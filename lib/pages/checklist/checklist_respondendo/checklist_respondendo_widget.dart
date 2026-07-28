import '/componentes/forms/avaliativo_emojis_checklist/avaliativo_emojis_checklist_widget.dart';
import '/componentes/forms/campo_cadastro_checklist/campo_cadastro_checklist_widget.dart';
import '/componentes/forms/campo_data_checklist/campo_data_checklist_widget.dart';
import '/componentes/forms/campo_numero_int_checklist/campo_numero_int_checklist_widget.dart';
import '/componentes/forms/campo_texto_checklist/campo_texto_checklist_widget.dart';
import '/componentes/forms/dropdown_opcoes_checklist/dropdown_opcoes_checklist_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'checklist_respondendo_model.dart';
export 'checklist_respondendo_model.dart';

/// agora crie uma pagina de respondendo um checklist nela vai ter areas do
/// checklist e dentro de cada area tem diversas perguntas em diversos
/// formatos cada pergunta pode permitir que insire um comentario alem da
/// resposta como também um anexo e plano de ação, tem pergunta que o formato
/// dela é de selecionar uma opção, tem outras que é para escrever uma
/// resposta e outras como selecionar um icone tipo se está feliz ou triste e
/// diversos formatos, quero que no topo va mostrando quando perguntas já
/// respondeu e quantas faltas como também andamento das respostas do
/// checklist e abaixo de tudo colocar o botão concluir que só permite
/// concluir depois de tudo respondido
class ChecklistRespondendoWidget extends StatefulWidget {
  const ChecklistRespondendoWidget({super.key});

  static String routeName = 'checklistRespondendo';
  static String routePath = '/checklistRespondendo';

  @override
  State<ChecklistRespondendoWidget> createState() =>
      _ChecklistRespondendoWidgetState();
}

class _ChecklistRespondendoWidgetState
    extends State<ChecklistRespondendoWidget> {
  late ChecklistRespondendoModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChecklistRespondendoModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(4.0, 20.0, 4.0, 4.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primary,
                    borderRadius: BorderRadius.circular(0.0),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              valueOrDefault<String>(
                                functions
                                    .getDadosFromChecklist('[\'nome\']')
                                    ?.toString(),
                                'Sem nome',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .headlineSmall
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .headlineSmall
                                          .fontStyle,
                                    ),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .headlineSmall
                                        .fontStyle,
                                  ),
                            ),
                            FlutterFlowIconButton(
                              borderRadius: 20.0,
                              buttonSize: 40.0,
                              fillColor: Color(0x33FFFFFF),
                              icon: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20.0,
                              ),
                              onPressed: () {
                                print('IconButton pressed ...');
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Progresso: 12/25 perguntas',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: Colors.white,
                                        fontSize: 14.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                Text(
                                  '48% concluído',
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontStyle,
                                        ),
                                        color: Color(0xCCFFFFFF),
                                        fontSize: 12.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                ),
                              ],
                            ),
                            Text(
                              'Área 2 de 5',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: Colors.white,
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ],
                        ),
                        Container(
                          width: double.infinity,
                          height: 8.0,
                          decoration: BoxDecoration(
                            color: Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Align(
                            alignment: AlignmentDirectional(-1.0, 0.0),
                            child: Container(
                              width: MediaQuery.sizeOf(context).width * 0.48,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).tertiary,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                            ),
                          ),
                        ),
                      ].divide(SizedBox(height: 12.0)),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 4.0, 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final areas = functions
                              .getAreasFromChecklist(
                                  FFAppState().checklistAtualJson)
                              .toList();

                          return ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            scrollDirection: Axis.vertical,
                            itemCount: areas.length,
                            itemBuilder: (context, areasIndex) {
                              final areasItem = areas[areasIndex];
                              return Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Icon(
                                              Icons.shield_outlined,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              size: 20.0,
                                            ),
                                            Expanded(
                                              child: Text(
                                                getJsonField(
                                                  areasItem,
                                                  r'''$['name']''',
                                                ).toString(),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .override(
                                                          font: GoogleFonts
                                                              .interTight(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontStyle,
                                                        ),
                                              ),
                                            ),
                                          ].divide(SizedBox(width: 8.0)),
                                        ),
                                        Builder(
                                          builder: (context) {
                                            final pergunta = getJsonField(
                                              areasItem,
                                              r'''$['items']''',
                                            ).toList();

                                            return ListView.builder(
                                              padding: EdgeInsets.zero,
                                              primary: false,
                                              shrinkWrap: true,
                                              scrollDirection: Axis.vertical,
                                              itemCount: pergunta.length,
                                              itemBuilder:
                                                  (context, perguntaIndex) {
                                                final perguntaItem =
                                                    pergunta[perguntaIndex];
                                                return Padding(
                                                  padding: EdgeInsets.all(4.0),
                                                  child: Container(
                                                    width: double.infinity,
                                                    decoration: BoxDecoration(
                                                      color: FlutterFlowTheme
                                                              .of(context)
                                                          .secondaryBackground,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsets.all(4.0),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            getJsonField(
                                                              perguntaItem,
                                                              r'''$['description']''',
                                                            ).toString(),
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                          if (perguntaItem[
                                                                  'type'] ==
                                                              "Texto")
                                                            CampoTextoChecklistWidget(
                                                              key: Key(
                                                                  'Key1bo_${perguntaIndex}_of_${pergunta.length}'),
                                                              index:
                                                                  getJsonField(
                                                                perguntaItem,
                                                                r'''$['id']''',
                                                              ),
                                                              areaId:
                                                                  getJsonField(
                                                                areasItem,
                                                                r'''$['id']''',
                                                              ),
                                                              perguntaId:
                                                                  getJsonField(
                                                                perguntaItem,
                                                                r'''$['id']''',
                                                              ),
                                                            ),
                                                          if (perguntaItem[
                                                                  'type'] ==
                                                              "Avaliativo Emojis")
                                                            AvaliativoEmojisChecklistWidget(
                                                              key: Key(
                                                                  'Keyrx3_${perguntaIndex}_of_${pergunta.length}'),
                                                              index:
                                                                  getJsonField(
                                                                perguntaItem,
                                                                r'''$['id']''',
                                                              ),
                                                              areaId:
                                                                  getJsonField(
                                                                areasItem,
                                                                r'''$['id']''',
                                                              ),
                                                              perguntaId:
                                                                  getJsonField(
                                                                perguntaItem,
                                                                r'''$['id']''',
                                                              ),
                                                            ),
                                                          if (perguntaItem[
                                                                  'type'] ==
                                                              "Opção")
                                                            DropdownOpcoesChecklistWidget(
                                                              key: Key(
                                                                  'Key8v1_${perguntaIndex}_of_${pergunta.length}'),
                                                              areaId:
                                                                  getJsonField(
                                                                areasItem,
                                                                r'''$['id']''',
                                                              ),
                                                              itemId:
                                                                  getJsonField(
                                                                perguntaItem,
                                                                r'''$['id']''',
                                                              ),
                                                              opcoes:
                                                                  perguntaItem[
                                                                      'options'],
                                                            ),
                                                          if (perguntaItem[
                                                                  'type'] ==
                                                              "Número")
                                                            CampoNumeroIntChecklistWidget(
                                                              key: Key(
                                                                  'Keyse2_${perguntaIndex}_of_${pergunta.length}'),
                                                              index:
                                                                  getJsonField(
                                                                perguntaItem,
                                                                r'''$['id']''',
                                                              ),
                                                              areaId:
                                                                  getJsonField(
                                                                areasItem,
                                                                r'''$['id']''',
                                                              ),
                                                              perguntaId:
                                                                  getJsonField(
                                                                perguntaItem,
                                                                r'''$['id']''',
                                                              ),
                                                            ),
                                                          if (perguntaItem[
                                                                  'type'] ==
                                                              "Data")
                                                            CampoDataChecklistWidget(
                                                              key: Key(
                                                                  'Keyaor_${perguntaIndex}_of_${pergunta.length}'),
                                                              index:
                                                                  getJsonField(
                                                                perguntaItem,
                                                                r'''$['id']''',
                                                              ),
                                                              areaId:
                                                                  getJsonField(
                                                                areasItem,
                                                                r'''$['id']''',
                                                              ),
                                                              perguntaId:
                                                                  getJsonField(
                                                                perguntaItem,
                                                                r'''$['id']''',
                                                              ),
                                                            ),
                                                          if (perguntaItem[
                                                                  'type'] ==
                                                              "Cadastro")
                                                            CampoCadastroChecklistWidget(
                                                              key: Key(
                                                                  'Key75c_${perguntaIndex}_of_${pergunta.length}'),
                                                              index:
                                                                  getJsonField(
                                                                perguntaItem,
                                                                r'''$['id']''',
                                                              ),
                                                              areaId:
                                                                  getJsonField(
                                                                areasItem,
                                                                r'''$['id']''',
                                                              ),
                                                              perguntaId:
                                                                  getJsonField(
                                                                perguntaItem,
                                                                r'''$['id']''',
                                                              ),
                                                            ),
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            children: [
                                                              FFButtonWidget(
                                                                onPressed: () {
                                                                  print(
                                                                      'Button pressed ...');
                                                                },
                                                                text:
                                                                    'Comentário',
                                                                icon: Icon(
                                                                  Icons
                                                                      .chat_bubble_outline,
                                                                  size: 14.0,
                                                                ),
                                                                options:
                                                                    FFButtonOptions(
                                                                  height: 32.0,
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          4.0,
                                                                          4.0,
                                                                          4.0,
                                                                          4.0),
                                                                  iconPadding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  iconColor: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryBackground,
                                                                  textStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .inter(
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .bodySmall
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodySmall
                                                                              .fontStyle,
                                                                        ),
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .bodySmall
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodySmall
                                                                            .fontStyle,
                                                                      ),
                                                                  elevation:
                                                                      0.0,
                                                                  borderSide:
                                                                      BorderSide(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .alternate,
                                                                    width: 1.0,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4.0),
                                                                ),
                                                              ),
                                                              FFButtonWidget(
                                                                onPressed: () {
                                                                  print(
                                                                      'Button pressed ...');
                                                                },
                                                                text: ' Anexo',
                                                                icon: Icon(
                                                                  Icons
                                                                      .attach_file,
                                                                  size: 14.0,
                                                                ),
                                                                options:
                                                                    FFButtonOptions(
                                                                  height: 32.0,
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          4.0,
                                                                          4.0,
                                                                          4.0,
                                                                          4.0),
                                                                  iconPadding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  iconColor: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryBackground,
                                                                  textStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .inter(
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .bodySmall
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodySmall
                                                                              .fontStyle,
                                                                        ),
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .bodySmall
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodySmall
                                                                            .fontStyle,
                                                                      ),
                                                                  elevation:
                                                                      0.0,
                                                                  borderSide:
                                                                      BorderSide(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .alternate,
                                                                    width: 1.0,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4.0),
                                                                ),
                                                              ),
                                                              FFButtonWidget(
                                                                onPressed: () {
                                                                  print(
                                                                      'Button pressed ...');
                                                                },
                                                                text:
                                                                    'Plano de Ação',
                                                                icon: Icon(
                                                                  Icons
                                                                      .assignment,
                                                                  size: 14.0,
                                                                ),
                                                                options:
                                                                    FFButtonOptions(
                                                                  height: 32.0,
                                                                  padding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          4.0,
                                                                          4.0,
                                                                          4.0,
                                                                          4.0),
                                                                  iconPadding: EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          0.0,
                                                                          0.0),
                                                                  iconColor: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryBackground,
                                                                  textStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .inter(
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .bodySmall
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .bodySmall
                                                                              .fontStyle,
                                                                        ),
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .bodySmall
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodySmall
                                                                            .fontStyle,
                                                                      ),
                                                                  elevation:
                                                                      0.0,
                                                                  borderSide:
                                                                      BorderSide(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .alternate,
                                                                    width: 1.0,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4.0),
                                                                ),
                                                              ),
                                                            ].divide(SizedBox(
                                                                width: 12.0)),
                                                          ),
                                                        ].divide(SizedBox(
                                                            height: 12.0)),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                        Divider(
                                          thickness: 1.0,
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                        ),
                                      ].divide(SizedBox(height: 16.0)),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ]
                        .divide(SizedBox(height: 20.0))
                        .addToStart(SizedBox(height: 20.0))
                        .addToEnd(SizedBox(height: 100.0)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
