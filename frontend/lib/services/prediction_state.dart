import "package:flutter/foundation.dart";

import "../models/prediction_result.dart";

/// Holds the most recent prediction so it can be shown on the Device tab
/// (e.g. "Ready to charge at 45W") without re-fetching or passing it
/// manually between tabs. Singleton for the same reason as
/// BluetoothService — this is app-wide state, not tied to one screen.
class PredictionState extends ChangeNotifier {
  PredictionState._();
  static final PredictionState instance = PredictionState._();

  PredictionResult? _latest;
  PredictionResult? get latest => _latest;

  void update(PredictionResult result) {
    _latest = result;
    notifyListeners();
  }
}
