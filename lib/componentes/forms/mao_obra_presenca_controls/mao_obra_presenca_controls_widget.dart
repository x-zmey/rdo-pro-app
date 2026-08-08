import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/forms/mao_obra_compact_dropdown.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';

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

/// Como o controle de presença se apresenta.
enum MaoObraPresencaModo {
  /// Par de ícones Presente / Ausente, para o cabeçalho da linha.
  acoes,

  /// Seletor do motivo da ausência, exibido só quando o status é `ausente`.
  motivo,
}

/// Presença do trabalhador no RDO: ícones de Presente / Ausente e o motivo.
/// Persiste em [relatorio_mao_obra_presenca] via [SQLiteManager.updateMaoObraRelatorio].
class MaoObraPresencaControlsWidget extends StatefulWidget {
  const MaoObraPresencaControlsWidget({
    super.key,
    required this.uuid,
    required this.statusPresenca,
    required this.motivoAusencia,
    required this.onSaved,
    this.modo = MaoObraPresencaModo.acoes,
  });

  final String uuid;
  final String statusPresenca;
  final String? motivoAusencia;
  final VoidCallback onSaved;
  final MaoObraPresencaModo modo;

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

  Widget _botaoPresenca({
    required IconData icone,
    required String tooltip,
    required bool ativo,
    required Color cor,
    required VoidCallback onPressed,
  }) {
    final theme = FlutterFlowTheme.of(context);

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: ativo ? cor.withValues(alpha: 0.14) : Colors.transparent,
        foregroundColor:
            ativo ? cor : theme.secondaryText.withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icone, size: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPresente = widget.statusPresenca == 'presente';
    final isAusente = widget.statusPresenca == 'ausente';
    final theme = FlutterFlowTheme.of(context);

    if (widget.modo == MaoObraPresencaModo.acoes) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _botaoPresenca(
            icone: isPresente
                ? Icons.check_circle_rounded
                : Icons.check_circle_outline_rounded,
            tooltip: 'Marcar presente',
            ativo: isPresente,
            cor: theme.success,
            onPressed: () async => _onPresente(),
          ),
          _botaoPresenca(
            icone: isAusente
                ? Icons.cancel_rounded
                : Icons.cancel_outlined,
            tooltip: 'Marcar ausente',
            ativo: isAusente,
            cor: theme.error,
            onPressed: () async => _onAusente(),
          ),
        ],
      );
    }

    if (!isAusente) {
      return const SizedBox.shrink();
    }

    return buildMaoObraCompactMotivoDropdown(
      context: context,
      label: 'Motivo da ausência',
      hint: 'Selecione o motivo da ausência',
      icone: Icons.event_busy_rounded,
      items: _itemsParaDropdown(),
      value: _valorDropdownValido(),
      onChanged: (v) {
        setState(() => _motivoSelecionado = v);
        _debounceMotivo();
      },
    );
  }
}
