import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/forms/mao_obra_compact_dropdown.dart';
import '/componentes/forms/mao_obra_motivo_atraso_storage.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/hh_mm_24h_input_formatter.dart';
import '/flutter_flow/relatorio_horarios_validation.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Quatro campos de horário (entrada, início/fim intervalo, saída) com a mesma
/// máscara HH:mm (00:00–23:59) e validação em cadeia do relatório.
///
/// Quando a entrada do funcionário é depois da entrada do relatório ou a saída
/// é antes da saída do relatório, exibe dropdown(s): motivo de atraso na entrada
/// continua em JSON em [motivo_atraso]; motivo da saída antecipada em [motivoSaidaCedo]
/// (coluna SQLite / API `motivo_saida_cedo`), com fallback legado no JSON `s`.
class MaoObraHorariosFormWidget extends StatefulWidget {
  const MaoObraHorariosFormWidget({
    super.key,
    required this.uuid,
    required this.horaEntrada,
    required this.intervaloInicio,
    required this.intervaloFim,
    required this.horaSaida,
    required this.relatorioEntradaManha,
    required this.relatorioSaidaTarde,
    required this.motivoAtrasoColumn,
    this.motivoSaidaCedo,
  });

  final String uuid;
  final String? horaEntrada;
  final String? intervaloInicio;
  final String? intervaloFim;
  final String? horaSaida;

  /// Horários de referência do relatório (mesmo conceito do Vue / `RelatorioDetalhes`).
  final String relatorioEntradaManha;
  final String relatorioSaidaTarde;

  /// Valor bruto da coluna `motivo_atraso` no vínculo (JSON com chave `e` para atraso entrada).
  final String? motivoAtrasoColumn;

  /// Motivo da saída antes do horário do relatório (coluna dedicada; sync com servidor).
  final String? motivoSaidaCedo;

  @override
  State<MaoObraHorariosFormWidget> createState() =>
      _MaoObraHorariosFormWidgetState();
}

class _MaoObraHorariosFormWidgetState extends State<MaoObraHorariosFormWidget> {
  late TextEditingController _entrada;
  late TextEditingController _inicio;
  late TextEditingController _fim;
  late TextEditingController _saida;

  late FocusNode _fnEntrada;
  late FocusNode _fnInicio;
  late FocusNode _fnFim;
  late FocusNode _fnSaida;

  late HhMm24hInputFormatter _maskEntrada;
  late HhMm24hInputFormatter _maskInicio;
  late HhMm24hInputFormatter _maskFim;
  late HhMm24hInputFormatter _maskSaida;

  String? _motivoEntrada;
  String? _motivoSaida;

  static String _escapeSql(String? s) => (s ?? '').replaceAll("'", "''");

  void _syncMotivosDaColuna() {
    final p = MaoObraMotivoAtrasoStorage.decode(widget.motivoAtrasoColumn);
    _motivoEntrada = p.entrada;
    final ms = widget.motivoSaidaCedo?.trim();
    if (ms != null && ms.isNotEmpty) {
      _motivoSaida = ms;
    } else {
      _motivoSaida = p.saida;
    }
  }

  @override
  void initState() {
    super.initState();
    _entrada = TextEditingController(
      text: valueOrDefault<String>(widget.horaEntrada, '08:00'),
    );
    _inicio = TextEditingController(
      text: valueOrDefault<String>(widget.intervaloInicio, '11:00'),
    );
    _fim = TextEditingController(
      text: valueOrDefault<String>(widget.intervaloFim, '13:00'),
    );
    _saida = TextEditingController(
      text: valueOrDefault<String>(widget.horaSaida, '17:00'),
    );
    _fnEntrada = FocusNode();
    _fnInicio = FocusNode();
    _fnFim = FocusNode();
    _fnSaida = FocusNode();
    _maskEntrada = HhMm24hInputFormatter();
    _maskInicio = HhMm24hInputFormatter();
    _maskFim = HhMm24hInputFormatter();
    _maskSaida = HhMm24hInputFormatter();
    _syncMotivosDaColuna();
  }

  @override
  void didUpdateWidget(covariant MaoObraHorariosFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uuid != widget.uuid) {
      _entrada.text = valueOrDefault<String>(widget.horaEntrada, '08:00');
      _inicio.text = valueOrDefault<String>(widget.intervaloInicio, '11:00');
      _fim.text = valueOrDefault<String>(widget.intervaloFim, '13:00');
      _saida.text = valueOrDefault<String>(widget.horaSaida, '17:00');
      _syncMotivosDaColuna();
      return;
    }
    if (widget.motivoAtrasoColumn != oldWidget.motivoAtrasoColumn ||
        widget.motivoSaidaCedo != oldWidget.motivoSaidaCedo) {
      _syncMotivosDaColuna();
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    _inicio.dispose();
    _fim.dispose();
    _saida.dispose();
    _fnEntrada.dispose();
    _fnInicio.dispose();
    _fnFim.dispose();
    _fnSaida.dispose();
    super.dispose();
  }

  bool _entradaAtrasadaVsRelatorio() {
    final me = parseMinutosDesdeMeiaNoite(_entrada.text);
    final mr = parseMinutosDesdeMeiaNoite(widget.relatorioEntradaManha);
    if (me == null || mr == null) return false;
    return me > mr;
  }

  bool _saidaAntecipadaVsRelatorio() {
    final ms = parseMinutosDesdeMeiaNoite(_saida.text);
    final mr = parseMinutosDesdeMeiaNoite(widget.relatorioSaidaTarde);
    if (ms == null || mr == null) return false;
    return ms < mr;
  }

  /// Só motivo de **atraso na entrada** (chave `e`); saída antecipada vai em [motivo_saida_cedo].
  String _motivoAtrasoParaPersistir() {
    final e = _entradaAtrasadaVsRelatorio() ? _motivoEntrada?.trim() : null;
    return MaoObraMotivoAtrasoStorage.encode(entrada: e, saida: null);
  }

  String _motivoSaidaCedoParaPersistir() {
    if (!_saidaAntecipadaVsRelatorio()) return '';
    return _motivoSaida?.trim() ?? '';
  }

  /// Mesmo visual de [_buildTimeField] em `obra_add_relatorio_widget.dart` (Horários de Trabalho).
  InputDecoration _decorationHorariosRelatorioGeral(
      BuildContext context, String label) {
    final theme = FlutterFlowTheme.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 11),
      filled: true,
      fillColor: theme.secondaryBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.alternate),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      counterText: '',
    );
  }

  TextStyle _textStyleHorariosRelatorioGeral() => GoogleFonts.inter(fontSize: 13);

  Future<void> _persistMotivoColumn(BuildContext context) async {
    final det = await SQLiteManager.instance.getMaoObraRelatorioDetalhes(
      uuid: widget.uuid,
    );
    final d = det.firstOrNull;
    if (d == null || !context.mounted) return;

    await SQLiteManager.instance.updateMaoObraRelatorio(
      horaEntrada: _entrada.text,
      horaSaida: _saida.text,
      intervaloInicio: _inicio.text,
      intervaloFim: _fim.text,
      uuid: widget.uuid,
      status: d.statusPresenca,
      horasTrabalhadas: '',
      motivoAusencia: d.motivoAusencia,
      motivoSaidaCedo: _escapeSql(_motivoSaidaCedoParaPersistir()),
      motivoAtraso: _escapeSql(_motivoAtrasoParaPersistir()),
    );
  }

  Future<void> _persist(BuildContext context) async {
    final err = validateHorariosSequenceFromStrings(
      entrada: _entrada.text,
      inicio: _inicio.text,
      fim: _fim.text,
      saida: _saida.text,
    );
    if (err != null) {
      if (context.mounted) {
        showHorarioErroSnackBar(context, err);
      }
      return;
    }

    final det = await SQLiteManager.instance.getMaoObraRelatorioDetalhes(
      uuid: widget.uuid,
    );
    if (!context.mounted) return;

    final d = det.firstOrNull;

    await SQLiteManager.instance.updateMaoObraRelatorio(
      horaEntrada: _entrada.text,
      horaSaida: _saida.text,
      intervaloInicio: _inicio.text,
      intervaloFim: _fim.text,
      uuid: widget.uuid,
      status: d?.statusPresenca,
      horasTrabalhadas: '',
      motivoAusencia: d?.motivoAusencia,
      motivoSaidaCedo: _escapeSql(_motivoSaidaCedoParaPersistir()),
      motivoAtraso: _escapeSql(_motivoAtrasoParaPersistir()),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Dados Salvos!',
          style: TextStyle(
            color: FlutterFlowTheme.of(context).alternate,
          ),
        ),
        duration: const Duration(milliseconds: 4000),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  }

  void _onAnyChanged(BuildContext context) {
    setState(() {});
    EasyDebounce.debounce(
      'mao_obra_horarios_${widget.uuid}',
      const Duration(milliseconds: 2000),
      () => _persist(context),
    );
  }

  void _debounceMotivoDropdown(BuildContext context) {
    EasyDebounce.debounce(
      'mao_obra_motivo_atraso_${widget.uuid}',
      const Duration(milliseconds: 900),
      () async {
        await _persistMotivoColumn(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showEntrada = _entradaAtrasadaVsRelatorio();
    final showSaida = _saidaAntecipadaVsRelatorio();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _entrada,
                focusNode: _fnEntrada,
                onChanged: (_) => _onAnyChanged(context),
                autofocus: false,
                obscureText: false,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration:
                    _decorationHorariosRelatorioGeral(context, 'Entrada'),
                style: _textStyleHorariosRelatorioGeral(),
                textAlign: TextAlign.center,
                maxLength: 5,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                keyboardType: TextInputType.number,
                validator: (v) => validateEntradaMaoObra(
                  v,
                  _inicio.text,
                  _fim.text,
                  _saida.text,
                ),
                inputFormatters: [_maskEntrada],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _inicio,
                focusNode: _fnInicio,
                onChanged: (_) => _onAnyChanged(context),
                autofocus: false,
                obscureText: false,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: _decorationHorariosRelatorioGeral(
                    context, 'Início int.'),
                style: _textStyleHorariosRelatorioGeral(),
                textAlign: TextAlign.center,
                maxLength: 5,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                keyboardType: TextInputType.number,
                validator: (v) => validateInicioMaoObra(
                  v,
                  _entrada.text,
                  _fim.text,
                  _saida.text,
                ),
                inputFormatters: [_maskInicio],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _fim,
                focusNode: _fnFim,
                onChanged: (_) => _onAnyChanged(context),
                autofocus: false,
                obscureText: false,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration:
                    _decorationHorariosRelatorioGeral(context, 'Fim int.'),
                style: _textStyleHorariosRelatorioGeral(),
                textAlign: TextAlign.center,
                maxLength: 5,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                keyboardType: TextInputType.number,
                validator: (v) => validateFimMaoObra(
                  v,
                  _entrada.text,
                  _inicio.text,
                  _saida.text,
                ),
                inputFormatters: [_maskFim],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _saida,
                focusNode: _fnSaida,
                onChanged: (_) => _onAnyChanged(context),
                autofocus: false,
                obscureText: false,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: _decorationHorariosRelatorioGeral(context, 'Saída'),
                style: _textStyleHorariosRelatorioGeral(),
                textAlign: TextAlign.center,
                maxLength: 5,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                keyboardType: TextInputType.number,
                validator: (v) => validateSaidaMaoObra(
                  v,
                  _entrada.text,
                  _inicio.text,
                  _fim.text,
                ),
                inputFormatters: [_maskSaida],
              ),
            ),
          ],
        ),
        if (showEntrada || showSaida) ...[
          const SizedBox(height: 8.0),
          if (showEntrada) ...[
            buildMaoObraCompactMotivoDropdown(
              context: context,
              label: 'Motivo do atraso',
              hint: 'Selecione o motivo',
              items: kMotivosAtrasoSaida,
              value: _motivoEntrada,
              onChanged: (v) {
                setState(() => _motivoEntrada = v);
                _debounceMotivoDropdown(context);
              },
            ),
          ],
          if (showEntrada && showSaida) const SizedBox(height: 8.0),
          if (showSaida)
            buildMaoObraCompactMotivoDropdown(
              context: context,
              label: 'Motivo da saída antecipada',
              hint: 'Selecione o motivo',
              items: kMotivosAtrasoSaida,
              value: _motivoSaida,
              onChanged: (v) {
                setState(() => _motivoSaida = v);
                _debounceMotivoDropdown(context);
              },
            ),
        ],
      ],
    );
  }
}
