import "package:flutter/material.dart";

import "../models/ble_command_log_entry.dart";
import "../models/bluetooth_device_info.dart";
import "../services/bluetooth_service.dart";
import "../theme/app_theme.dart";

/// Connection tab: scan/connect UI, connected device details + health,
/// and a live log of every BLE command sent to the device (e.g. from the
/// Dashboard's "Start charging" button or a wattage-limit update).
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _bluetooth = BluetoothService.instance;

  @override
  void initState() {
    super.initState();
    _bluetooth.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bluetooth.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Connection",
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              "Manage the Bluetooth link to your Tecron charger and see every command sent to it.",
              style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            _statusCard(),
            const SizedBox(height: 16),
            if (_bluetooth.isConnected) _healthCard() else _scanSection(),
            const SizedBox(height: 24),
            _commandLogSection(),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final status = _bluetooth.status;
    final device = _bluetooth.connectedDevice;

    late Color dotColor;
    late String label;
    switch (status) {
      case BluetoothConnectionStatus.connected:
        dotColor = AppColors.primary;
        label = "Connected";
        break;
      case BluetoothConnectionStatus.connecting:
        dotColor = AppColors.neutral;
        label = "Connecting…";
        break;
      case BluetoothConnectionStatus.scanning:
        dotColor = AppColors.neutral;
        label = "Scanning…";
        break;
      case BluetoothConnectionStatus.disconnected:
        dotColor = AppColors.textFaint;
        label = "Not connected";
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const Spacer(),
                if (status == BluetoothConnectionStatus.connected)
                  TextButton(
                    onPressed: () => _bluetooth.disconnect(),
                    child: const Text("Disconnect", style: TextStyle(color: AppColors.error)),
                  )
                else if (status != BluetoothConnectionStatus.scanning && status != BluetoothConnectionStatus.connecting)
                  TextButton(
                    onPressed: () => _bluetooth.startScan(),
                    child: const Text("Scan", style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            if (device != null) ...[
              const SizedBox(height: 16),
              _detailRow("Device name", device.name),
              _detailRow("Device ID", device.id),
              _detailRow("Signal", "${device.rssi} dBm"),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textFaint)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _healthCard() {
    final health = _bluetooth.health;
    if (health == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  health.isHealthy ? Icons.check_circle_rounded : Icons.warning_rounded,
                  size: 18,
                  color: health.isHealthy ? AppColors.primary : AppColors.error,
                ),
                const SizedBox(width: 8),
                const Text("Device health", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 14),
            _detailRow("Firmware version", health.firmwareVersion),
            _detailRow("Internal battery", "${health.firmwareBatteryPercent}%"),
            _detailRow("Internal temperature", "${health.internalTempCelsius.toStringAsFixed(1)}°C"),
            _detailRow("Status", health.isHealthy ? "Normal" : "Attention needed"),
          ],
        ),
      ),
    );
  }

  Widget _scanSection() {
    final status = _bluetooth.status;
    final devices = _bluetooth.discoveredDevices;

    if (status == BluetoothConnectionStatus.disconnected && devices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("Nearby devices", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(width: 10),
                if (status == BluetoothConnectionStatus.scanning)
                  const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 14),
            ...devices.map(_deviceTile),
          ],
        ),
      ),
    );
  }

  Widget _deviceTile(BluetoothDeviceInfo device) {
    final connecting = _bluetooth.status == BluetoothConnectionStatus.connecting;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: connecting ? null : () => _bluetooth.connect(device),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.bluetooth_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(device.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                ),
                Text("${device.rssi} dBm", style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _commandLogSection() {
    final log = _bluetooth.commandLog;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Command log", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text(
          "Every command sent to the connected device, most recent first.",
          style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
        ),
        const SizedBox(height: 14),
        if (log.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: const Text(
              "No commands sent yet. Connect a device and use Start charging on the Dashboard.",
              style: TextStyle(fontSize: 13, color: AppColors.textFaint),
            ),
          )
        else
          ...log.map(_commandTile),
      ],
    );
  }

  Widget _commandTile(BleCommandLogEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Icon(
            entry.acknowledged ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 16,
            color: entry.acknowledged ? AppColors.primary : AppColors.textFaint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.display,
              style: const TextStyle(fontSize: 13, fontFamily: "monospace", color: AppColors.textPrimary),
            ),
          ),
          Text(_formatTime(entry.sentAt), style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return "$h:$m:$s";
  }
}
