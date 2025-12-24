import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// A minimal widget that scans for BLE devices whose name contains
/// [targetNamePrefix] (case-insensitive) and allows connecting/disconnecting.
class BleConnectWidget extends StatefulWidget {
  final String targetNamePrefix;
  final ValueChanged<BluetoothDevice?>? onConnectionChanged;
  final ValueListenable<bool>? ackNotifier;

  const BleConnectWidget({Key? key, this.targetNamePrefix = 'progressor', this.onConnectionChanged, this.ackNotifier})
    : super(key: key);

  @override
  State<BleConnectWidget> createState() => _BleConnectWidgetState();
}

class _BleConnectWidgetState extends State<BleConnectWidget> {
  static final Guid _ctrlCharUuid = Guid(
    '7e4e1703-1ea6-40c9-9dcc-13d34ffead57',
  );
  static final Guid _dataCharUuid = Guid('7e4e1702-1ea6-40c9-9dcc-13d34ffead57');
  static const int _cmdStartWeight = 101;
  static const int _cmdTare = 100;
  static const int _cmdGetBatteryVoltage = 111;
  static const int _resCmdResponse = 0;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _ctrlChar;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _dataNotificationSub;
  int? _batteryVoltage; // in millivolts
  int? _currentCmdRequest;
  Timer? _batteryTimer;

  @override
  void dispose() {
    _connectionSub?.cancel();
    _dataNotificationSub?.cancel();
    _ctrlChar = null;
    super.dispose();
  }

  Future<bool> _ensurePermissions() async {
    final p1 = await Permission.bluetoothScan.request();
    final p2 = await Permission.bluetoothConnect.request();
    final p3 = await Permission.locationWhenInUse.request();

    if (p1.isGranted && p2.isGranted) return true;
    if (p3.isGranted) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bluetooth permissions are required to scan/connect.'),
      ),
    );
    return false;
  }

  Future<void> _onPrimaryPressed() async {
    if (_connectedDevice != null) {
      await _disconnect(_connectedDevice!);
      return;
    }

    final device = await _showDevicePicker();
    if (device == null) return;

    await _connectDevice(device);
  }

  Future<BluetoothDevice?> _showDevicePicker() async {
    if (!await _ensurePermissions()) return null;
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth adapter is not ON.')),
      );
      return null;
    }

    List<ScanResult> results = [];
    StreamSubscription<List<ScanResult>>? sub;
    bool scanning = true;

    final chosen = await showDialog<BluetoothDevice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            // start scanning when dialog opens
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
                                // stop scanning
                                try {
                                  await FlutterBluePlus.stopScan();
                                } catch (_) {}
                                await sub?.cancel();
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

    // ensure we cleaned up
    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    return chosen;
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    setState(() => _connectedDevice = device);
    try {
      await device.connect(license: License.free);
      _connectionSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          setState(() => _connectedDevice = null);
          widget.onConnectionChanged?.call(null);
        }
      });
      widget.onConnectionChanged?.call(device);

      // discover services & find control characteristic (do NOT send tare automatically)
      final services = await device.discoverServices();
      BluetoothCharacteristic? ctrl;
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.uuid == _ctrlCharUuid) {
            ctrl = c;
            break;
          }
        }
        if (ctrl != null) break;
      }

      if (ctrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Control characteristic not found')),
        );
        _ctrlChar = null;
        return;
      }

      // cache control characteristic for later taring
      _ctrlChar = ctrl;
      // Try to enable notifications on the Data characteristic and start measurements
      try {
        BluetoothCharacteristic? dataChar;
        for (final s in services) {
          for (final c in s.characteristics) {
            if (c.uuid == _dataCharUuid) {
              dataChar = c;
              break;
            }
          }
          if (dataChar != null) break;
        }

        if (dataChar != null) {
          await dataChar.setNotifyValue(true);
          
          // Subscribe to data notifications to receive battery voltage
          _dataNotificationSub = dataChar.lastValueStream.listen((data) {
            _handleDataNotification(data);
          });
          
          // Request battery voltage and start periodic refresh
          await _requestBatteryVoltage();
          _startBatteryTimer();
          
          // Wait a bit for battery response
          await Future.delayed(const Duration(milliseconds: 500));
          
          // send the start measurement command to the control characteristic
          try {
            await _ctrlChar!.write([_cmdStartWeight], withoutResponse: false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Start measurement command sent')),
            );
          } catch (e) {
            debugPrint('Failed to send start command: $e');
          }
        }
      } catch (e) {
        debugPrint('Failed to enable data notifications: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected')),
      );
      widget.onConnectionChanged?.call(_connectedDevice);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
      _ctrlChar = null;
      setState(() => _connectedDevice = null);
    }
  }

  void _handleDataNotification(List<int> data) {
    if (data.isEmpty) return;
    
    try {
      if (data[0] == _resCmdResponse && _currentCmdRequest == _cmdGetBatteryVoltage) {
        // Battery voltage response: 4-byte unsigned integer in little-endian
        if (data.length >= 6) {
          final vdd = data[2] | (data[3] << 8) | (data[4] << 16) | (data[5] << 24);
          setState(() {
            _batteryVoltage = vdd;
          });
          _currentCmdRequest = null;
        }
      } else if (data[0] == 4) {
        // RES_LOW_PWR_WARNING (4) - device indicates low battery
        setState(() {
          if (_batteryVoltage == null || _batteryVoltage! > 3300) {
            _batteryVoltage = 3200; // represent critical/low battery
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device reports low battery')),
        );
      }
    } catch (e) {
      debugPrint('Failed to parse data notification: $e');
    }
  }

  Future<void> _requestBatteryVoltage() async {
    if (_ctrlChar == null) return;
    
    try {
      _currentCmdRequest = _cmdGetBatteryVoltage;
      await _ctrlChar!.write([_cmdGetBatteryVoltage], withoutResponse: false);
    } catch (e) {
      debugPrint('Failed to request battery voltage: $e');
      _currentCmdRequest = null;
    }
  }

  void _startBatteryTimer({Duration interval = const Duration(minutes: 5)}) {
    _batteryTimer?.cancel();
    _batteryTimer = Timer.periodic(interval, (_) async {
      await _requestBatteryVoltage();
    });
  }

  void _stopBatteryTimer() {
    _batteryTimer?.cancel();
    _batteryTimer = null;
  }

  Future<void> _sendTare() async {
    if (_connectedDevice == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not connected')));
      return;
    }

    try {
      // If we don't have the control characteristic cached, try to discover it now
      if (_ctrlChar == null) {
        final services = await _connectedDevice!.discoverServices();
        for (final s in services) {
          for (final c in s.characteristics) {
            if (c.uuid == _ctrlCharUuid) {
              _ctrlChar = c;
              break;
            }
          }
          if (_ctrlChar != null) break;
        }
        if (_ctrlChar == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Control characteristic not found')),
          );
          return;
        }
      }

      await _ctrlChar!.write([_cmdTare], withoutResponse: false);

      // After Tare, the device may stop streaming. Re-enable data notifications and
      // send the start measurement command so measurements resume automatically.
      try {
        BluetoothCharacteristic? dataChar;
        final services = await _connectedDevice!.discoverServices();
        for (final s in services) {
          for (final c in s.characteristics) {
            if (c.uuid == _dataCharUuid) {
              dataChar = c;
              break;
            }
          }
          if (dataChar != null) break;
        }

        if (dataChar != null) {
          await dataChar.setNotifyValue(true);
          try {
            await _ctrlChar!.write([_cmdStartWeight], withoutResponse: false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Tare sent and measurement restarted')));
          } catch (e) {
            debugPrint('Failed to send start after tare: $e');
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tare sent (restart failed)')));
          }
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Tare command sent')));
        }
      } catch (e) {
        debugPrint('Failed to restart measurements after tare: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tare command sent')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send tare: $e')));
    }
  }

  Future<void> _disconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {}
    await _connectionSub?.cancel();
    await _dataNotificationSub?.cancel();
    _stopBatteryTimer();
    setState(() {
      _connectedDevice = null;
      _batteryVoltage = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Disconnected')));
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
              // Disconnect directly without dialog
              await _disconnect(_connectedDevice!);
            } else {
              // Show connection dialog
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
