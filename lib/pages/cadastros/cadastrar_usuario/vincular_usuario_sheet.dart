import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';

/// Bottom sheet: perfil e obra travada para vincular usuário existente.
/// Retorna `{ user_id, type, obra_travada }` ou `null` se cancelado.
Future<Map<String, dynamic>?> showVincularUsuarioSheet(
  BuildContext context, {
  required Map<String, dynamic> user,
}) async {
  String type = 'operador';
  bool obraTravada = false;
  final typeController = FormFieldController<String>('Operador');

  String typeApi(String ui) {
    switch (ui) {
      case 'Cliente':
        return 'cliente';
      case 'Supervisor':
        return 'supervisor';
      case 'Administrador':
        return 'administrador';
      default:
        return 'operador';
    }
  }

  final nome = user['nome']?.toString().trim() ?? '';
  final sob = user['sobrenome']?.toString().trim() ?? '';
  final displayName = [nome, sob].where((s) => s.isNotEmpty).join(' ');
  final email = user['email']?.toString() ?? '';
  final cargo = user['cargo']?.toString();
  final initials = () {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }();

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final theme = FlutterFlowTheme.of(context);
          final bottom = MediaQuery.paddingOf(context).bottom;

          return Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: Container(
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.alternate,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: theme.primary.withValues(alpha: 0.12),
                            child: Text(
                              initials,
                              style: theme.titleMedium.override(
                                font: GoogleFonts.interTight(fontWeight: FontWeight.w700),
                                color: theme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vincular à empresa',
                                  style: theme.titleLarge.override(
                                    font: GoogleFonts.interTight(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Text(
                                  'Perfil de acesso nesta empresa',
                                  style: theme.bodySmall.override(
                                    font: GoogleFonts.inter(),
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            icon: Icon(Icons.close, color: theme.secondaryText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _userInfoCard(context, displayName, email, cargo),
                      const SizedBox(height: 12),
                      _infoBanner(context),
                      const SizedBox(height: 16),
                      FlutterFlowDropDown<String>(
                        controller: typeController,
                        options: const [
                          'Operador',
                          'Supervisor',
                          'Administrador',
                          'Cliente',
                        ],
                        onChanged: (val) {
                          setSheetState(() {
                            type = typeApi(val ?? 'Operador');
                            if (type == 'cliente') {
                              obraTravada = true;
                            }
                          });
                        },
                        width: double.infinity,
                        height: 52,
                        textStyle: theme.bodyMedium,
                        hintText: 'Perfil nesta empresa',
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: theme.secondaryText,
                        ),
                        fillColor: theme.primaryBackground,
                        elevation: 0,
                        borderColor: theme.alternate,
                        borderWidth: 1,
                        borderRadius: 8,
                        margin: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: obraTravada,
                        onChanged: type == 'cliente'
                            ? null
                            : (v) => setSheetState(() => obraTravada = v),
                        title: Text(
                          type == 'cliente'
                              ? 'Obra travada (obrigatório para cliente)'
                              : 'Restringir às obras designadas',
                          style: theme.bodyMedium,
                        ),
                        subtitle: Text(
                          'Só acessa obras vinculadas nesta empresa.',
                          style: theme.bodySmall.override(color: theme.secondaryText),
                        ),
                        activeThumbColor: theme.primary,
                      ),
                      const SizedBox(height: 16),
                      FFButtonWidget(
                        onPressed: () => Navigator.pop(ctx, true),
                        text: 'Vincular à empresa',
                        icon: const Icon(Icons.link, size: 20),
                        options: FFButtonOptions(
                          width: double.infinity,
                          height: 48,
                          color: theme.primary,
                          textStyle: theme.titleSmall.override(
                            font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
                            color: Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  typeController.dispose();

  if (confirmed != true) {
    return null;
  }

  final userId = user['id'];
  final parsedId = userId is int ? userId : int.tryParse(userId?.toString() ?? '');
  if (parsedId == null) {
    return null;
  }

  return {
    'user_id': parsedId,
    'type': type,
    'obra_travada': type == 'cliente' ? true : obraTravada,
  };
}

Widget _userInfoCard(
  BuildContext context,
  String name,
  String email,
  String? cargo,
) {
  final theme = FlutterFlowTheme.of(context);
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: theme.primaryBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.alternate),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'USUÁRIO ENCONTRADO',
          style: theme.labelSmall.override(
            font: GoogleFonts.inter(fontWeight: FontWeight.w700),
            color: theme.primary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: theme.titleMedium.override(
            font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          email,
          style: theme.bodyMedium.override(
            font: GoogleFonts.inter(),
            color: theme.secondaryText,
          ),
        ),
        if (cargo != null && cargo.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(cargo, style: theme.labelMedium),
          ),
        ],
      ],
    ),
  );
}

Widget _infoBanner(BuildContext context) {
  final theme = FlutterFlowTheme.of(context);
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.accent1.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 20, color: theme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'A senha da conta não será alterada. O usuário continua entrando com o e-mail e senha atuais.',
            style: theme.bodySmall.override(
              font: GoogleFonts.inter(),
              color: theme.primaryText,
            ),
          ),
        ),
      ],
    ),
  );
}
