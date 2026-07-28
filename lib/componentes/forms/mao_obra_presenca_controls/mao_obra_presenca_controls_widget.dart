import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/forms/mao_obra_compact_dropdown.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Alinhado ao frontend Vue (`motivosAusencia` em `relatorios/edit/[token].vue`).
const List<String> kMotivosAusencia = [
  'Acidente',
  'Não justificado',
  'Problemas de Saúde',
  'Emergência Familiar',
  'Folga',
  'Questões Pessoais',
  'Conflitos Internos',
  'Férias',
  'Outro',
];

/// Botões Presente / Ausente e dropdown de motivo quando ausente.
/// Persiste em [relatorio_mao_obra_presenca] via [SQLiteManager.updateMaoObraRelatorio].
class MaoObraPresencaControlsWidget extends StatefulWidget {
  const MaoObraPresencaControlsWidget({
    super.key,
    required this.uuid,
    required this.statusPresenca,
    required this.motivoAusencia,
    required this.onSaved,
  });

  final String uuid;
  final String statusPresenca;
  final String? motivoAusencia;
  final VoidCallback onSaved;

  @override
  State<MaoObraPresencaControlsWidget> createState() =>
      _MaoObraPresencaControlsWidgetState();
}

class _MaoObraPresencaControlsWidgetState
    extends State<MaoObraPresencaControlsWidget> {
  /// Motivo escolhido no dropdown (null = nenhum / hint).
  String? _motivoSelecionado;

  static String _escapeSql(String? s) => (s ?? '').replaceAll("'", "''");

  void _syncMotivoFromWidget() {
    final m = widget.motivoAusencia?.trim();
    if (m == null || m.isEmpty) {
      _motivoSelecionado = null;
    } else {
      _motivoSelecionado = m;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncMotivoFromWidget();
  }

  @override
  void didUpdateWidget(covariant MaoObraPresencaControlsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uuid != oldWidget.uuid) {
      _syncMotivoFromWidget();
      return;
    }
    if (widget.motivoAusencia != oldWidget.motivoAusencia) {
      _syncMotivoFromWidget();
    }
  }

  List<String> _itemsParaDropdown() {
    final base = List<String>.from(kMotivosAusencia);
    final m = _motivoSelecionado?.trim();
    if (m != null && m.isNotEmpty && !base.contains(m)) {
      base.insert(0, m);
    }
    return base;
  }

  String? _valorDropdownValido() {
    final items = _itemsParaDropdown();
    final m = _motivoSelecionado?.trim();
    if (m == null || m.isEmpty) return null;
    return items.contains(m) ? m : null;
  }

  Future<void> _persist({
    required String status,
    required String motivo,
  }) async {
    final det =
        await SQLiteManager.instance.getMaoObraRelatorioDetalhes(uuid: widget.uuid);
    final d = det.firstOrNull;
    if (d == null) return;

    await SQLiteManager.instance.updateMaoObraRelatorio(
      status: status,
      horaEntrada: _escapeSql(d.horaEntrada),
      horaSaida: _escapeSql(d.horaSaida),
      intervaloInicio: _escapeSql(d.intervaloInicio),
      intervaloFim: _escapeSql(d.intervaloFim),
      horasTrabalhadas: _escapeSql(d.horasTrabalhadas),
      motivoAusencia: status == 'presente' ? '' : _escapeSql(motivo),
      motivoSaidaCedo: _escapeSql(d.motivoSaidaCedo),
      motivoAtraso: _escapeSql(d.motivoAtraso),
      uuid: widget.uuid,
    );
    if (mounted) {
      widget.onSaved();
    }
  }

  Future<void> _onPresente() async {
    setState(() => _motivoSelecionado = null);
    await _persist(status: 'presente', motivo: '');
  }

  Future<void> _onAusente() async {
    await _persist(
      status: 'ausente',
      motivo: _motivoSelecionado?.trim() ?? '',
    );
  }

  void _debounceMotivo() {
    if (widget.statusPresenca != 'ausente') return;
    EasyDebounce.debounce(
      'mao_obra_motivo_${widget.uuid}',
      const Duration(milliseconds: 900),
      () async {
        await _persist(
          status: 'ausente',
          motivo: _motivoSelecionado?.trim() ?? '',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPresente = widget.statusPresenca == 'presente';
    final isAusente = widget.statusPresenca == 'ausente';
    final theme = FlutterFlowTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FFButtonWidget(
              onPressed: () async {
                await _onPresente();
              },
              text: 'Presente',
              options: FFButtonOptions(
                width: 70.0,
                height: 28.0,
                padding: const EdgeInsets.all(8.0),
                iconPadding: EdgeInsetsDirectional.zero,
                color: isPresente
                    ? theme.success
                    : theme.secondaryBackground,
                textStyle: theme.labelSmall.override(
                      font: GoogleFonts.inter(
                        fontWeight: theme.labelSmall.fontWeight,
                        fontStyle: theme.labelSmall.fontStyle,
                      ),
                      color: isPresente ? theme.info : theme.secondaryText,
                      letterSpacing: 0.0,
                      fontWeight: theme.labelSmall.fontWeight,
                      fontStyle: theme.labelSmall.fontStyle,
                    ),
                elevation: 0.0,
                borderSide: BorderSide(
                  color: isPresente ? Colors.transparent : theme.alternate,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
            const SizedBox(width: 8),
            FFButtonWidget(
              onPressed: () async {
                await _onAusente();
              },
              text: 'Ausente',
              options: FFButtonOptions(
                width: 70.0,
                height: 28.0,
                padding: const EdgeInsets.all(8.0),
                iconPadding: EdgeInsetsDirectional.zero,
                color: isAusente ? theme.error : theme.secondaryBackground,
                textStyle: theme.labelSmall.override(
                      font: GoogleFonts.inter(
                        fontWeight: theme.labelSmall.fontWeight,
                        fontStyle: theme.labelSmall.fontStyle,
                      ),
                      color: isAusente ? theme.info : theme.secondaryText,
                      letterSpacing: 0.0,
                      fontWeight: theme.labelSmall.fontWeight,
                      fontStyle: theme.labelSmall.fontStyle,
                    ),
                elevation: 0.0,
                borderSide: BorderSide(
                  color: isAusente ? Colors.transparent : theme.alternate,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
          ],
        ),
        if (isAusente) ...[
          const SizedBox(height: 6.0),
          buildMaoObraCompactMotivoDropdown(
            context: context,
            label: 'Motivo da ausência',
            hint: 'Selecione o motivo',
            items: _itemsParaDropdown(),
            value: _valorDropdownValido(),
            onChanged: (v) {
              setState(() => _motivoSelecionado = v);
              _debounceMotivo();
            },
          ),
        ],
      ],
    );
  }
}
