import 'dart:async' show runZonedGuarded, unawaited;

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/config/environment.dart';
import 'core/error/error_reporter.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/services/auth_service.dart';
import 'features/auth/presentation/view_models/auth_view_model.dart';
import 'features/catalogo/data/services/catalogo_service.dart';
import 'features/parcela/data/services/parcela_service.dart';
import 'features/parcela/presentation/view_models/parcela_view_model.dart';
import 'routing/auth_gate.dart';

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

    Environment.validate();

    await initializeDateFormatting('es');
    runApp(const CosechaClimaApp());
  }, (error, stack) => ErrorReporter.report(error, stack, context: 'zone'));
}

class CosechaClimaApp extends StatefulWidget {
  const CosechaClimaApp({super.key});

  @override
  State<CosechaClimaApp> createState() => _CosechaClimaAppState();
}

class _CosechaClimaAppState extends State<CosechaClimaApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  final _apiClient = ApiClient();
  late final AuthViewModel _authProvider;
  late final ParcelaViewModel _parcelaProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthViewModel(AuthService(_apiClient));
    _parcelaProvider = ParcelaViewModel(
      ParcelaService(_apiClient),
      CatalogoService(_apiClient),
    );

    ApiClient.onSessionExpired = () {
      unawaited(_authProvider.cerrarSesion());
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Tu sesión expiró. Volviste al modo público.'),
        ),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _parcelaProvider),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        title: 'CosechaClima',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}
