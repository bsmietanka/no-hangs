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
    Key? key,
    this.targetNamePrefix = 'progressor',
    this.onConnectionChanged,
    this.ackNotifier,
  }) : super(key: key);

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
                      (e) =>
                          e.device.name.isNotEmpty &&
                          e.device.name.toLowerCase().contains(
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
                } catch (_) {}
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
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final d = results[i].device;
                            return ListTile(
                              title: Text(
                                d.name.isEmpty ? '(unknown)' : d.name,
                              ),
                              subtitle: Text(d.id.id),
                              onTap: () async {
                                try {
                                  await FlutterBluePlus.stopScan();
                                } catch (_) {}
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
                      } catch (_) {}
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
    } catch (_) {}
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

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

      // Request battery voltage and start periodic refresh
      await _protocol!.requestBatteryVoltage();
      _startBatteryTimer();

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

  void _startBatteryTimer({Duration interval = const Duration(minutes: 5)}) {
    _batteryTimer?.cancel();
    _batteryTimer = Timer.periodic(interval, (_) async {
      await _protocol?.requestBatteryVoltage();
    });
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
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final connected = _connectedDevice != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bluetooth icon - tap to connect/disconnect
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
        // Battery indicator - only visible when connected and battery info available
        if (connected && _batteryVoltage != null)
          Icon(
            _getBatteryIcon(),
            color: _getBatteryColor(),
            size: 20,
          ),
        // Tare button - only visible when connected
        if (connected)
          TextButton(
            onPressed: _sendTare,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Tare',
              style: TextStyle(color: Colors.white),
            ),
          ),
      ],
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
