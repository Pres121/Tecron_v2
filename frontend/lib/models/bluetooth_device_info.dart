/// Represents a discoverable Bluetooth device. This shape intentionally
/// mirrors what a real BLE plugin (e.g. flutter_blue_plus) would give you
/// — id, name, signal strength — so swapping the dummy service for a real
/// one later only means changing BluetoothService's internals, not this
/// model or any UI code that consumes it.
class BluetoothDeviceInfo {
  final String id;
  final String name;
  final int rssi; // signal strength in dBm; closer to 0 = stronger signal

  const BluetoothDeviceInfo({required this.id, required this.name, required this.rssi});

  /// Rough 0-4 bar signal strength for display, based on typical BLE RSSI ranges.
  int get signalBars {
    if (rssi >= -50) return 4;
    if (rssi >= -65) return 3;
    if (rssi >= -75) return 2;
    return 1;
  }
}
