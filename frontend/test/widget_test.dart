import 'package:charging_wattage_app/main.dart';
import 'package:charging_wattage_app/services/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tecron app renders its splash screen', (tester) async {
    await tester.pumpWidget(TecronApp(appState: AppState()));

    expect(find.text('TECRON'), findsOneWidget);
  });
}
