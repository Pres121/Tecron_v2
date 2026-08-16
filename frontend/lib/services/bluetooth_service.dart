import "dart:async";
import "dart:math";

import "package:flutter/foundation.dart";

import "../models/ble_command_log_entry.dart";
import "../models/bluetooth_device_info.dart";

enum BluetoothConnectionStatus { disconnected, scanning, connecting, connected }

/// Dummy Bluetooth connectivity for the Tecron charging hardware.
///
/// This is a placeholder implementation — scanning, connecting, and
/// sending commands all simulate real BLE timing and behavior (discovery
/// delay, connection handshake delay, command acknowledgement delay)
/// without touching any actual hardware or platform Bluetooth APIs.
///
/// To swap in real Bluetooth later (e.g. via the `flutter_blue_plus`
/// package): keep this class's public API identical, and replace only
/// the insides of startScan/connect/disconnect/sendCommand with real
/// BLE calls. No UI code should need to change.
///
/// Singleton, since Bluetooth connection state is inherently app-wide —
/// every screen should see the same "connected" status and command log.
class BluetoothService extends ChangeNotifier {
  BluetoothService._();
  static final BluetoothService instance = BluetoothService._();

  BluetoothConnectionStatus _status = BluetoothConnectionStatus.disconnected;
  List<BluetoothDeviceInfo> _discoveredDevices = [];
  BluetoothDeviceInfo? _connectedDevice;
  DeviceHealth? _health;
  final List<BleCommandLogEntry> _commandLog = [];

  Timer? _scanTimer;
  int _scanTick = 0;

  BluetoothConnectionStatus get status => _status;
  List<BluetoothDeviceInfo> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  BluetoothDeviceInfo? get connectedDevice => _connectedDevice;
  DeviceHealth? get health => _health;
  List<BleCommandLogEntry> get commandLog => List.unmodifiable(_commandLog.reversed);
  bool get isConnected => _status == BluetoothConnectionStatus.connected;

  static const List<BluetoothDeviceInfo> _dummyDevices = [
    BluetoothDeviceInfo(id: "TCR-2201", name: "Tecron Charger — Desk", rssi: -42),
    BluetoothDeviceInfo(id: "TCR-4417", name: "Tecron Charger — Living Room", rssi: -61),
    BluetoothDeviceInfo(id: "TCR-9930", name: "Tecron Charger — Bedside", rssi: -78),
  ];

  /// Simulates a BLE scan: devices "appear" one at a time over a couple of
  /// seconds, the way a real scan gradually discovers nearby peripherals.
  Future<void> startScan() async {
    if (_status == BluetoothConnectionStatus.scanning) return;
    _scanTimer?.cancel();
    _discoveredDevices = [];
    _setStatus(BluetoothConnectionStatus.scanning);

    _scanTick = 0;
    final rng = Random();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (_scanTick >= _dummyDevices.length) {
        timer.cancel();
        if (_status == BluetoothConnectionStatus.scanning) {
          _setStatus(BluetoothConnectionStatus.disconnected);
        }
        return;
      }
      final base = _dummyDevices[_scanTick];
      final jittered = BluetoothDeviceInfo(
        id: base.id,
        name: base.name,
        rssi: base.rssi + rng.nextInt(6) - 3,
      );
      _discoveredDevices = [..._discoveredDevices, jittered];
      _scanTick++;
      notifyListeners();
    });
  }

  void stopScan() {
    _scanTimer?.cancel();
    if (_status == BluetoothConnectionStatus.scanning) {
      _setStatus(BluetoothConnectionStatus.disconnected);
    }
  }

  Future<void> connect(BluetoothDeviceInfo device) async {
    stopScan();
    _setStatus(BluetoothConnectionStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 1100));
    _connectedDevice = device;
    _health = DeviceHealth(
      firmwareBatteryPercent: 80 + Random().nextInt(20),
      internalTempCelsius: 32 + Random().nextDouble() * 6,
      firmwareVersion: "1.4.2",
      isHealthy: true,
    );
    _commandLog.clear();
    _setStatus(BluetoothConnectionStatus.connected);
  }

  Future<void> disconnect() async {
    _connectedDevice = null;
    _health = null;
    _setStatus(BluetoothConnectionStatus.disconnected);
  }

  /// Sends a command to the connected device, e.g.
  /// `sendCommand("Set max wattage", "45")` or
  /// `sendCommand("Start charging", "true")`. Logs it immediately as
  /// unacknowledged, then flips to acknowledged after a short simulated
  /// round-trip, the way a real BLE write-with-response would.
  Future<void> sendCommand(String name, String value) async {
    if (!isConnected) return;
    final entry = BleCommandLogEntry(name: name, value: value, sentAt: DateTime.now());
    _commandLog.add(entry);
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));
    final index = _commandLog.indexOf(entry);
    if (index != -1) {
      _commandLog[index] = entry.copyWith(acknowledged: true);
      notifyListeners();
    }
  }

  void _setStatus(BluetoothConnectionStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }
}
