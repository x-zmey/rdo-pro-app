import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cadastrar_mao_obra_obra/cadastrar_mao_obra_obra_dialog.dart';
import '/componentes/relatorios/includes/botao_cadastro_obra_atalho/botao_cadastro_obra_atalho_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'add_mao_obra_vinculada_model.dart';
export 'add_mao_obra_vinculada_model.dart';

/// Normaliza hora vinda do relatório (p.ex. 8:00) para o formato HH:mm usado na UI.
String _hhmmFromRelatorioField(String? raw, String fallback) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return fallback;
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(t);
  if (m == null) return fallback;
  final h = (int.tryParse(m.group(1)!) ?? 0).clamp(0, 23);
  return '${h.toString().padLeft(2, '0')}:${m.group(2)}';
}

/// Rótulo no select: descrição (orçamento) + cargo/função em [obra_itens], quando houver.
String _labelMaoObraDropdown(CarregaItensObraRow e) {
  final d = e.descricao.trim();
  final c = (e.cargoFuncao ?? '').trim();
  if (d.isEmpty && c.isEmpty) return 'sem descrição';
  if (c.isEmpty) return d;
  if (d.isEmpty) return c;
  return '$d — $c';
}

/// Preferência aos horários já digitados na tela do relatório; senão aos do SQLite.
String _preferHorarioLinhaRelatorio({
  required String? digitadoNaTela,
  required String? valorDoBanco,
  required String fallback,
}) {
  final u = (digitadoNaTela ?? '').trim();
  if (u.isNotEmpty) {
    return _hhmmFromRelatorioField(u, fallback);
  }
  return _hhmmFromRelatorioField(valorDoBanco, fallback);
}

/// crie para mim um componente que tem um select que vai ter nomes de mao de
/// obras podendo selecionar todas e após seleção aparece abaixo em cards
/// todos selecionados com cada um com opção de marcar se está presente ou
/// ausente, caso marque ausente abre um campo perguntando o motivo da
/// ausencia, e tbm para cada selecionado ter 4 campos de horas, sendo
/// entrada, inicio intervalo, fim intervalo e saida e depois de tudo botão de
/// salvar ou cancelarlembrando que no select que vai ter a mao de obra para
/// selecionar quero que apareça o nome da mão de obra e função que ele exerce
class AddMaoObraVinculadaWidget extends StatefulWidget {
  const AddMaoObraVinculadaWidget({
    super.key,
    required this.obraUuid,
    required this.relatorioUuid,
    /// Horários atualmente na tela do relatório (devem prevalecer sobre o SQLite
    /// até o usuário salvar o relatório).
    this.relatorioEntradaManha,
    this.relatorioInicioIntervalo,
    this.relatorioFimIntervalo,
    this.relatorioSaidaTarde,
  });

  final String? obraUuid;
  final String? relatorioUuid;
  final String? relatorioEntradaManha;
  final String? relatorioInicioIntervalo;
  final String? relatorioFimIntervalo;
  final String? relatorioSaidaTarde;

  @override
  State<AddMaoObraVinculadaWidget> createState() =>
      _AddMaoObraVinculadaWidgetState();
}

class _AddMaoObraVinculadaWidgetState extends State<AddMaoObraVinculadaWidget> {
  late AddMaoObraVinculadaModel _model;
  late Future<List<CarregaItensObraRow>> _itensObraFuture;
  int _itensObraReloadToken = 0;

  Future<List<CarregaItensObraRow>> _loadItensObra() async {
    final obraUuid = (widget.obraUuid ?? '').trim();
    if (obraUuid.isEmpty) {
      return <CarregaItensObraRow>[];
    }
    // Tela da obra usa a API; o dropdown lia só SQLite (podia estar desatualizado
    // por watermark do sync). Com internet, espelha a mesma fonte antes de listar.
    try {
      await actions.refreshObraItensPorTipo(
        obraUuid: obraUuid,
        tipo: 'mao_obra',
      );
    } catch (_) {}
    return SQLiteManager.instance.carregaItensObra(
      tipo: 'mao_obra',
      obraUuid: obraUuid,
      obraId: 0,
    );
  }

  void _reloadItensObra() {
    setState(() {
      _itensObraReloadToken++;
      _itensObraFuture = _loadItensObra();
    });
  }

  Future<void> _abrirCadastroMaoObraNaObra() async {
    final novoUuid = await showCadastrarMaoObraObraDialog(
      context: context,
      obraUuid: widget.obraUuid!,
    );
    if (!mounted || novoUuid == null || novoUuid.trim().isEmpty) return;

    _reloadItensObra();
    final selecionados = List<String>.from(_model.dropDownValue ?? const []);
    if (!selecionados.contains(novoUuid)) {
      selecionados.add(novoUuid);
    }
    safeSetState(() {
      _model.dropDownValue = selecionados;
      _model.funcionariosSelected = selecionados;
      _model.dropDownValueController =
          FormFieldController<List<String>?>(selecionados);
    });

    final inseriu = await _inserirMaoObraNoRelatorio(
      novoUuid,
      mostrarFeedback: true,
    );
    if (!mounted) return;
    if (inseriu) {
      FFAppState().update(() {});
      Navigator.pop(context);
    }
  }

  Future<bool> _inserirMaoObraNoRelatorio(
    String obraItemUuid, {
    bool mostrarFeedback = true,
  }) async {
    if (obraItemUuid.trim().isEmpty) return false;
    _model.relatorioResult = await SQLiteManager.instance.relatorioDetalhes(
      uuid: widget.relatorioUuid!,
      userUuid: FFAppState().creatorUuid,
      accountOwnerUuid: FFAppState().creatorUuid,
    );
    _model.uuidResult = await actions.generateUuid();
    final relDet = _model.relatorioResult?.firstOrNull;
    if (relDet?.dataExecutado == null) return false;

    final horaEntrada = _preferHorarioLinhaRelatorio(
      digitadoNaTela: widget.relatorioEntradaManha,
      valorDoBanco: relDet?.entradaManha,
      fallback: '08:00',
    );
    final intervaloInicio = _preferHorarioLinhaRelatorio(
      digitadoNaTela: widget.relatorioInicioIntervalo,
      valorDoBanco: relDet?.inicioIntervalo,
      fallback: '11:00',
    );
    final intervaloFim = _preferHorarioLinhaRelatorio(
      digitadoNaTela: widget.relatorioFimIntervalo,
      valorDoBanco: relDet?.fimIntervalo,
      fallback: '13:00',
    );
    final horaSaida = _preferHorarioLinhaRelatorio(
      digitadoNaTela: widget.relatorioSaidaTarde,
      valorDoBanco: relDet?.saidaTarde,
      fallback: '17:00',
    );

    await SQLiteManager.instance.setMaoObraRelatorio(
      relatorioId: 0,
      companyId: FFAppState().creatorId,
      obraItemId: 0,
      dataReferencia: relDet!.dataExecutado!,
      statusPresenca: 'presente',
      horaEntrada: horaEntrada,
      horaSaida: horaSaida,
      intervaloInicio: intervaloInicio,
      intervaloFim: intervaloFim,
      horasTrabalhadas: '8',
      createdBy: FFAppState().creatorUuid,
      createdAt: valueOrDefault<String>(
        dateTimeFormat('d/M/y', getCurrentTimestamp),
        '13/1/2026',
      ),
      relatorioUuid: widget.relatorioUuid,
      uuid: _model.uuidResult!,
      companyUuid: FFAppState().creatorUuid,
      obraItemUuid: obraItemUuid,
    );

    if (!mounted) return false;
    if (mostrarFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mão de obra incluída no relatório!',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          duration: const Duration(milliseconds: 4000),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
    }
    return true;
  }

  Future<int> _inserirVariasMaosObra(Iterable<String> obraItemUuids) async {
    final candidatos = obraItemUuids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '0')
        .toSet()
        .toList();
    var count = 0;
    for (final uuid in candidatos) {
      final ok = await _inserirMaoObraNoRelatorio(
        uuid,
        mostrarFeedback: false,
      );
      if (ok) count++;
    }
    return count;
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddMaoObraVinculadaModel());
    _itensObraFuture = _loadItensObra();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            boxShadow: [
              BoxShadow(
                blurRadius: 4.0,
                color: Color(0x33000000),
                offset: Offset(
                  0.0,
                  2.0,
                ),
                spreadRadius: 0.0,
              )
            ],
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
                      child: Text(
                        'Seleção de Mão de Obra',
                        style:
                            FlutterFlowTheme.of(context).titleMedium.override(
                                  font: GoogleFonts.interTight(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                                  fontSize: 18.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                      ),
                    ),
                    FutureBuilder<List<CarregaItensObraRow>>(
                      key: ValueKey('mao_obra_itens_$_itensObraReloadToken'),
                      future: _itensObraFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Erro ao carregar itens da obra: ${snapshot.error}',
                              style: TextStyle(
                                color: FlutterFlowTheme.of(context).error,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return Center(
                            child: LinearProgressIndicator(
                              color: FlutterFlowTheme.of(context).primary,
                            ),
                          );
                        }
                        final dropDownCarregaItensObraRowList = snapshot.data!;

                        return FlutterFlowDropDown<String>(
                          multiSelectController:
                              _model.dropDownValueController ??=
                                  FormFieldController<List<String>?>(
                            _model.dropDownValue ??= <String>[],
                          ),
                          options: List<String>.from(
                              dropDownCarregaItensObraRowList
                                  .map((e) => e.uuid)
                                  .toList()),
                          optionLabels: dropDownCarregaItensObraRowList
                              .map(_labelMaoObraDropdown)
                              .toList(),
                          onMultiSelectChanged: (vals) {
                            final lista = (vals ?? [])
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty && e != '0')
                                .toList();
                            safeSetState(() {
                              _model.dropDownValue = lista;
                              _model.funcionariosSelected = lista;
                            });
                          },
                          width: double.infinity,
                          height: 56.0,
                          textStyle:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                          hintText: 'Selecione um ou mais trabalhadores',
                          fillColor:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          elevation: 0.0,
                          borderColor: FlutterFlowTheme.of(context).alternate,
                          borderWidth: 1.0,
                          borderRadius: 8.0,
                          margin: EdgeInsetsDirectional.fromSTEB(
                              12.0, 0.0, 12.0, 0.0),
                          isSearchable: true,
                          searchHintText: 'Buscar mão de obra...',
                          isMultiSelect: true,
                        );
                      },
                    ),
                    BotaoCadastroObraAtalhoWidget(
                      titulo: 'Nova mão de obra',
                      subtitulo:
                          'Cadastra na obra e inclui no relatório como presente',
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: _abrirCadastroMaoObraNaObra,
                      margin: const EdgeInsets.only(top: 8),
                    ),
                  ].divide(SizedBox(height: 8.0)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          Navigator.pop(context);
                        },
                        text: 'Cancelar',
                        options: FFButtonOptions(
                          height: 48.0,
                          padding: EdgeInsets.all(8.0),
                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          textStyle: FlutterFlowTheme.of(context)
                              .titleSmall
                              .override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .fontStyle,
                              ),
                          elevation: 0.0,
                          borderSide: BorderSide(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          final selecionados = (_model.funcionariosSelected ??
                                  _model.dropDownValue ??
                                  const <String>[])
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty && e != '0')
                              .toSet()
                              .toList();
                          if (selecionados.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selecione uma ou mais mãos de obra ou cadastre uma nova.',
                                ),
                              ),
                            );
                            return;
                          }
                          final count =
                              await _inserirVariasMaosObra(selecionados);
                          if (!mounted || count == 0) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                count == 1
                                    ? '1 mão de obra incluída no relatório!'
                                    : '$count mãos de obra incluídas no relatório!',
                                style: TextStyle(
                                  color: FlutterFlowTheme.of(context)
                                      .primaryText,
                                ),
                              ),
                              duration: const Duration(milliseconds: 4000),
                              backgroundColor:
                                  FlutterFlowTheme.of(context).secondary,
                            ),
                          );
                          FFAppState().update(() {});
                          Navigator.pop(context);
                          safeSetState(() {});
                        },
                        text: 'Salvar',
                        options: FFButtonOptions(
                          height: 48.0,
                          padding: EdgeInsets.all(8.0),
                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          color: FlutterFlowTheme.of(context).primary,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context).info,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                          elevation: 0.0,
                          borderSide: BorderSide(
                            color: Colors.transparent,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ].divide(SizedBox(width: 12.0)),
                ),
              ].divide(SizedBox(height: 16.0)),
            ),
          ),
        ),
      ),
    );
  }
}
