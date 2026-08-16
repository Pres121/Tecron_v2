/// Everything the backend's two-layer predictor (database lookup + ML
/// fallback) can accept. Only [brand] and [model] are required — every
/// other field is optional and simply omitted from the JSON body if null,
/// matching how the Python predictor treats missing specs (defaults are
/// filled in server-side).
class PhoneSpec {
  final String brand;
  final String model;

  final double? priceInr;
  final double? ratingScore;
  final String? processorBrand;
  final int? coreCount;
  final double? clockSpeedGhz;
  final double? ramGb;
  final double? storageGb;
  final bool? has5g;
  final bool? hasNfc;
  final bool? hasIrBlaster;
  final double? displayInches;
  final int? refreshRateHz;
  final double? batteryMah;
  final bool? fastCharging;

  const PhoneSpec({
    required this.brand,
    required this.model,
    this.priceInr,
    this.ratingScore,
    this.processorBrand,
    this.coreCount,
    this.clockSpeedGhz,
    this.ramGb,
    this.storageGb,
    this.has5g,
    this.hasNfc,
    this.hasIrBlaster,
    this.displayInches,
    this.refreshRateHz,
    this.batteryMah,
    this.fastCharging,
  });

  /// Builds the JSON body. Fields left null are omitted entirely rather
  /// than sent as `null`, so the backend's "how many specs were actually
  /// provided" coverage check behaves the same as it does from the CLI/web UI.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      "smartphone_brand": brand,
      "model": model,
    };
    void addIfNotNull(String key, dynamic value) {
      if (value != null) json[key] = value;
    }

    addIfNotNull("price_inr", priceInr);
    addIfNotNull("rating_score", ratingScore);
    addIfNotNull("processor_brand", processorBrand);
    addIfNotNull("core_count", coreCount);
    addIfNotNull("clock_speed_ghz", clockSpeedGhz);
    addIfNotNull("ram_gb", ramGb);
    addIfNotNull("storage_gb", storageGb);
    addIfNotNull("has_5g", has5g);
    addIfNotNull("has_nfc", hasNfc);
    addIfNotNull("has_ir_blaster", hasIrBlaster);
    addIfNotNull("display_inches", displayInches);
    addIfNotNull("refresh_rate_hz", refreshRateHz);
    addIfNotNull("battery_mah", batteryMah);
    addIfNotNull("fast_charging", fastCharging);

    return json;
  }
}
