import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Handles Tindeq Progressor BLE protocol communication
class TindeqProtocol {
  // UUIDs
  static final Guid ctrlCharUuid = Guid('7e4e1703-1ea6-40c9-9dcc-13d34ffead57');
  static final Guid dataCharUuid = Guid('7e4e1702-1ea6-40c9-9dcc-13d34ffead57');
  
  // Commands
  static const int cmdTare = 100;
  static const int cmdStartWeight = 101;
  static const int cmdGetBatteryVoltage = 111;
  
  // Responses
  static const int resCmdResponse = 0;
  static const int resLowPowerWarning = 4;
  
  BluetoothCharacteristic? _ctrlChar;
  StreamSubscription<List<int>>? _dataSubscription;
  int? _pendingCommand;
  
  // Callbacks
  final void Function(int millivolts)? onBatteryUpdate;
  final void Function()? onLowBatteryWarning;
  final void Function(List<int> data)? onWeightData;
  
  TindeqProtocol({
    this.onBatteryUpdate,
    this.onLowBatteryWarning,
    this.onWeightData,
  });
  
  /// Initialize protocol with device characteristics
  Future<bool> initialize(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      
      for (final service in services) {
        for (final char in service.characteristics) {
          if (char.uuid == ctrlCharUuid) {
            _ctrlChar = char;
          } else if (char.uuid == dataCharUuid) {
            await char.setNotifyValue(true);
            _dataSubscription = char.lastValueStream.listen(_handleDataNotification);
          }
        }
      }
      
      return _ctrlChar != null;
    } catch (e) {
      debugPrint('TindeqProtocol initialization failed: $e');
      return false;
    }
  }
  
  /// Clean up resources
  void dispose() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _ctrlChar = null;
    _pendingCommand = null;
  }
  
  /// Send tare (zero) command
  Future<bool> tare() async {
    return await _sendCommand(cmdTare);
  }
  
  /// Start weight measurement stream
  Future<bool> startWeightStream() async {
    return await _sendCommand(cmdStartWeight);
  }
  
  /// Request battery voltage
  Future<bool> requestBatteryVoltage() async {
    _pendingCommand = cmdGetBatteryVoltage;
    return await _sendCommand(cmdGetBatteryVoltage);
  }
  
  /// Send a command to the device
  Future<bool> _sendCommand(int command) async {
    if (_ctrlChar == null) {
      debugPrint('TindeqProtocol: No control characteristic available');
      return false;
    }
    
    try {
      await _ctrlChar!.write([command], withoutResponse: false);
      return true;
    } catch (e) {
      debugPrint('TindeqProtocol: Failed to send command $command: $e');
      return false;
    }
  }
  
  /// Handle incoming data notifications
  void _handleDataNotification(List<int> data) {
    if (data.isEmpty) return;
    
    try {
      final messageType = data[0];
      
      switch (messageType) {
        case resCmdResponse:
          _handleCommandResponse(data);
          break;
        case resLowPowerWarning:
          _handleLowPowerWarning();
          break;
        default:
          // Assume it's weight data, pass to callback
          onWeightData?.call(data);
          break;
      }
    } catch (e) {
      debugPrint('TindeqProtocol: Error handling data notification: $e');
    }
  }
  
  /// Handle command response
  void _handleCommandResponse(List<int> data) {
    if (_pendingCommand == cmdGetBatteryVoltage && data.length >= 6) {
      // Parse 4-byte unsigned integer (little-endian)
      final vdd = data[2] | (data[3] << 8) | (data[4] << 16) | (data[5] << 24);
      onBatteryUpdate?.call(vdd);
      _pendingCommand = null;
    }
  }
  
  /// Handle low power warning
  void _handleLowPowerWarning() {
    onLowBatteryWarning?.call();
  }
  
  /// Check if protocol is ready
  bool get isReady => _ctrlChar != null;
}
