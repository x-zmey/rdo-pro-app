import 'dart:async';

import '/app_version.dart';
import '/auth/biometric_login_store.dart';
import '/auth/custom_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/push/push_device_registration.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/auth/tenant_auth_payload.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_model.dart';
export 'login_model.dart';

/// Portal web (Vue) — mesmas rotas de `frontend` (`forgot-password`, `register`).
const String _kPortalBaseUrl = 'https://rdopro.com.br';

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  static String routeName = 'Login';
  static String routePath = '/login';

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget>
    with TickerProviderStateMixin {
  late LoginModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  bool _loggingIn = false;
  bool? _isOnline;
  bool _showBiometricLogin = false;

  final animationsMap = <String, AnimationInfo>{};

  Future<void> _openPortalPath(String path) async {
    final uri = Uri.parse('$_kPortalBaseUrl$path');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Não foi possível abrir o navegador. Tente: $uri',
          style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
        ),
        backgroundColor: FlutterFlowTheme.of(context).error,
      ),
    );
  }

  Future<void> _refreshBiometricUiFlag() async {
    final show = await BiometricLoginStore.shouldShowLoginButton();
    if (mounted) {
      setState(() => _showBiometricLogin = show);
    }
  }

  String _mensagemBiometria(BiometricPromptResult status) {
    switch (status) {
      case BiometricPromptResult.cancelled:
        return 'Autenticação cancelada.';
      case BiometricPromptResult.notAvailable:
        return 'Biometria indisponível neste aparelho. Use e-mail e senha.';
      case BiometricPromptResult.notEnrolled:
        return 'Cadastre impressão digital ou rosto nas configurações do aparelho.';
      case BiometricPromptResult.credentialsMissing:
        return 'Credenciais não encontradas. Entre com e-mail e senha e ative a biometria de novo.';
      case BiometricPromptResult.error:
        return 'Não foi possível autenticar. Tente de novo ou use e-mail e senha.';
      case BiometricPromptResult.success:
        return '';
    }
  }

  Future<void> _promptEnableBiometricIfNeeded(
    String email,
    String password,
  ) async {
    if (!await BiometricLoginStore.hardwareAvailable()) {
      return;
    }
    if (await BiometricLoginStore.isEnabled()) {
      await BiometricLoginStore.saveCredentials(
        email: email,
        password: password,
      );
      await _refreshBiometricUiFlag();
      return;
    }
    if (!mounted) {
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrar com biometria?'),
        content: Text(
          'Nas próximas vezes você poderá usar o mesmo desbloqueio do aparelho '
          '(impressão digital, rosto ou PIN) para entrar. '
          'E-mail e senha ficam só no cofre criptografado do dispositivo.',
          style: FlutterFlowTheme.of(context).bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      await BiometricLoginStore.saveCredentials(
        email: email,
        password: password,
      );
      await _refreshBiometricUiFlag();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Biometria ativada para este usuário.',
              style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
            ),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
      }
    }
  }

  Future<void> _attemptLogin(
    String email,
    String password, {
    int? tenantUserId,
    required bool offerBiometricSetup,
  }) async {
    // Permite 2ª chamada após escolher empresa (1ª ainda mantém _loggingIn = true).
    final isTenantSelectionRetry = tenantUserId != null && tenantUserId > 0;
    if (_loggingIn && !isTenantSelectionRetry) {
      return;
    }
    setState(() => _loggingIn = true);
    try {
      _model.apiResultrtk = await LoginCall.call(
        email: email,
        password: password,
        tenantUserId: tenantUserId,
      );

      if (!mounted) {
        return;
      }

      final resp = _model.apiResultrtk;
      if (resp?.exception != null ||
          (resp?.statusCode == -1 && resp?.jsonBody == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha de rede. Verifique sua internet e tente de novo.',
              style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
            ),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        return;
      }

      final loginBody = resp?.jsonBody ?? '';

      final needsTenantPick = LoginCall.requiresTenantSelection(loginBody) == true
          || LoginCall.status(loginBody) == 'selecionar_empresa';
      if (needsTenantPick) {
        final list = LoginCall.memberships(loginBody) ?? [];
        if (!mounted) return;
        final picked = await showDialog<int>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            int? selected = list.isNotEmpty
                ? castToType<int>(getJsonField(list.first, r'''$.tenant_user_id'''))
                : null;
            return StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('Selecione a empresa'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: list.map((m) {
                    final tid = castToType<int>(
                      getJsonField(m, r'''$.tenant_user_id'''),
                    );
                    final nome = getJsonField(m, r'''$.empresa_nome''')?.toString() ??
                        'Empresa';
                    final tipo = getJsonField(m, r'''$.type''')?.toString() ?? '';
                    return RadioListTile<int>(
                      value: tid ?? 0,
                      groupValue: selected,
                      title: Text('$nome ($tipo)'),
                      onChanged: (v) => setDialogState(() => selected = v),
                    );
                  }).toList(),
                ),
                actions: [
                  TextButton(
                    onPressed: (selected != null && selected! > 0)
                        ? () => Navigator.pop(ctx, selected)
                        : null,
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            );
          },
        );
        if (picked != null && picked > 0 && mounted) {
          await _attemptLogin(
            email,
            password,
            tenantUserId: picked,
            offerBiometricSetup: offerBiometricSetup,
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Selecione uma empresa para continuar.',
                style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
              ),
              backgroundColor: FlutterFlowTheme.of(context).warning,
            ),
          );
        }
        return;
      }

      if (resp?.statusCode == 422) {
        final msg = LoginCall.message(loginBody);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                msg ?? 'Verifique os dados informados.',
                style: TextStyle(
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
              duration: const Duration(seconds: 5),
              backgroundColor: FlutterFlowTheme.of(context).error,
            ),
          );
        }
        return;
      }

      if (LoginCall.status(loginBody) == 'sucesso') {
        final token = LoginCall.userToken(loginBody);
        if (token == null || token.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Resposta do servidor incompleta (token). Tente novamente ou contate o suporte.',
                style: TextStyle(
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ),
              backgroundColor: FlutterFlowTheme.of(context).error,
            ),
          );
          return;
        }

        final uid = LoginCall.userID(loginBody);
        final cId = LoginCall.creatorId(loginBody);
        final uUuid = LoginCall.userUuid(loginBody);
        final cUuid = LoginCall.creatorUuid(loginBody);
        final tokenExpiresAtRaw = LoginCall.expiresAt(loginBody);
        final tokenExpiresAt = tokenExpiresAtRaw != null
            ? DateTime.tryParse(tokenExpiresAtRaw)?.toLocal()
            : null;

        FFAppState().UserID = valueOrDefault<int>(uid, 0);
        FFAppState().UserToken = token;
        FFAppState().UserName = valueOrDefault<String>(
          LoginCall.userNome(loginBody),
          'Usuário',
        );
        FFAppState().UserUuid = valueOrDefault<String>(uUuid, '');
        await applyTenantAuthPayload(
          loginBody,
          fallbackTenantUserId: tenantUserId,
        );
        await ensureCreatorUuidForActiveTenant();
        FFAppState().notifyTenantContextChanged();
        if (FFAppState().creatorId <= 0) {
          FFAppState().creatorId = valueOrDefault<int>(
            cId,
            valueOrDefault<int>(uid, 0),
          );
        }
        if (FFAppState().activeTenantUserId <= 0) {
          FFAppState().activeTenantUserId = valueOrDefault<int>(
            LoginCall.activeTenantUserId(loginBody),
            valueOrDefault<int>(cId, 0),
          );
        }
        if (FFAppState().creatorUuid.isEmpty) {
          FFAppState().creatorUuid = valueOrDefault<String>(
            cUuid,
            valueOrDefault<String>(uUuid, ''),
          );
        }
        if (FFAppState().UserPermissoes == null ||
            (FFAppState().UserPermissoes is List &&
                (FFAppState().UserPermissoes as List).isEmpty)) {
          FFAppState().UserPermissoes =
              LoginCall.permissoes(loginBody) ?? <dynamic>[];
        }
        await authManager.signIn(
          authenticationToken: token,
          tokenExpiration: tokenExpiresAt,
          authUid: uUuid,
        );
        safeSetState(() {});

        unawaited(syncPushDeviceToApi());

        if (offerBiometricSetup) {
          await _promptEnableBiometricIfNeeded(email, password);
        }

        if (!mounted) {
          return;
        }
        context.pushNamed(
          InicioWidget.routeName,
          extra: <String, dynamic>{
            '__transition_info__': TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.bottomToTop,
            ),
          },
        );
      } else {
        if (!offerBiometricSetup) {
          await BiometricLoginStore.clearAll();
          await _refreshBiometricUiFlag();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Senha incorreta ou alterada. Faça login com e-mail e senha e ative a biometria de novo.',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).primaryText,
                  ),
                ),
                duration: const Duration(seconds: 5),
                backgroundColor: FlutterFlowTheme.of(context).error,
              ),
            );
          }
        }
        final msg = LoginCall.message(loginBody);
        final feedback = (msg != null && msg.toString().trim().isNotEmpty)
            ? msg.toString().trim()
            : 'E-mail ou senha incorretos.';
        if (offerBiometricSetup && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                feedback,
                style:
                    TextStyle(color: FlutterFlowTheme.of(context).primaryText),
              ),
              duration: const Duration(seconds: 4),
              backgroundColor: FlutterFlowTheme.of(context).error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loggingIn = false);
      }
    }
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    if (_loggingIn) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_isOnline == false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sem conexão. Conecte-se à internet para entrar.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    final email = _model.emailAddressTextController!.text.trim();
    final password = _model.passwordTextController!.text;
    await _attemptLogin(
      email,
      password,
      offerBiometricSetup: true,
    );
  }

  Future<void> _loginWithBiometric() async {
    FocusScope.of(context).unfocus();
    if (_isOnline == false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sem conexão. Conecte-se à internet para entrar.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    if (_loggingIn) {
      return;
    }
    final result = await BiometricLoginStore.readWithBiometric(
      localizedReason: 'Entrar no RDO Pro',
    );
    if (!mounted) {
      return;
    }
    if (!result.isSuccess) {
      final msg = _mensagemBiometria(result.status);
      if (msg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
            ),
            backgroundColor: result.status == BiometricPromptResult.cancelled
                ? FlutterFlowTheme.of(context).secondary
                : FlutterFlowTheme.of(context).error,
          ),
        );
      }
      if (result.status == BiometricPromptResult.credentialsMissing) {
        await _refreshBiometricUiFlag();
      }
      return;
    }
    _model.emailAddressTextController?.text = result.email!;
    _model.passwordTextController?.text = result.password!;
    await _attemptLogin(
      result.email!,
      result.password!,
      offerBiometricSetup: false,
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.result = await actions.checkInternetConnection();
      if (!mounted) return;
      setState(() => _isOnline = _model.result);
      if (_model.result != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sem conexão com a internet. O login precisa de rede.',
              style: TextStyle(
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
      await _refreshBiometricUiFlag();
    });

    _model.emailAddressTextController ??= TextEditingController();
    _model.emailAddressFocusNode ??= FocusNode();

    _model.passwordTextController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();


    animationsMap.addAll({
      'containerOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          VisibilityEffect(duration: 1.ms),
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 300.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
          MoveEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 300.0.ms,
            begin: Offset(0.0, 140.0),
            end: Offset(0.0, 0.0),
          ),
          ScaleEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 300.0.ms,
            begin: Offset(0.9, 1.0),
            end: Offset(1.0, 1.0),
          ),
          TiltEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 300.0.ms,
            begin: Offset(-0.349, 0),
            end: Offset(0, 0),
          ),
        ],
      ),
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  InputDecoration _campoDecoracao(
    BuildContext context, {
    required String label,
    Widget? suffixIcon,
  }) {
    final t = FlutterFlowTheme.of(context);
    OutlineInputBorder borda(Color cor, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cor, width: w),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: t.secondaryText),
      filled: true,
      fillColor: t.secondaryBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: borda(t.alternate),
      focusedBorder: borda(t.primary, 1.5),
      errorBorder: borda(t.error, 1.5),
      focusedErrorBorder: borda(t.error, 1.5),
      suffixIcon: suffixIcon,
    );
  }

  Widget _bannerOffline(BuildContext context) {
    final t = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: t.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sem conexão. Verifique a rede antes de entrar.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkTexto(
    BuildContext context, {
    required String prefixo,
    required String link,
    required VoidCallback onTap,
    Color? linkColor,
  }) {
    final t = FlutterFlowTheme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          prefixo,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: t.secondaryText,
          ),
        ),
        InkWell(
          onTap: onTap,
          child: Text(
            link,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: linkColor ?? t.primary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FlutterFlowTheme.of(context);
    final altura = MediaQuery.sizeOf(context).height;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: t.primaryBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: altura - 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Image.asset(
                      'assets/images/logo-md.png',
                      width: 200,
                      height: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Entrar',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: t.primaryText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Acesse sua conta com e-mail e senha',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: t.secondaryText,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: t.secondaryBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.alternate),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isOnline == false) _bannerOffline(context),
                              TextFormField(
                                controller: _model.emailAddressTextController,
                                focusNode: _model.emailAddressFocusNode,
                                autofocus: true,
                                autofillHints: const [AutofillHints.email],
                                obscureText: false,
                                autocorrect: false,
                                enableSuggestions: false,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    _model.passwordFocusNode?.requestFocus(),
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: t.primaryText,
                                ),
                                decoration:
                                    _campoDecoracao(context, label: 'E-mail'),
                                validator: _model
                                    .emailAddressTextControllerValidator
                                    .asValidator(context),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _model.passwordTextController,
                                focusNode: _model.passwordFocusNode,
                                autofillHints: const [AutofillHints.password],
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_loggingIn) _submitLogin();
                                },
                                obscureText: !_model.passwordVisibility,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: t.primaryText,
                                ),
                                decoration: _campoDecoracao(
                                  context,
                                  label: 'Senha',
                                  suffixIcon: InkWell(
                                    onTap: () => safeSetState(() =>
                                        _model.passwordVisibility =
                                            !_model.passwordVisibility),
                                    focusNode:
                                        FocusNode(skipTraversal: true),
                                    child: Icon(
                                      _model.passwordVisibility
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: t.secondaryText,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                validator: _model
                                    .passwordTextControllerValidator
                                    .asValidator(context),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      _openPortalPath('/forgot-password'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Esqueceu a senha?',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: t.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed:
                                    _loggingIn ? null : () => _submitLogin(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: t.primary,
                                  disabledBackgroundColor:
                                      t.primary.withValues(alpha: 0.5),
                                  minimumSize:
                                      const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child: _loggingIn
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: t.info,
                                        ),
                                      )
                                    : Text(
                                        'Entrar',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: t.info,
                                        ),
                                      ),
                              ),
                              if (_showBiometricLogin) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _loggingIn
                                      ? null
                                      : _loginWithBiometric,
                                  icon: Icon(
                                    Icons.fingerprint_rounded,
                                    size: 20,
                                    color: t.primary,
                                  ),
                                  label: Text(
                                    'Entrar com biometria',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: t.primary,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize:
                                        const Size(double.infinity, 46),
                                    side: BorderSide(color: t.alternate),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).animateOnPageLoad(
                    animationsMap['containerOnPageLoadAnimation']!,
                  ),
                  const SizedBox(height: 20),
                  _linkTexto(
                    context,
                    prefixo: 'Ainda não tem conta?',
                    link: 'Criar conta',
                    onTap: () => _openPortalPath('/register'),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Versão $kAppVersionName',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: t.secondaryText.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
