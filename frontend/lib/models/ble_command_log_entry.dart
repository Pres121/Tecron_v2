/// A single command sent to the connected Tecron device over BLE, plus
/// its (dummy, simulated) acknowledgement state. Shown as a log on the
/// Connection page so the user can see exactly what's being sent, e.g.
/// {Set max wattage: 45} or {Start charging: true}.
class BleCommandLogEntry {
  final String name;
  final String value;
  final DateTime sentAt;
  final bool acknowledged;

  const BleCommandLogEntry({
    required this.name,
    required this.value,
    required this.sentAt,
    this.acknowledged = false,
  });

  BleCommandLogEntry copyWith({bool? acknowledged}) {
    return BleCommandLogEntry(
      name: name,
      value: value,
      sentAt: sentAt,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  String get display => "{ $name: $value }";
}

/// Dummy device health snapshot, as if read from the connected charger's
/// own status characteristic over BLE.
class DeviceHealth {
  final int firmwareBatteryPercent; // the charger unit's own internal battery/backup, if any
  final double internalTempCelsius;
  final String firmwareVersion;
  final bool isHealthy;

  const DeviceHealth({
    required this.firmwareBatteryPercent,
    required this.internalTempCelsius,
    required this.firmwareVersion,
    required this.isHealthy,
  });
}
