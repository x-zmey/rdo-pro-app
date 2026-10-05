import 'dart:async';

import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth/app_update_check.dart';
import 'auth/custom_auth/auth_util.dart';
import 'auth/custom_auth/custom_auth_user_provider.dart';

import '/backend/api_requests/api_calls.dart';
import '/backend/api_requests/api_manager.dart';
import '/backend/sqlite/empresa_multi_tenant_sqlite.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/push/push_device_registration.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/nav/nav.dart';
import 'index.dart';

Timer? _tokenRefreshTimer;

/// Renova o token quando restam menos de 24h (janela de sessão ~15 dias no server).
/// Cada refresh bem-sucedido emite um novo token com TTL completo (sliding).
const Duration _tokenRefreshLeadTime = Duration(hours: 24);

Future<bool> _tryRefreshAccessToken(FFAppState appState) async {
  final token = appState.UserToken.trim();
  final exp = currentAuthTokenExpiration;
  if (token.isEmpty || exp == null) {
    return false;
  }

  final remaining = exp.difference(DateTime.now());
  if (remaining.isNegative) {
    return false;
  }
  if (remaining > _tokenRefreshLeadTime) {
    return true;
  }

  final resp = await RefreshTokenCall.call(token: token);
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    return false;
  }
  final body = resp.jsonBody;
  final newToken = RefreshTokenCall.token(body);
  final newExpRaw = RefreshTokenCall.expiresAt(body);
  final newExp =
      newExpRaw != null ? DateTime.tryParse(newExpRaw)?.toLocal() : null;
  if (newToken == null || newToken.isEmpty) {
    return false;
  }
  appState.UserToken = newToken;
  authManager.updateAuthUserData(
    authenticationToken: newToken,
    tokenExpiration: newExp,
    authUid: appState.UserUuid.isNotEmpty ? appState.UserUuid : null,
  );
  return true;
}

void _startAutoTokenRefresh(FFAppState appState) {
  _tokenRefreshTimer?.cancel();
  // Checa a cada 15 min; renova se faltar < 24h para o fim da sessão.
  _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
    unawaited(_tryRefreshAccessToken(appState));
  });
  unawaited(_tryRefreshAccessToken(appState));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  // Evita bloco cinza gigante (RenderErrorBox ~100000px) quando um filho quebra
  // em release — ex.: seção abaixo de Status em Gerenciar Atividade.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    assert(() {
      debugPrint('ErrorWidget: ${details.exceptionAsString()}');
      return true;
    }());
    return const Material(
      color: Color(0xFFFFEBEE),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Não foi possível montar este trecho da tela. '
            'Volte e abra de novo; se continuar, sincronize o app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFB71C1C), fontSize: 13),
          ),
        ),
      ),
    );
  };

  // Sem depender de download de fontes (rede / Play Services instáveis).
  GoogleFonts.config.allowRuntimeFetching = false;

  await SQLiteManager.initialize();
  await FlutterFlowTheme.initialize();

  await authManager.initialize();

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();

  if (appState.UserToken.isNotEmpty) {
    unawaited(refreshAppStatePermissoesFromSqlite());
  }

  ApiManager.setUnauthorizedHandler(() async {
    // Evita manter navegação ativa com token expirado.
    final context = appNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sua sessão expirou. Faça login novamente.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          duration: const Duration(milliseconds: 1400),
          backgroundColor: FlutterFlowTheme.of(context).warning,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
    }
    await authManager.signOut();
    appState.clearAuthSession();
    if (context != null) {
      context.go(LoginWidget.routePath);
    }
  });

  ApiManager.setAccessTokenProvider(() => FFAppState().UserToken);
  ApiManager.setTenantUserIdProvider(() => FFAppState().activeTenantUserId);
  ApiManager.setRefreshTokenHandler(() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      return false;
    }
    final resp = await RefreshTokenCall.call(token: token);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      return false;
    }
    final body = resp.jsonBody;
    final newToken = RefreshTokenCall.token(body);
    final newExpRaw = RefreshTokenCall.expiresAt(body);
    final newExp =
        newExpRaw != null ? DateTime.tryParse(newExpRaw)?.toLocal() : null;
    if (newToken == null || newToken.isEmpty) {
      return false;
    }
    FFAppState().UserToken = newToken;
    authManager.updateAuthUserData(
      authenticationToken: newToken,
      tokenExpiration: newExp,
      authUid: FFAppState().UserUuid.isNotEmpty ? FFAppState().UserUuid : null,
    );
    return true;
  });

  // Alinha GoRouter (`loggedIn`) com sessão já salva pelo login FlutterFlow.
  final persistedToken = appState.UserToken.trim();
  if (persistedToken.isNotEmpty) {
    await authManager.signIn(
      authenticationToken: persistedToken,
      tokenExpiration: currentAuthTokenExpiration,
      authUid: appState.UserUuid.isNotEmpty ? appState.UserUuid : null,
    );
  }
  _startAutoTokenRefresh(appState);

  try {
    await initPushDeviceRegistration();
  } catch (e, s) {
    debugPrint('Error initializing push device registration: $e');
  }

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  late Stream<RdoproAuthUser> userStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
    userStream = rdoproAuthUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
        if (_appStateNotifier.showSplashImage) {
          _appStateNotifier.stopShowingSplashImage();
        }
      });

    unawaited(
      scheduleAppUpdateCheck(
        isSplashVisible: () => _appStateNotifier.showSplashImage,
        navigatorContext: () => appNavigatorKey.currentContext,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_tryRefreshAccessToken(FFAppState()));
    }
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'rdopro',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: false,
      ),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}
