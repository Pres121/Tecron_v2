import "package:flutter/material.dart";

import "../models/phone_spec.dart";
import "../theme/app_theme.dart";

/// Brand/model form with an optional expandable section for the extra
/// specs the ML fallback uses when a phone isn't in the known database.
class PhoneForm extends StatefulWidget {
  final bool isLoading;
  final ValueChanged<PhoneSpec> onSubmit;

  const PhoneForm({super.key, required this.isLoading, required this.onSubmit});

  @override
  State<PhoneForm> createState() => _PhoneFormState();
}

class _PhoneFormState extends State<PhoneForm> {
  final _formKey = GlobalKey<FormState>();

  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _ramCtrl = TextEditingController();
  final _storageCtrl = TextEditingController();
  final _batteryCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _displayCtrl = TextEditingController();
  final _refreshCtrl = TextEditingController();
  final _clockSpeedCtrl = TextEditingController();
  String? _processorBrand;

  bool _has5g = false;
  bool _hasNfc = false;
  bool _hasIrBlaster = false;
  bool _fastCharging = true;
  bool _showAdvanced = false;

  @override
  void dispose() {
    for (final c in [
      _brandCtrl,
      _modelCtrl,
      _ramCtrl,
      _storageCtrl,
      _batteryCtrl,
      _priceCtrl,
      _displayCtrl,
      _refreshCtrl,
      _clockSpeedCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _toDouble(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim());
  int? _toInt(String text) => text.trim().isEmpty ? null : int.tryParse(text.trim());

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(PhoneSpec(
      brand: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      ramGb: _toDouble(_ramCtrl.text),
      storageGb: _toDouble(_storageCtrl.text),
      batteryMah: _toDouble(_batteryCtrl.text),
      priceInr: _toDouble(_priceCtrl.text),
      displayInches: _toDouble(_displayCtrl.text),
      refreshRateHz: _toInt(_refreshCtrl.text),
      clockSpeedGhz: _toDouble(_clockSpeedCtrl.text),
      processorBrand: _processorBrand,
      has5g: _has5g,
      hasNfc: _hasNfc,
      hasIrBlaster: _hasIrBlaster,
      fastCharging: _fastCharging,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _brandCtrl,
                decoration: const InputDecoration(
                  labelText: "Brand",
                  hintText: "Xiaomi",
                  prefixIcon: Icon(Icons.smartphone_rounded, size: 20, color: AppColors.textFaint),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(
                  labelText: "Model",
                  hintText: "Redmi Note 14 SE 5G",
                  prefixIcon: Icon(Icons.badge_outlined, size: 20, color: AppColors.textFaint),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
              ),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _showAdvanced ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "Add specs (helps if the phone isn't in the database)",
                        style: TextStyle(fontSize: 13.5, color: AppColors.primaryDark, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _showAdvanced ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: _advancedSection(),
                secondChild: const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: widget.isLoading ? null : _submit,
                child: widget.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Text("Predict charging power"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _advancedSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _numberField(_ramCtrl, "RAM (GB)", "8")),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_storageCtrl, "Storage (GB)", "128")),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _numberField(_batteryCtrl, "Battery (mAh)", "5000")),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_priceCtrl, "Price (INR)", "20000")),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _numberField(_displayCtrl, "Display (in)", "6.6")),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_refreshCtrl, "Refresh (Hz)", "120")),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _processorBrand,
                  decoration: const InputDecoration(labelText: "Processor brand"),
                  dropdownColor: AppColors.background,
                  items: const [
                    DropdownMenuItem(value: "snapdragon", child: Text("Snapdragon")),
                    DropdownMenuItem(value: "mediatek", child: Text("MediaTek")),
                    DropdownMenuItem(value: "exynos", child: Text("Exynos")),
                    DropdownMenuItem(value: "unisoc", child: Text("Unisoc")),
                    DropdownMenuItem(value: "apple", child: Text("Apple")),
                    DropdownMenuItem(value: "tensor", child: Text("Tensor")),
                  ],
                  onChanged: (v) => setState(() => _processorBrand = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _numberField(_clockSpeedCtrl, "Clock speed (GHz)", "2.4")),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip("5G", _has5g, (v) => setState(() => _has5g = v)),
              _chip("NFC", _hasNfc, (v) => setState(() => _hasNfc = v)),
              _chip("IR blaster", _hasIrBlaster, (v) => setState(() => _hasIrBlaster = v)),
              _chip("Fast charging", _fastCharging, (v) => setState(() => _fastCharging = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController ctrl, String label, String hint) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _chip(String label, bool selected, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onChanged,
      showCheckmark: false,
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primarySoft,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.surfaceBorder),
      labelStyle: TextStyle(
        fontSize: 12.5,
        color: selected ? AppColors.primaryDark : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
