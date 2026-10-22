import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('la app arranca sin servidor y muestra el estado vacío', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});

    await tester.pumpWidget(const CosechaClimaApp());
    await tester.pumpAndSettle();

    expect(find.text('Mis parcelas'), findsOneWidget);
    expect(find.text('Registrar mi primera parcela'), findsOneWidget);
    expect(find.text('Nueva parcela'), findsOneWidget);
  });
}
