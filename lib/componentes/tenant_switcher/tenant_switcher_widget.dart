import '/auth/membership_access.dart';
import '/auth/tenant_auth_payload.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/empresa_multi_tenant_sqlite.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Seletor de empresa da sessão (equivalente ao `TenantSwitcher.vue`).
class TenantSwitcherWidget extends StatefulWidget {
  const TenantSwitcherWidget({
    super.key,
    this.compact = true,
    this.fillWidth = false,
  });

  /// `true` para AppBar; `false` para card no menu.
  final bool compact;

  /// No modo compacto, ocupa a largura disponível (ex.: topo da Início).
  final bool fillWidth;

  @override
  State<TenantSwitcherWidget> createState() => _TenantSwitcherWidgetState();
}

class _TenantSwitcherWidgetState extends State<TenantSwitcherWidget> {
  List<dynamic> _memberships = [];
  bool _loading = false;
  bool _switching = false;
  bool _loadedOnce = false;

  int get _activeTenantId => FFAppState().activeTenantUserId;

  String get _activeLabel {
    for (final m in _memberships) {
      if (m is! Map) continue;
      final tid = castToType<int>(getJsonField(m, r'''$.tenant_user_id'''));
      if (tid == _activeTenantId) {
        final nome =
            getJsonField(m, r'''$.empresa_nome''')?.toString().trim();
        if (nome != null && nome.isNotEmpty) return nome;
      }
    }
    final stored = FFAppState().activeEmpresaNome.trim();
    if (stored.isNotEmpty) return stored;
    return 'Empresa ativa';
  }

  bool get _canSwitch => _memberships.length > 1;

  Future<void> _loadMemberships() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;

    setState(() => _loading = true);
    try {
      final res = await AuthMembershipsCall.call(token: token);
      if (!mounted) return;
      if (res.succeeded) {
        final list = AuthMembershipsCall.membershipsList(res.jsonBody) ?? [];
        setState(() {
          _memberships = list;
          _loadedOnce = true;
        });
        for (final m in list) {
          if (m is! Map) continue;
          final tid = castToType<int>(getJsonField(m, r'''$.tenant_user_id'''));
          if (tid == _activeTenantId) {
            final nome =
                getJsonField(m, r'''$.empresa_nome''')?.toString().trim();
            if (nome != null && nome.isNotEmpty) {
              FFAppState().activeEmpresaNome = nome;
            }
            break;
          }
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPicker() async {
    if (!_loadedOnce) {
      await _loadMemberships();
    }
    if (!mounted) return;

    if (!_canSwitch) {
      if (_memberships.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nenhuma empresa vinculada.',
              style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
            ),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
      }
      return;
    }

    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'Empresa da sessão',
                  style: FlutterFlowTheme.of(ctx).titleMedium.override(
                        font: GoogleFonts.interTight(fontWeight: FontWeight.w700),
                        letterSpacing: 0,
                      ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _memberships.map((m) {
                    if (m is! Map) return const SizedBox.shrink();
                    final tid = castToType<int>(
                          getJsonField(m, r'''$.tenant_user_id'''),
                        ) ??
                        0;
                    final nome = getJsonField(m, r'''$.empresa_nome''')
                            ?.toString() ??
                        'Empresa';
                    final tipo =
                        getJsonField(m, r'''$.type''')?.toString() ?? '';
                    final active = tid == _activeTenantId;
                    return ListTile(
                      leading: Icon(
                        active ? Icons.check_circle : Icons.business_outlined,
                        color: active
                            ? FlutterFlowTheme.of(ctx).primary
                            : FlutterFlowTheme.of(ctx).secondaryText,
                      ),
                      title: Text(nome),
                      subtitle: tipo.isNotEmpty ? Text(tipo) : null,
                      selected: active,
                      enabled: !_switching && !active,
                      onTap: active
                          ? null
                          : () => Navigator.pop(ctx, tid),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && picked > 0 && picked != _activeTenantId) {
      await _switchTo(picked);
    }
  }

  Future<void> _switchTo(int tenantUserId) async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty || !mounted) return;

    setState(() => _switching = true);
    try {
      final res = await AuthSwitchTenantCall.call(
        token: token,
        tenantUserId: tenantUserId,
      );
      if (!mounted) return;

      if (!res.succeeded) {
        final msg = LoginCall.message(res.jsonBody) ??
            'Não foi possível trocar de empresa.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
            ),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        return;
      }

      await applyTenantAuthPayload(
        res.jsonBody,
        fallbackTenantUserId: tenantUserId,
      );
      await ensureCreatorUuidForActiveTenant();
      // Garante persistência mesmo se a API não devolver membership completo.
      if (FFAppState().activeTenantUserId != tenantUserId) {
        FFAppState().activeTenantUserId = tenantUserId;
        FFAppState().creatorId = tenantUserId;
      }
      MembershipAccess.persistToPrefs();
      FFAppState().notifyTenantContextChanged();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Empresa alterada. Atualizando dados…',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
          duration: const Duration(seconds: 2),
        ),
      );

      context.goNamed(InicioWidget.routeName);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMemberships());
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final busy = _loading || _switching;

    if (widget.compact) {
      final chip = Material(
        color: theme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: busy ? null : _openPicker,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize:
                  widget.fillWidth ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.primary,
                    ),
                  )
                else
                  Icon(Icons.business_outlined, size: 20, color: theme.primary),
                const SizedBox(width: 8),
                if (widget.fillWidth)
                  Expanded(
                    child: Text(
                      _activeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.labelLarge.override(
                        font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        color: theme.primary,
                        letterSpacing: 0,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 148),
                    child: Text(
                      _activeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.labelMedium.override(
                        font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        color: theme.primary,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                if (_canSwitch)
                  Icon(Icons.expand_more, size: 20, color: theme.primary),
              ],
            ),
          ),
        ),
      );
      if (widget.fillWidth) {
        return SizedBox(width: double.infinity, child: chip);
      }
      return chip;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            color: Color(0x1A000000),
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : _openPicker,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: busy
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.primary,
                          ),
                        )
                      : Icon(Icons.business, color: theme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Empresa da sessão',
                        style: theme.labelSmall.override(
                          font: GoogleFonts.inter(),
                          color: theme.secondaryText,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activeLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleSmall.override(
                          font: GoogleFonts.interTight(
                            fontWeight: FontWeight.w600,
                          ),
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_canSwitch)
                  Icon(Icons.chevron_right, color: theme.secondaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
