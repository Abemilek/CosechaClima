import 'dart:async' show runZonedGuarded;

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/app/app_state.dart';
import 'core/error/error_reporter.dart';
import 'core/local/local_data_migration.dart';
import 'core/theme/app_theme.dart';
import 'features/catalogo/data/services/catalogo_service.dart';
import 'features/catalogo/presentation/view_models/catalogo_view_model.dart';
import 'routing/app_gate.dart';

void main() {
  runZonedGuarded(() async {
    FlutterError.onError = (details) {
      ErrorReporter.report(
        details.exception,
        details.stack ?? StackTrace.current,
        context: 'FlutterError',
      );
    };
    WidgetsFlutterBinding.ensureInitialized();

    await initializeDateFormatting('es');
    await LocalDataMigration.ejecutar();

    runApp(const CosechaClimaApp());
  }, (error, stack) => ErrorReporter.report(error, stack, context: 'zone'));
}

class CosechaClimaApp extends StatelessWidget {
  const CosechaClimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(
          create: (_) =>
              CatalogoViewModel(CatalogoService())..cargarCatalogos(),
        ),
      ],
      child: MaterialApp(
        title: 'CosechaClima',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AppGate(),
      ),
    );
  }
}
