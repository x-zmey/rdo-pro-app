import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/api_requests/api_calls.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

enum EmailCadastroStatus {
  idle,
  checking,
  available,
  linkAvailable,
  alreadyLinked,
  error,
}

/// Verificação de e-mail ao cadastrar usuário (multi-empresa).
class CadastroUsuarioEmailFlow {
  CadastroUsuarioEmailFlow({
    required this.emailController,
    required this.onChanged,
  });

  final TextEditingController emailController;
  final VoidCallback onChanged;

  EmailCadastroStatus status = EmailCadastroStatus.idle;
  String message = '';
  Map<String, dynamic>? existingUser;
  Timer? _debounce;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool get canShowNewUserForm => status == EmailCadastroStatus.available;

  void dispose() {
    _debounce?.cancel();
  }

  void reset() {
    _debounce?.cancel();
    status = EmailCadastroStatus.idle;
    message = '';
    existingUser = null;
    onChanged();
  }

  void onEmailChanged(String value) {
    _debounce?.cancel();
    final normalized = value.trim().toLowerCase();

    if (normalized.isEmpty) {
      status = EmailCadastroStatus.idle;
      message = '';
      existingUser = null;
      onChanged();
      return;
    }

    if (!_emailPattern.hasMatch(normalized)) {
      status = EmailCadastroStatus.idle;
      message = '';
      existingUser = null;
      onChanged();
      return;
    }

    status = EmailCadastroStatus.checking;
    message = 'Verificando e-mail...';
    existingUser = null;
    onChanged();

    _debounce = Timer(const Duration(milliseconds: 600), () {
      _checkEmail(normalized);
    });
  }

  Future<void> _checkEmail(String email) async {
    try {
      final resp = await VerificarEmailUsuarioCall.call(
        token: FFAppState().UserToken,
        email: email,
      );

      if (!resp.succeeded || resp.jsonBody is! Map) {
        status = EmailCadastroStatus.error;
        message = resp.bodyText.isNotEmpty
            ? resp.bodyText
            : 'Não foi possível verificar o e-mail.';
        existingUser = null;
        onChanged();
        return;
      }

      final body = resp.jsonBody as Map;
      final st = body['status']?.toString() ?? '';
      message = body['message']?.toString() ?? '';

      switch (st) {
        case 'available':
          status = EmailCadastroStatus.available;
          existingUser = null;
          break;
        case 'link_available':
          status = EmailCadastroStatus.linkAvailable;
          final u = body['user'];
          existingUser = u is Map ? Map<String, dynamic>.from(u) : null;
          break;
        case 'already_linked':
          status = EmailCadastroStatus.alreadyLinked;
          final u = body['user'];
          existingUser = u is Map ? Map<String, dynamic>.from(u) : null;
          break;
        default:
          status = EmailCadastroStatus.error;
          message =
              message.isNotEmpty ? message : 'Resposta inválida do servidor.';
      }
      onChanged();
    } catch (_) {
      status = EmailCadastroStatus.error;
      message = 'Erro de conexão ao verificar o e-mail.';
      existingUser = null;
      onChanged();
    }
  }

  String _existingDisplayName() {
    if (existingUser == null) return '';
    final nome = existingUser!['nome']?.toString().trim() ?? '';
    final sob = existingUser!['sobrenome']?.toString().trim() ?? '';
    final full = [nome, sob].where((s) => s.isNotEmpty).join(' ');
    return full.isNotEmpty ? full : (existingUser!['email']?.toString() ?? '');
  }

  Widget buildEmailSection(BuildContext context, {VoidCallback? onOpenLink}) {
    final theme = FlutterFlowTheme.of(context);

    Widget? suffix;
    if (status == EmailCadastroStatus.checking) {
      suffix = const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (status == EmailCadastroStatus.available) {
      suffix = Icon(Icons.check_circle_rounded, color: theme.success, size: 22);
    }

    return RdoSectionCard(
      title: 'E-mail',
      icon: Icons.email_outlined,
      subtitle: 'Verifique se o usuário já existe no sistema',
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            style: rdoFormFieldTextStyle(context),
            decoration: rdoFormFieldDecoration(
              context,
              label: 'E-mail *',
              hint: 'exemplo@email.com',
              suffixIcon: suffix,
            ),
            onChanged: onEmailChanged,
          ),
          if (status == EmailCadastroStatus.available) ...[
            const SizedBox(height: 12),
            _statusBanner(
              context,
              icon: Icons.check_circle_outline,
              color: theme.success,
              text:
                  'E-mail disponível. Preencha os dados abaixo para criar o usuário.',
            ),
          ],
          if (status == EmailCadastroStatus.linkAvailable &&
              existingUser != null) ...[
            const SizedBox(height: 12),
            _linkAvailableCard(context, onOpenLink),
          ],
          if (status == EmailCadastroStatus.alreadyLinked) ...[
            const SizedBox(height: 12),
            _statusBanner(
              context,
              icon: Icons.error_outline,
              color: theme.error,
              text: message.isNotEmpty
                  ? message
                  : 'Este e-mail já está vinculado à sua empresa.',
            ),
          ],
          if (status == EmailCadastroStatus.error) ...[
            const SizedBox(height: 12),
            _statusBanner(
              context,
              icon: Icons.warning_amber_rounded,
              color: theme.error,
              text: message,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBanner(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: theme.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkAvailableCard(BuildContext context, VoidCallback? onOpenLink) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.person_search, color: theme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Conta existente',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _existingDisplayName(),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onOpenLink,
            icon: const Icon(Icons.link, size: 18),
            label: Text(
              'Configurar vínculo',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
