import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

import '/backend/schema/structs/index.dart';

import '/auth/custom_auth/custom_auth_user_provider.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'serialization_util.dart';

import '/index.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  RdoproAuthUser? initialUser;
  RdoproAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;

  /// Determines whether the app will refresh and build again when a sign
  /// in or sign out happens. This is useful when the app is launched or
  /// on an unexpected logout. However, this must be turned off when we
  /// intend to sign in/out and then navigate or perform any actions after.
  /// Otherwise, this will trigger a refresh and interrupt the action(s).
  bool notifyOnAuthChange = true;

  bool get loading => user == null || showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  /// Mark as not needing to notify on a sign in / out when we intend
  /// to perform subsequent actions (such as navigation) afterwards.
  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(RdoproAuthUser newUser) {
    final shouldUpdate =
        user?.uid == null || newUser.uid == null || user?.uid != newUser.uid;
    initialUser ??= newUser;
    user = newUser;
    // Refresh the app on auth change unless explicitly marked otherwise.
    // No need to update unless the user has changed.
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    // Once again mark the notifier as needing to update on auth change
    // (in order to catch sign in / out events).
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier) => GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      errorBuilder: (context, state) =>
          appStateNotifier.loggedIn ? InicioWidget() : LoginWidget(),
      routes: [
        FFRoute(
          name: '_initialize',
          path: '/',
          builder: (context, _) =>
              appStateNotifier.loggedIn ? InicioWidget() : LoginWidget(),
        ),
        FFRoute(
          name: LoginWidget.routeName,
          path: LoginWidget.routePath,
          builder: (context, params) => LoginWidget(),
        ),
        FFRoute(
          name: ObraTarefasWidget.routeName,
          path: ObraTarefasWidget.routePath,
          builder: (context, params) => ObraTarefasWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: ObraAddEtapaWidget.routeName,
          path: ObraAddEtapaWidget.routePath,
          builder: (context, params) => ObraAddEtapaWidget(
            obraServidorId: params.getParam(
                  'obraServidorId',
                  ParamType.int,
                ) ??
                0,
            obraUuid: params.getParam(
                  'obraUuid',
                  ParamType.String,
                ) ??
                '',
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
          ),
        ),
        FFRoute(
          name: ObraAddTarefaWidget.routeName,
          path: ObraAddTarefaWidget.routePath,
          builder: (context, params) => ObraAddTarefaWidget(
            obraUuid: params.getParam(
                  'obraUuid',
                  ParamType.String,
                ) ??
                '',
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            etapaUuidInicial: params.getParam(
              'etapaUuidInicial',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: ObraAddComposicaoWidget.routeName,
          path: ObraAddComposicaoWidget.routePath,
          builder: (context, params) => ObraAddComposicaoWidget(
            obraUuid: params.getParam(
                  'obraUuid',
                  ParamType.String,
                ) ??
                '',
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            etapaUuidInicial: params.getParam(
              'etapaUuidInicial',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: ObraAddRelatorioWidget.routeName,
          path: ObraAddRelatorioWidget.routePath,
          builder: (context, params) => ObraAddRelatorioWidget(
            id: params.getParam(
              'id',
              ParamType.int,
            ),
            uuid: params.getParam(
              'uuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: AddAtividadeRelatorioWidget.routeName,
          path: AddAtividadeRelatorioWidget.routePath,
          builder: (context, params) => AddAtividadeRelatorioWidget(
            relatorioId: params.getParam(
              'relatorioId',
              ParamType.int,
            ),
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            atividadeId: params.getParam(
              'atividadeId',
              ParamType.int,
            ),
            atividadeUuid: params.getParam(
              'atividadeUuid',
              ParamType.String,
            ),
            relatorioUuid: params.getParam(
              'relatorioUuid',
              ParamType.String,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
            novaAtividade: params.getParam(
              'novaAtividade',
              ParamType.bool,
            ),
          ),
        ),
        FFRoute(
          name: AddAtividadeRelatorioEtapaWidget.routeName,
          path: AddAtividadeRelatorioEtapaWidget.routePath,
          builder: (context, params) => AddAtividadeRelatorioEtapaWidget(
            relatorioId: params.getParam(
              'relatorioId',
              ParamType.int,
            ),
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            atividadeId: params.getParam(
              'atividadeId',
              ParamType.int,
            ),
            atividadeUuid: params.getParam(
              'atividadeUuid',
              ParamType.String,
            ),
            relatorioUuid: params.getParam(
              'relatorioUuid',
              ParamType.String,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: SelecionarTarefaAtividadeWidget.routeName,
          path: SelecionarTarefaAtividadeWidget.routePath,
          builder: (context, params) => SelecionarTarefaAtividadeWidget(
            relatorioID: params.getParam(
              'relatorioID',
              ParamType.int,
            ),
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            relatorioUuid: params.getParam(
              'relatorioUuid',
              ParamType.String,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: InicioWidget.routeName,
          path: InicioWidget.routePath,
          requireAuth: true,
          builder: (context, params) => InicioWidget(),
        ),
        FFRoute(
          name: RelatoriosGeraisWidget.routeName,
          path: RelatoriosGeraisWidget.routePath,
          requireAuth: true,
          builder: (context, params) => const RelatoriosGeraisWidget(),
        ),
        FFRoute(
          name: CadastrarRelatorioGeralWidget.routeName,
          path: CadastrarRelatorioGeralWidget.routePath,
          requireAuth: true,
          builder: (context, params) => const CadastrarRelatorioGeralWidget(),
        ),
        FFRoute(
          name: ChecklistsWidget.routeName,
          path: ChecklistsWidget.routePath,
          builder: (context, params) => ChecklistsWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
          ),
        ),
        FFRoute(
          name: AplicarChecklistWidget.routeName,
          path: AplicarChecklistWidget.routePath,
          builder: (context, params) => AplicarChecklistWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
          ),
        ),
        FFRoute(
          name: ChecklistRespondendoWidget.routeName,
          path: ChecklistRespondendoWidget.routePath,
          builder: (context, params) => ChecklistRespondendoWidget(),
        ),
        FFRoute(
          name: MenuWidget.routeName,
          path: MenuWidget.routePath,
          builder: (context, params) => MenuWidget(),
        ),
        FFRoute(
          name: NotificacoesWidget.routeName,
          path: NotificacoesWidget.routePath,
          builder: (context, params) => NotificacoesWidget(),
        ),
        FFRoute(
          name: MedicoesWidget.routeName,
          path: MedicoesWidget.routePath,
          builder: (context, params) => MedicoesWidget(),
        ),
        FFRoute(
          name: MedicaoDetalhesWidget.routeName,
          path: MedicaoDetalhesWidget.routePath,
          builder: (context, params) => MedicaoDetalhesWidget(
            medicaoId: params.getParam(
              'medicaoId',
              ParamType.int,
            ),
          ),
        ),
        FFRoute(
          name: SincronizacoesWidget.routeName,
          path: SincronizacoesWidget.routePath,
          builder: (context, params) => SincronizacoesWidget(),
        ),
        FFRoute(
          name: SincronizandoWidget.routeName,
          path: SincronizandoWidget.routePath,
          builder: (context, params) => SincronizandoWidget(),
        ),
        FFRoute(
          name: CadastrarObraWidget.routeName,
          path: CadastrarObraWidget.routePath,
          builder: (context, params) => CadastrarObraWidget(),
        ),
        FFRoute(
          name: CadastrarClienteWidget.routeName,
          path: CadastrarClienteWidget.routePath,
          builder: (context, params) => CadastrarClienteWidget(
            clienteUuid: params.getParam(
              'clienteUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: ClientesWidget.routeName,
          path: ClientesWidget.routePath,
          builder: (context, params) => ClientesWidget(),
        ),
        FFRoute(
          name: ClienteDetalhesWidget.routeName,
          path: ClienteDetalhesWidget.routePath,
          builder: (context, params) => ClienteDetalhesWidget(
            clienteServidorId: params.getParam(
              'clienteServidorId',
              ParamType.int,
            ),
            clienteUuid: params.getParam(
              'clienteUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: ChecklistRespondendoCopyWidget.routeName,
          path: ChecklistRespondendoCopyWidget.routePath,
          builder: (context, params) => ChecklistRespondendoCopyWidget(),
        ),
        FFRoute(
          name: DetalhesObraWidget.routeName,
          path: DetalhesObraWidget.routePath,
          builder: (context, params) => DetalhesObraWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: ComentariosObraNovoWidget.routeName,
          path: ComentariosObraNovoWidget.routePath,
          builder: (context, params) => ComentariosObraNovoWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: OcorrenciasObraWidget.routeName,
          path: OcorrenciasObraWidget.routePath,
          builder: (context, params) => OcorrenciasObraWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: AnexosObraWidget.routeName,
          path: AnexosObraWidget.routePath,
          builder: (context, params) => AnexosObraWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: InsumosObraWidget.routeName,
          path: InsumosObraWidget.routePath,
          builder: (context, params) => InsumosObraWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: EquipamentosObraWidget.routeName,
          path: EquipamentosObraWidget.routePath,
          builder: (context, params) => EquipamentosObraWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: MaoObraWidget.routeName,
          path: MaoObraWidget.routePath,
          builder: (context, params) => MaoObraWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: OrdensServicoObraWidget.routeName,
          path: OrdensServicoObraWidget.routePath,
          builder: (context, params) => OrdensServicoObraWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: RelatoriosObraWidget.routeName,
          path: RelatoriosObraWidget.routePath,
          builder: (context, params) => RelatoriosObraWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: GruposObrasWidget.routeName,
          path: GruposObrasWidget.routePath,
          builder: (context, params) => GruposObrasWidget(),
        ),
        FFRoute(
          name: LocaisWidget.routeName,
          path: LocaisWidget.routePath,
          builder: (context, params) => LocaisWidget(),
        ),
        FFRoute(
          name: FuncoesMaoObraWidget.routeName,
          path: FuncoesMaoObraWidget.routePath,
          builder: (context, params) => FuncoesMaoObraWidget(),
        ),
        FFRoute(
          name: MaoObraCadastrosWidget.routeName,
          path: MaoObraCadastrosWidget.routePath,
          builder: (context, params) => MaoObraCadastrosWidget(),
        ),
        FFRoute(
          name: EquipamentosCadastrosWidget.routeName,
          path: EquipamentosCadastrosWidget.routePath,
          builder: (context, params) => EquipamentosCadastrosWidget(),
        ),
        FFRoute(
          name: InsumosCadastrosWidget.routeName,
          path: InsumosCadastrosWidget.routePath,
          builder: (context, params) => InsumosCadastrosWidget(),
        ),
        FFRoute(
          name: EditarPerfilWidget.routeName,
          path: EditarPerfilWidget.routePath,
          builder: (context, params) => EditarPerfilWidget(),
        ),
        FFRoute(
          name: UsuariosWidget.routeName,
          path: UsuariosWidget.routePath,
          builder: (context, params) => UsuariosWidget(),
        ),
        FFRoute(
          name: CadastrarUsuarioWidget.routeName,
          path: CadastrarUsuarioWidget.routePath,
          builder: (context, params) => CadastrarUsuarioWidget(
            usuarioUuid: params.getParam(
              'usuarioUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: UsuarioDetalhesWidget.routeName,
          path: UsuarioDetalhesWidget.routePath,
          builder: (context, params) => UsuarioDetalhesWidget(
            usuarioUuid: params.getParam(
              'usuarioUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: RelatorioDetalhesWidget.routeName,
          path: RelatorioDetalhesWidget.routePath,
          builder: (context, params) => RelatorioDetalhesWidget(
            id: params.getParam(
              'id',
              ParamType.int,
            ),
            uuid: params.getParam(
              'uuid',
              ParamType.String,
            ),
            camufladoId: params.getParam(
              'camufladoId',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: EditarObraWidget.routeName,
          path: EditarObraWidget.routePath,
          builder: (context, params) => EditarObraWidget(
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: ShowAtividadeRelatorioWidget.routeName,
          path: ShowAtividadeRelatorioWidget.routePath,
          builder: (context, params) => ShowAtividadeRelatorioWidget(
            relatorioId: params.getParam(
              'relatorioId',
              ParamType.int,
            ),
            obraId: params.getParam(
              'obraId',
              ParamType.int,
            ),
            atividadeId: params.getParam(
              'atividadeId',
              ParamType.int,
            ),
            relatorioUuid: params.getParam(
              'relatorioUuid',
              ParamType.String,
            ),
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
            atividadeUuid: params.getParam(
              'atividadeUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: DetalhesOrdemServicoWidget.routeName,
          path: DetalhesOrdemServicoWidget.routePath,
          builder: (context, params) => DetalhesOrdemServicoWidget(
            ordemUuid: params.getParam(
              'ordemUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: OrdemServicoDetalhesWidget.routeName,
          path: OrdemServicoDetalhesWidget.routePath,
          builder: (context, params) => OrdemServicoDetalhesWidget(
            ordemUuid: params.getParam(
              'ordemUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: LocaisObraWidget.routeName,
          path: LocaisObraWidget.routePath,
          builder: (context, params) => LocaisObraWidget(
            obraUuid: params.getParam(
              'obraUuid',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: AlterarSenhaWidget.routeName,
          path: AlterarSenhaWidget.routePath,
          builder: (context, params) => AlterarSenhaWidget(),
        ),
        FFRoute(
          name: ExcluirContaWidget.routeName,
          path: ExcluirContaWidget.routePath,
          builder: (context, params) => ExcluirContaWidget(),
        ),
      ].map((r) => r.toRoute(appStateNotifier)).toList(),
    );

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void goNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : goNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void pushNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : pushNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void safePop() {
    // If there is only one route on the stack, navigate to the initial
    // page instead of popping.
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension GoRouterExtensions on GoRouter {
  AppStateNotifier get appState => AppStateNotifier.instance;
  void prepareAuthEvent([bool ignoreRedirect = false]) =>
      appState.hasRedirect() && !ignoreRedirect
          ? null
          : appState.updateNotifyOnAuthChange(false);
  bool shouldRedirect(bool ignoreRedirect) =>
      !ignoreRedirect && appState.hasRedirect();
  void clearRedirectLocation() => appState.clearRedirectLocation();
  void setRedirectLocationIfUnset(String location) =>
      appState.updateNotifyOnAuthChange(false);
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  // Parameters are empty if the params map is empty or if the only parameter
  // present is the special extra parameter reserved for the transition info.
  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
    StructBuilder<T>? structBuilder,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    // Got parameter from `extras`, so just directly return it.
    if (param is! String) {
      return param;
    }
    // Return serialized value.
    return deserializeParam<T>(
      param,
      type,
      isList,
      structBuilder: structBuilder,
    );
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        redirect: (context, state) {
          if (appStateNotifier.shouldRedirect) {
            final redirectLocation = appStateNotifier.getRedirectLocation();
            appStateNotifier.clearRedirectLocation();
            return redirectLocation;
          }

          if (requireAuth && !appStateNotifier.loggedIn) {
            appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
            return '/login';
          }
          return null;
        },
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: appStateNotifier.loading
                ? SizedBox.expand(
                    key: const ValueKey('app_splash'),
                    child: Image.asset(
                      'assets/images/split-entrada.png',
                      fit: BoxFit.cover,
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('app_content'),
                    child: page,
                  ),
          );

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  name: state.name,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(
                  key: state.pageKey, name: state.name, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
