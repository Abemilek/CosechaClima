import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/widgets/pin_input.dart';

void main() {
  Widget buildTestable(ValueChanged<String> onChanged, {String? errorText}) {
    return MaterialApp(
      home: Scaffold(
        body: PinInput(onChanged: onChanged, errorText: errorText),
      ),
    );
  }

  testWidgets('renderiza exactamente 4 casillas de texto', (tester) async {
    await tester.pumpWidget(buildTestable((_) {}));
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('reporta el PIN concatenado a medida que se escribe', (tester) async {
    String? ultimoValor;
    await tester.pumpWidget(buildTestable((v) => ultimoValor = v));

    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.pump();
    expect(ultimoValor, '1');

    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.pump();
    expect(ultimoValor, '12');
  });

  testWidgets('muestra el texto de error cuando se provee', (tester) async {
    await tester.pumpWidget(buildTestable((_) {}, errorText: 'Los PIN no coinciden'));
    expect(find.text('Los PIN no coinciden'), findsOneWidget);
  });
}