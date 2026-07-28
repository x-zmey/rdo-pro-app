import '/auth/fetch_allowed_obras.dart';
import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import 'cadastrar_relatorio_geral_model.dart';
export 'cadastrar_relatorio_geral_model.dart';

/// Cadastro de RDO a partir de qualquer ecrã: seleciona obra, modelo e data.
class CadastrarRelatorioGeralWidget extends StatefulWidget {
  const CadastrarRelatorioGeralWidget({super.key});

  static const String routeName = 'cadastrarRelatorioGeral';
  static const String routePath = '/cadastrar-relatorio-geral';

  @override
  State<CadastrarRelatorioGeralWidget> createState() =>
      _CadastrarRelatorioGeralWidgetState();
}

class _CadastrarRelatorioGeralWidgetState
    extends State<CadastrarRelatorioGeralWidget> {
  late CadastrarRelatorioGeralModel _model;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<CarregaObrasRow> _obras = [];
  bool _obrasLoading = true;

  String? _obraUuid;
  String? _modeloUuid;
  FormFieldController<String>? _obraController;
  FormFieldController<String>? _modeloController;

  late final TextEditingController _dataController;
  late final FocusNode _dataFocus;
  late final MaskTextInputFormatter _dataMask;

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CadastrarRelatorioGeralModel());
    _dataController = TextEditingController(
      text: dateTimeFormat('dd/MM/yyyy', getCurrentTimestamp, locale: 'pt_BR'),
    );
    _dataFocus = FocusNode();
    _dataMask = MaskTextInputFormatter(mask: '##/##/####');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('generate_rdo')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para gerar RDO.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
        return;
      }
      _carregarObras();
    });
  }

  Future<void> _carregarObras() async {
    try {
      final obras = await loadAccessibleObras();
      if (!mounted) return;
      setState(() {
        _obras = obras;
        _obrasLoading = false;
        _obraController = FormFieldController<String>(null);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _obrasLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _dataController.dispose();
    _dataFocus.dispose();
    _model.dispose();
    super.dispose();
  }

  void _onObraChanged(String? u) {
    setState(() {
      _obraUuid = (u == null || u.isEmpty) ? null : u;
      _modeloUuid = null;
      _modeloController = FormFieldController<String>(null);
    });
  }

  void _onModeloChanged(String? m) {
    setState(() {
      _modeloUuid = (m == null || m.isEmpty) ? null : m;
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: TextStyle(color: FlutterFlowTheme.of(context).alternate)),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  }

  CarregaObrasRow? get _obraSelecionada {
    final u = _obraUuid;
    if (u == null) return null;
    for (final o in _obras) {
      if (o.uuid == u) return o;
    }
    return null;
  }

  Future<void> _criarRelatorio() async {
    if (_salvando) return;
    final obra = _obraSelecionada;
    final mUuid = _modeloUuid;
    final dataTxt = _dataController.text.trim();

    if (obra == null) {
      _snack('Selecione a obra.');
      return;
    }
    if (mUuid == null || mUuid.isEmpty) {
      _snack('Selecione o modelo de relatório.');
      return;
    }
    if (dataTxt.length < 10) {
      _snack('Informe a data do relatório (dd/mm/aaaa).');
      return;
    }

    final router = GoRouter.of(context);
    setState(() => _salvando = true);
    try {
      final ultimo = await SQLiteManager.instance.carregaUltimoRelatorio(
        accountOwnerUuid: FFAppState().creatorUuid,
      );
      final numero = await actions.incriseRelatorioNumero(
        ultimo.firstOrNull?.numero,
      );
      final newUuid = await actions.generateUuid();
      await SQLiteManager.instance.cadastrarRelatorio(
        userId: FFAppState().creatorId,
        obraId: obra.id,
        modeloId: 0,
        dataexecutado: dataTxt,
        criador: FFAppState().UserUuid,
        numero: numero!,
        uuid: newUuid,
        creatorUuid: FFAppState().creatorUuid,
        userUuid: FFAppState().creatorUuid,
        obraUuid: obra.uuid,
        modeloUuid: mUuid,
      );
      final relDet = await SQLiteManager.instance.carregaUltimoRelatorio(
        accountOwnerUuid: FFAppState().creatorUuid,
      );
      final novoId = relDet.firstOrNull?.id;
      if (!mounted) return;
      router.pop();
      router.pushNamed(
        ObraAddRelatorioWidget.routeName,
        queryParameters: {
          'id': serializeParam(novoId, ParamType.int),
          'uuid': serializeParam(newUuid, ParamType.String),
        }.withoutNulls,
        extra: <String, dynamic>{
          kTransitionInfoKey: const TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.rightToLeft,
          ),
        },
      );
    } catch (e) {
      if (mounted) {
        _snack('Não foi possível criar o relatório: $e');
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = FlutterFlowTheme.of(context);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: t.primaryBackground,
        appBar: AppBar(
          backgroundColor: t.primaryBackground,
          automaticallyImplyLeading: true,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 20.0,
            borderWidth: 1.0,
            buttonSize: 40.0,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: t.primaryText,
              size: 24.0,
            ),
            onPressed: () => context.safePop(),
          ),
          title: Text(
            'Cadastrar relatório',
            style: t.headlineMedium.override(
              font: GoogleFonts.interTight(
                fontWeight: FontWeight.w600,
                fontStyle: t.headlineMedium.fontStyle,
              ),
              fontSize: 20.0,
            ),
          ),
          elevation: 0.0,
        ),
        body: SafeArea(
          child: _obrasLoading
              ? Center(
                  child: LinearProgressIndicator(color: t.primary),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_obras.isEmpty)
                        Text(
                          'Nenhuma obra no dispositivo. Sincronize o app ou cadastre uma nova obra.',
                          style: t.bodyLarge,
                        )
                      else ...[
                        Text(
                          'Obra',
                          style: t.bodyMedium.override(
                            font: GoogleFonts.inter(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FlutterFlowDropDown<String>(
                          key: const ValueKey('dd_obra_cad_rel'),
                          controller: _obraController,
                          options: _obras.map((e) => e.uuid).toList(),
                          optionLabels: _obras.map((e) => e.nome).toList(),
                          onChanged: _onObraChanged,
                          width: double.infinity,
                          height: 50.0,
                          textStyle: t.bodyMedium,
                          hintText: 'Selecionar obra',
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: t.secondaryText,
                            size: 24.0,
                          ),
                          fillColor: t.secondaryBackground,
                          elevation: 2.0,
                          borderColor: t.alternate,
                          borderWidth: 1.0,
                          borderRadius: 8.0,
                          margin:
                              const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                          hidesUnderline: true,
                          isSearchable: false,
                          isMultiSelect: false,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Modelo de relatório',
                          style: t.bodyMedium.override(
                            font: GoogleFonts.inter(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_obraUuid == null || _obraUuid!.isEmpty)
                          Text(
                            'Selecione uma obra para listar os modelos.',
                            style: t.labelMedium.override(
                              color: t.secondaryText,
                            ),
                          )
                        else
                          KeyedSubtree(
                            key: ValueKey<String?>('m_$_obraUuid'),
                            child: FutureBuilder<List<ModelosRelatoriosRow>>(
                              future: SQLiteManager.instance
                                  .modelosRelatorios(
                                obraUuid: _obraUuid!,
                                accountOwnerUuid: FFAppState().creatorUuid,
                              ),
                              builder: (context, snap) {
                                if (!snap.hasData) {
                                  return const Center(
                                    child: LinearProgressIndicator(),
                                  );
                                }
                                final list = snap.data!;
                                if (list.isEmpty) {
                                  return Text(
                                    'Nenhum modelo para esta obra. Sincronize os modelos e tente novamente.',
                                    style: t.labelMedium.override(
                                      color: t.error,
                                    ),
                                  );
                                }
                                return FlutterFlowDropDown<String>(
                                  controller: _modeloController ??=
                                      FormFieldController<String>(null),
                                  options: list.map((e) => e.uuid).toList(),
                                  optionLabels:
                                      list.map((e) => e.nome).toList(),
                                  onChanged: _onModeloChanged,
                                  width: double.infinity,
                                  height: 50.0,
                                  textStyle: t.bodyMedium,
                                  hintText: 'Selecionar modelo',
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: t.secondaryText,
                                    size: 24.0,
                                  ),
                                  fillColor: t.secondaryBackground,
                                  elevation: 2.0,
                                  borderColor: t.alternate,
                                  borderWidth: 1.0,
                                  borderRadius: 8.0,
                                  margin: const EdgeInsetsDirectional.fromSTEB(
                                      0, 0, 0, 0),
                                  hidesUnderline: true,
                                  isSearchable: false,
                                  isMultiSelect: false,
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          'Data do relatório',
                          style: t.bodyMedium.override(
                            font: GoogleFonts.inter(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _dataController,
                          focusNode: _dataFocus,
                          inputFormatters: [_dataMask],
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: t.secondaryBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide(color: t.alternate),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          style: t.bodyMedium,
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: FFButtonWidget(
                                showLoadingIndicator: false,
                                onPressed: _salvando
                                    ? null
                                    : () {
                                        context.pop();
                                      },
                                text: 'Cancelar',
                                options: FFButtonOptions(
                                  height: 48.0,
                                  elevation: 0.0,
                                  color: t.secondaryBackground,
                                  textStyle: t.titleSmall,
                                  borderSide: BorderSide(
                                      color: t.alternate, width: 1.0),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FFButtonWidget(
                                showLoadingIndicator: false,
                                onPressed: _salvando || _obras.isEmpty
                                    ? null
                                    : _criarRelatorio,
                                text: _salvando
                                    ? 'A guardar...'
                                    : 'Criar relatório',
                                options: FFButtonOptions(
                                  height: 48.0,
                                  elevation: 0.0,
                                  color: t.primary,
                                  textStyle: t.titleSmall.override(
                                    color: t.info,
                                    font: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
