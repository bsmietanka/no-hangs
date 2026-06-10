import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Handles WH-C06 Bluetooth scale communication.
///
/// Unlike the Tindeq Progressor, the WH-C06 never accepts a GATT connection.
/// It broadcasts weight readings inside the manufacturer-specific data of its
/// BLE advertisements, so "connecting" means continuously scanning and
/// decoding advertisements coming from the selected device.
class Whc06Protocol {
  /// The WH-C06 advertises under this name.
  static const String deviceNamePattern = 'IF_B7';

  // The weight is a big-endian uint16 (in 10 g units) at byte 12 of the raw
  // manufacturer data field. flutter_blue_plus strips the 2-byte company ID
  // into the map key, so within the payload it sits at offset 10.
  static const int _weightByteOffset = 10;

  final void Function(double kg)? onWeightData;

  final StreamController<double> _weightController =
      StreamController<double>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSub;
  DeviceIdentifier? _remoteId;
  bool _running = false;

  Whc06Protocol({this.onWeightData});

  /// Weight readings in kg, emitted as advertisements arrive (a few per second).
  Stream<double> get weightStream => _weightController.stream;

  bool get isRunning => _running;

  /// Start streaming weight data from [device] by scanning its advertisements.
  Future<bool> start(BluetoothDevice device) async {
    if (_running) return true;
    _remoteId = device.remoteId;

    _scanSub = FlutterBluePlus.onScanResults.listen(
      _handleScanResults,
      onError: (e) => debugPrint('Whc06Protocol: scan error: $e'),
    );

    try {
      // continuousUpdates makes flutter_blue_plus re-emit results on every
      // advertisement instead of deduplicating, which is how the WH-C06
      // delivers each new weight sample.
      await FlutterBluePlus.startScan(
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
      _running = true;
      return true;
    } catch (e) {
      debugPrint('Whc06Protocol: failed to start scan: $e');
      await _scanSub?.cancel();
      _scanSub = null;
      return false;
    }
  }

  /// Stop streaming weight data.
  Future<void> stop() async {
    _running = false;
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Whc06Protocol: failed to stop scan: $e');
    }
  }

  void dispose() {
    stop();
    _weightController.close();
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final r in results) {
      if (r.device.remoteId != _remoteId) continue;
      final weight = parseWeight(r.advertisementData.manufacturerData);
      if (weight == null) continue;
      if (!_weightController.isClosed) {
        _weightController.add(weight);
      }
      onWeightData?.call(weight);
    }
  }

  /// Decode the weight (kg) from advertisement manufacturer data.
  /// Returns null if the payload is malformed or out of range.
  @visibleForTesting
  static double? parseWeight(Map<int, List<int>> manufacturerData) {
    for (final data in manufacturerData.values) {
      if (data.length < _weightByteOffset + 2) continue;
      final raw = (data[_weightByteOffset] << 8) | data[_weightByteOffset + 1];
      final weight = raw / 100.0;
      if (weight < 0 || weight > 1000) continue;
      return weight;
    }
    return null;
  }
}
