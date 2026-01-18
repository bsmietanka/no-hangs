import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/tindeq_protocol.dart';

/// A minimal widget that scans for BLE devices whose name contains
/// [targetNamePrefix] (case-insensitive) and allows connecting/disconnecting.
class BleConnectWidget extends StatefulWidget {
  final String targetNamePrefix;
  final ValueChanged<BluetoothDevice?>? onConnectionChanged;
  final ValueListenable<bool>? ackNotifier;

  const BleConnectWidget({
    super.key,
    this.targetNamePrefix = 'progressor',
    this.onConnectionChanged,
    this.ackNotifier,
  });

  @override
  State<BleConnectWidget> createState() => _BleConnectWidgetState();
}

class _BleConnectWidgetState extends State<BleConnectWidget> {
  BluetoothDevice? _connectedDevice;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  TindeqProtocol? _protocol;
  int? _batteryVoltage; // in millivolts
  Timer? _batteryTimer;

  @override
  void dispose() {
    _connectionSub?.cancel();
    _batteryTimer?.cancel();
    _protocol?.dispose();
    super.dispose();
  }

  Future<bool> _ensurePermissions() async {
    final messenger = ScaffoldMessenger.of(context);
    final p1 = await Permission.bluetoothScan.request();
    final p2 = await Permission.bluetoothConnect.request();
    final p3 = await Permission.locationWhenInUse.request();

    if (p1.isGranted && p2.isGranted) return true;
    if (p3.isGranted) return true;

    _showSnackBar(messenger, 'Bluetooth permissions are required to scan/connect.');
    return false;
  }

  Future<BluetoothDevice?> _showDevicePicker() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _ensurePermissions()) return null;
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _showSnackBar(messenger, 'Bluetooth adapter is not ON.');
      return null;
    }

    List<ScanResult> results = [];
    StreamSubscription<List<ScanResult>>? sub;
    bool scanning = true;

    if (!mounted) return null;
    final chosen = await showDialog<BluetoothDevice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            if (sub == null) {
              sub = FlutterBluePlus.scanResults.listen((r) {
                final filtered = r
                    .where(
                      (e) => e.device.platformName.isNotEmpty &&
                          e.device.platformName.toLowerCase().contains(
                                widget.targetNamePrefix.toLowerCase(),
                              ),
                    )
                    .toList();
                setStateDialog(() {
                  results = filtered;
                });
              });

              FlutterBluePlus.startScan(
                timeout: const Duration(seconds: 4),
              ).then((_) async {
                await FlutterBluePlus.isScanning.where((v) => v == false).first;
                try {
                  await FlutterBluePlus.stopScan();
                } catch (e, st) {
                  _log('Failed to stop scanning when selecting device', e, st);
                }
                scanning = false;
                setStateDialog(() {});
              });
            }

            return AlertDialog(
              title: const Text('Select device'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (scanning) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    if (results.isEmpty)
                      const Text('No devices found yet')
                    else
                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final d = results[i].device;
                            final name = d.platformName.isEmpty ? '(unknown)' : d.platformName;
                            return ListTile(
                              title: Text(name),
                              subtitle: Text(d.remoteId.str),
                              onTap: () async {
                                try {
                                  await FlutterBluePlus.stopScan();
                                } catch (e, st) {
                                  _log('Failed to stop scanning for device list', e, st);
                                }
                                await sub?.cancel();
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop(d);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await FlutterBluePlus.stopScan();
                      } catch (e, st) {
                        _log('Failed to stop scanning when cancelling device picker', e, st);
                      }
                      await sub?.cancel();
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop(null);
                    },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    try {
      await sub?.cancel();
    } catch (e, st) {
      _log('Failed to cancel scan subscription', e, st);
    }
    try {
      await FlutterBluePlus.stopScan();
    } catch (e, st) {
      _log('Failed to stop scan after dialog', e, st);
    }

    return chosen;
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _connectedDevice = device);
    try {
      await device.connect(license: License.free);
      _connectionSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _stopBatteryTimer();
          _protocol?.dispose();
          _protocol = null;
          setState(() {
            _connectedDevice = null;
            _batteryVoltage = null;
          });
          widget.onConnectionChanged?.call(null);
        }
      });
      widget.onConnectionChanged?.call(device);

      // Initialize protocol handler
      _protocol = TindeqProtocol(
        onBatteryUpdate: (millivolts) {
          setState(() {
            _batteryVoltage = millivolts;
          });
        },
        onLowBatteryWarning: () {
          setState(() {
            if (_batteryVoltage == null || _batteryVoltage! > 3300) {
              _batteryVoltage = 3200; // represent critical/low battery
            }
          });
          _showSnackBar(messenger, 'Device reports low battery');
        },
      );

      final initialized = await _protocol!.initialize(device);
      if (!initialized) {
        _showSnackBar(messenger, 'Failed to initialize device protocol');
        _protocol?.dispose();
        _protocol = null;
        return;
      }

      // Request battery voltage once on connection
      await _protocol!.requestBatteryVoltage();

      // Wait a bit for battery response
      await Future.delayed(const Duration(milliseconds: 500));

      // Start weight measurement stream
      final started = await _protocol!.startWeightStream();
      if (started) {
        _showSnackBar(messenger, 'Start measurement command sent');
      }

      _showSnackBar(messenger, 'Connected');
    } catch (e) {
      _showSnackBar(messenger, 'Failed to connect: $e');
      _protocol?.dispose();
      _protocol = null;
      setState(() => _connectedDevice = null);
    }
  }

  void _stopBatteryTimer() {
    _batteryTimer?.cancel();
    _batteryTimer = null;
  }

  Future<void> _sendTare() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_protocol == null || !_protocol!.isReady) {
      _showSnackBar(messenger, 'Not connected');
      return;
    }

    try {
      await _protocol!.tare();

      // Request fresh battery reading after tare
      await _protocol!.requestBatteryVoltage();

      // Wait briefly then restart measurements
      await Future.delayed(const Duration(milliseconds: 100));
      final started = await _protocol!.startWeightStream();

      if (started) {
        _showSnackBar(messenger, 'Tare sent and measurement restarted');
      } else {
        _showSnackBar(messenger, 'Tare sent (restart failed)');
      }
    } catch (e) {
      _showSnackBar(messenger, 'Failed to send tare: $e');
    }
  }

  Future<void> _disconnect(BluetoothDevice device) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await device.disconnect();
    } catch (e, st) {
      _log('Disconnect command failed', e, st);
    }
    await _connectionSub?.cancel();
    _stopBatteryTimer();
    _protocol?.dispose();
    setState(() {
      _connectedDevice = null;
      _batteryVoltage = null;
      _protocol = null;
    });
    _showSnackBar(messenger, 'Disconnected');
  }

  void _showSnackBar(ScaffoldMessengerState messenger, String message, {Color? backgroundColor}) {
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }
  
  void _log(String message, [Object? error, StackTrace? stackTrace]) {
    final details = error != null ? ' Error: $error' : '';
    debugPrint('$message$details');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = _connectedDevice != null;

    // Build children list with conditional spacing (smaller gaps)
    final children = <Widget>[];

    // Tare button - leftmost (visible when connected)
    if (connected) {
      children.add(
        TextButton(
          onPressed: _sendTare,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: const Text(
            'Tare',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
      // spacing between Tare and next control
      children.add(const SizedBox(width: 6));
    }

    // Battery indicator - middle (only when available)
    if (connected && _batteryVoltage != null) {
      children.add(
        Icon(
          _getBatteryIcon(),
          color: _getBatteryColor(),
          size: 20,
        ),
      );
      // spacing between battery and next control
      children.add(const SizedBox(width: 6));
    }

    // Bluetooth icon - rightmost
    children.add(
      IconButton(
        icon: Icon(
          connected ? Icons.bluetooth_connected : Icons.bluetooth,
          color: connected ? Colors.white : Colors.white70,
        ),
        onPressed: () async {
          if (connected) {
            await _disconnect(_connectedDevice!);
          } else {
            final device = await _showDevicePicker();
            if (device != null) {
              await _connectDevice(device);
            }
          }
        },
        tooltip: connected ? 'Disconnect' : 'Connect',
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  IconData _getBatteryIcon() {
    if (_batteryVoltage == null) return Icons.battery_unknown;

    // Typical Li-ion voltage: 4.2V (full) to 3.0V (empty)
    // Using millivolts
    if (_batteryVoltage! >= 4000) return Icons.battery_full;
    if (_batteryVoltage! >= 3700) return Icons.battery_6_bar;
    if (_batteryVoltage! >= 3500) return Icons.battery_4_bar;
    if (_batteryVoltage! >= 3300) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

  Color _getBatteryColor() {
    if (_batteryVoltage == null) return Colors.white70;

    if (_batteryVoltage! >= 3500) return Colors.white;
    if (_batteryVoltage! >= 3300) return Colors.orange;
    return Colors.red;
  }
}
