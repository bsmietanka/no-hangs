import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Which force-measurement device protocol is in use.
enum ForceDeviceType { tindeq, whc06 }

/// An active device connection handed from the BLE connect widget to the
/// rest of the app.
class ConnectedDevice {
  final BluetoothDevice device;
  final ForceDeviceType type;

  /// Weight readings in kg. Non-null for devices that broadcast weight via
  /// advertisements (WH-C06); null for the Tindeq, which is read through its
  /// GATT data characteristic.
  final Stream<double>? weightStream;

  const ConnectedDevice({
    required this.device,
    required this.type,
    this.weightStream,
  });
}
