import '/auth/fetch_allowed_obras.dart';
import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import 'cadastrar_relatorio_geral_model.dart';
export 'cadastrar_relatorio_geral_model.dart';

/// Cadastro de RDO: obra, modelo, data (única ou período) e cópia do anterior.
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
  final _formKey = GlobalKey<FormState>();

  List<CarregaObrasRow> _obras = [];
  List<ModelosRelatoriosRow> _modelos = [];
  bool _obrasLoading = true;
  bool _modelosLoading = false;

  String? _obraUuid;
  String? _modeloUuid;
  FormFieldController<String>? _obraController;
  FormFieldController<String>? _modeloController;

  late final TextEditingController _dataController;
  late final TextEditingController _dataInicioController;
  late final TextEditingController _dataFinalController;
  late final FocusNode _dataFocus;
  late final FocusNode _dataInicioFocus;
  late final FocusNode _dataFinalFocus;
  late MaskTextInputFormatter _dataMask;
  late MaskTextInputFormatter _dataInicioMask;
  late MaskTextInputFormatter _dataFinalMask;

  /// Igual à web: sem opção "Fotos".
  static const _opcoesCopiar = <({String label, String value})>[
    (label: 'Atividades', value: 'atividades'),
    (label: 'Ocorrências', value: 'ocorrencias'),
    (label: 'Controle de materiais', value: 'controleMateriais'),
    (label: 'Comentários', value: 'comentarios'),
    (label: 'Mão de obra', value: 'mao_obra'),
  ];
  final Set<String> _copiarSelecionados = {};

  bool _salvando = false;

  static const _espacoCampo = 10.0;

  ModelosRelatoriosRow? get _modeloSelecionado {
    final u = _modeloUuid;
    if (u == null) return null;
    for (final m in _modelos) {
      if (m.uuid == u) return m;
    }
    return null;
  }

  bool get _isPeriodo => _modeloSelecionado?.isPeriodo ?? false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CadastrarRelatorioGeralModel());
    final hoje =
        dateTimeFormat('dd/MM/yyyy', getCurrentTimestamp, locale: 'pt_BR');
    MaskTextInputFormatter maskCom(String initial) => MaskTextInputFormatter(
          mask: '##/##/####',
          filter: {'#': RegExp(r'[0-9]')},
          initialText: initial,
          type: MaskAutoCompletionType.lazy,
        );
    _dataMask = maskCom(hoje);
    _dataInicioMask = maskCom(hoje);
    _dataFinalMask = maskCom(hoje);
    _dataController = TextEditingController(text: _dataMask.getMaskedText());
    _dataInicioController =
        TextEditingController(text: _dataInicioMask.getMaskedText());
    _dataFinalController =
        TextEditingController(text: _dataFinalMask.getMaskedText());
    _dataFocus = FocusNode();
    _dataInicioFocus = FocusNode();
    _dataFinalFocus = FocusNode();
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _obrasLoading = false;
        });
      }
    }
  }

  Future<void> _carregarModelos(String obraUuid) async {
    setState(() {
      _modelosLoading = true;
      _modelos = [];
      _modeloUuid = null;
      _modeloController = FormFieldController<String>(null);
    });
    try {
      final list = await SQLiteManager.instance.modelosRelatorios(
        obraUuid: obraUuid,
        accountOwnerUuid: FFAppState().creatorUuid,
      );
      if (!mounted) return;
      setState(() {
        _modelos = list;
        _modelosLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _modelosLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _dataController.dispose();
    _dataInicioController.dispose();
    _dataFinalController.dispose();
    _dataFocus.dispose();
    _dataInicioFocus.dispose();
    _dataFinalFocus.dispose();
    _model.dispose();
    super.dispose();
  }

  void _onObraChanged(String? u) {
    final uuid = (u == null || u.isEmpty) ? null : u;
    setState(() {
      _obraUuid = uuid;
      _modeloUuid = null;
      _modeloController = FormFieldController<String>(null);
      _modelos = [];
      _copiarSelecionados.clear();
    });
    if (uuid != null) {
      _carregarModelos(uuid);
    }
  }

  void _onModeloChanged(String? m) {
    setState(() {
      _modeloUuid = (m == null || m.isEmpty) ? null : m;
      if (_isPeriodo) {
        // Referência do período segue a data inicial (como na web).
        if (_dataInicioController.text.trim().isNotEmpty) {
          _dataController.text = _dataInicioController.text.trim();
        }
      }
    });
  }

  void _snack(String msg, {bool erro = false}) {
    final theme = FlutterFlowTheme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: erro ? theme.error : theme.secondary,
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

  DateTime? _parseDataBr(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return null;
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(t);
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (d == null || mo == null || y == null) return null;
    if (y < 1900 || y > 2100) return null;
    final dt = DateTime(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return dt;
  }

  String? _validarData(
    String? val, {
    bool aoDigitar = false,
    String campoVazio = 'Informe a data do relatório.',
  }) {
    final t = (val ?? '').trim();
    if (t.isEmpty) return campoVazio;
    final digitos = t.replaceAll(RegExp(r'\D'), '');
    if (aoDigitar && digitos.length < 8) return null;
    if (_parseDataBr(t) == null) {
      return 'Informe uma data válida (dd/mm/aaaa)';
    }
    return null;
  }

  Future<void> _criarRelatorio() async {
    if (_salvando) return;
    final obra = _obraSelecionada;
    final mUuid = _modeloUuid;
    final periodo = _isPeriodo;

    if (obra == null) {
      _snack('Selecione a obra.', erro: true);
      return;
    }
    if (mUuid == null || mUuid.isEmpty) {
      _snack('Selecione o modelo de relatório.', erro: true);
      return;
    }

    String dataTxt;
    String? dataInicio;
    String? dataFinal;

    if (periodo) {
      dataInicio = _dataInicioController.text.trim();
      dataFinal = _dataFinalController.text.trim();
      if (_validarData(dataInicio, campoVazio: 'Informe a data inicial.') !=
              null ||
          _validarData(dataFinal, campoVazio: 'Informe a data final.') !=
              null) {
        _formKey.currentState?.validate();
        _snack('Corrija as datas do período antes de continuar.', erro: true);
        return;
      }
      final ini = _parseDataBr(dataInicio)!;
      final fim = _parseDataBr(dataFinal)!;
      if (fim.isBefore(ini)) {
        _snack('Data final não pode ser anterior à data inicial.', erro: true);
        return;
      }
      // Referência = data inicial (igual web).
      dataTxt = dataInicio;
    } else {
      dataTxt = _dataController.text.trim();
      if (_validarData(dataTxt) != null) {
        _formKey.currentState?.validate();
        _snack('Corrija a data do relatório antes de continuar.', erro: true);
        return;
      }
    }

    final router = GoRouter.of(context);
    setState(() => _salvando = true);
    try {
      // Resolver relatório anterior ANTES de criar o novo (para cópia).
      final anteriorObra = await SQLiteManager.instance.carregaUltimoRelatorio(
        accountOwnerUuid: FFAppState().creatorUuid,
        obraUuid: obra.uuid,
      );
      final anteriorUuid = anteriorObra.firstOrNull?.uuid;

      final ultimoGlobal = await SQLiteManager.instance.carregaUltimoRelatorio(
        accountOwnerUuid: FFAppState().creatorUuid,
      );
      final numero = await actions.incriseRelatorioNumero(
        ultimoGlobal.firstOrNull?.numero,
      );
      final newUuid = await actions.generateUuid();
      await SQLiteManager.instance.cadastrarRelatorio(
        userId: FFAppState().creatorId,
        obraId: obra.id,
        modeloId: 0,
        dataexecutado: dataTxt,
        dataInicio: periodo ? dataInicio : null,
        dataFinal: periodo ? dataFinal : null,
        criador: FFAppState().UserUuid,
        numero: numero!,
        uuid: newUuid,
        creatorUuid: FFAppState().creatorUuid,
        userUuid: FFAppState().creatorUuid,
        obraUuid: obra.uuid,
        modeloUuid: mUuid,
      );

      final criado = await SQLiteManager.instance.relatorioDetalhes(
        uuid: newUuid,
        accountOwnerUuid: FFAppState().creatorUuid,
      );
      final novoId = criado.firstOrNull?.id;
      if (novoId == null) {
        throw Exception('Relatório criado sem id local.');
      }

      if (_copiarSelecionados.isNotEmpty &&
          anteriorUuid != null &&
          anteriorUuid.isNotEmpty) {
        await actions.copiarDadosRelatorioAnterior(
          novoRelatorioId: novoId,
          novoRelatorioUuid: newUuid,
          anteriorRelatorioUuid: anteriorUuid,
          dataReferencia: dataTxt,
          tiposParaCopiar: _copiarSelecionados.toList(),
          companyId: FFAppState().creatorId,
          companyUuid: FFAppState().creatorUuid,
          createdByUuid: FFAppState().creatorUuid,
        );
      }

      if (!mounted) return;
      final mensagem = periodo
          ? 'Relatório de período criado: $dataInicio a $dataFinal'
          : 'Relatório criado com sucesso!';
      _snack(mensagem);
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
        _snack('Não foi possível criar o relatório: $e', erro: true);
        setState(() => _salvando = false);
      }
    }
  }

  Widget _rotuloCampo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(texto.toUpperCase(), style: rdoColumnLabelStyle(context)),
      );

  Widget _dropDownIcon(FlutterFlowTheme theme) => Icon(
        Icons.keyboard_arrow_down_rounded,
        color: theme.secondaryText,
        size: 18,
      );

  Widget _loadingCampo() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _campoData({
    required TextEditingController controller,
    required FocusNode focus,
    required MaskTextInputFormatter mask,
    required String hint,
    required String? Function(String?) validator,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return TextFormField(
      controller: controller,
      focusNode: focus,
      keyboardType: TextInputType.number,
      inputFormatters: [mask],
      textInputAction: TextInputAction.done,
      style: rdoCompactFieldTextStyle(context),
      cursorColor: theme.primary,
      decoration: rdoCompactFieldDecoration(context, hint: hint),
      validator: validator,
      onChanged: (_) {
        if (_isPeriodo && identical(controller, _dataInicioController)) {
          _dataController.text = controller.text.trim();
        }
        _formKey.currentState?.validate();
        setState(() {});
      },
    );
  }

  Widget _secaoIdentificacao(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Identificação',
      icon: Icons.description_outlined,
      subtitle: 'Obra e modelo do RDO',
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rotuloCampo('Obra'),
          FlutterFlowDropDown<String>(
            key: const ValueKey('dd_obra_cad_rel'),
            controller: _obraController,
            options: _obras.map((e) => e.uuid).toList(),
            optionLabels: _obras.map((e) => e.nome).toList(),
            onChanged: _onObraChanged,
            width: double.infinity,
            height: 38,
            textStyle: rdoCompactFieldTextStyle(context),
            hintText: 'Selecionar obra',
            icon: _dropDownIcon(theme),
            fillColor: theme.secondaryBackground,
            elevation: 0,
            borderColor: theme.alternate,
            borderWidth: 1,
            borderRadius: 8,
            margin: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
            hidesUnderline: true,
            isSearchable: true,
            searchHintText: 'Buscar obra...',
            searchHintTextStyle: rdoCompactFieldTextStyle(context),
            searchTextStyle: rdoCompactFieldTextStyle(context),
            isMultiSelect: false,
          ),
          const SizedBox(height: _espacoCampo),
          _rotuloCampo('Modelo de relatório'),
          if (_obraUuid == null || _obraUuid!.isEmpty)
            Text(
              'Selecione uma obra para listar os modelos.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: theme.secondaryText,
              ),
            )
          else if (_modelosLoading)
            _loadingCampo()
          else if (_modelos.isEmpty)
            Text(
              'Nenhum modelo para esta obra. Sincronize os modelos e tente novamente.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: theme.error,
              ),
            )
          else ...[
            FlutterFlowDropDown<String>(
              key: ValueKey<String?>('m_$_obraUuid'),
              controller: _modeloController ??=
                  FormFieldController<String>(null),
              options: _modelos.map((e) => e.uuid).toList(),
              optionLabels: _modelos.map((e) => e.nome).toList(),
              onChanged: _onModeloChanged,
              width: double.infinity,
              height: 38,
              textStyle: rdoCompactFieldTextStyle(context),
              hintText: 'Selecionar modelo',
              icon: _dropDownIcon(theme),
              fillColor: theme.secondaryBackground,
              elevation: 0,
              borderColor: theme.alternate,
              borderWidth: 1,
              borderRadius: 8,
              margin: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
              hidesUnderline: true,
              isSearchable: false,
              isMultiSelect: false,
            ),
            if (_modeloUuid != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: (_isPeriodo ? Colors.orange : theme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_isPeriodo ? Colors.orange : theme.primary)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isPeriodo
                          ? Icons.date_range_outlined
                          : Icons.calendar_today_outlined,
                      size: 16,
                      color: _isPeriodo ? Colors.orange.shade800 : theme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isPeriodo
                            ? 'Relatório de período'
                            : 'Relatório de data única',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _isPeriodo
                              ? Colors.orange.shade900
                              : theme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _secaoData(FlutterFlowTheme theme) {
    final periodo = _isPeriodo;
    return RdoSectionCard(
      title: periodo ? 'Período do relatório' : 'Data do relatório',
      icon: Icons.calendar_today_outlined,
      subtitle: periodo
          ? 'Informe data inicial e final'
          : 'Dia de execução do RDO',
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!periodo) ...[
            _rotuloCampo('Data'),
            _campoData(
              controller: _dataController,
              focus: _dataFocus,
              mask: _dataMask,
              hint: 'dd/mm/aaaa',
              validator: (v) => _validarData(v, aoDigitar: true),
            ),
          ] else ...[
            _rotuloCampo('Data inicial'),
            _campoData(
              controller: _dataInicioController,
              focus: _dataInicioFocus,
              mask: _dataInicioMask,
              hint: 'dd/mm/aaaa',
              validator: (v) => _validarData(
                v,
                aoDigitar: true,
                campoVazio: 'Informe a data inicial.',
              ),
            ),
            const SizedBox(height: _espacoCampo),
            _rotuloCampo('Data final'),
            _campoData(
              controller: _dataFinalController,
              focus: _dataFinalFocus,
              mask: _dataFinalMask,
              hint: 'dd/mm/aaaa',
              validator: (v) {
                final err = _validarData(
                  v,
                  aoDigitar: true,
                  campoVazio: 'Informe a data final.',
                );
                if (err != null) return err;
                final ini = _parseDataBr(_dataInicioController.text);
                final fim = _parseDataBr(v);
                if (ini != null && fim != null && fim.isBefore(ini)) {
                  return 'Data final anterior à inicial';
                }
                return null;
              },
            ),
            if (_parseDataBr(_dataInicioController.text) != null &&
                _parseDataBr(_dataFinalController.text) != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_note_outlined,
                        size: 16, color: theme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Período: ${_dataInicioController.text.trim()} a ${_dataFinalController.text.trim()}',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _secaoCopiar(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Copiar dados do relatório anterior',
      icon: Icons.content_copy_outlined,
      subtitle: 'Selecione quais dados deseja copiar do último relatório desta obra',
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final op in _opcoesCopiar)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _copiarSelecionados.contains(op.value),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _copiarSelecionados.add(op.value);
                  } else {
                    _copiarSelecionados.remove(op.value);
                  }
                });
              },
              title: Text(
                op.label,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: theme.primaryText,
                ),
              ),
              activeColor: theme.primary,
            ),
          if (_copiarSelecionados.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Fotos das atividades não serão copiadas.',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: theme.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _botoesAcao(FlutterFlowTheme theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _salvando ? null : () => context.safePop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              foregroundColor: theme.primaryText,
              side: BorderSide(color: theme.alternate),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _salvando || _obras.isEmpty
                ? null
                : () async {
                    _formKey.currentState?.validate();
                    await _criarRelatorio();
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: theme.primary.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: _salvando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.note_add_outlined, size: 18),
            label: Text(
              _salvando ? 'Criando…' : 'Criar relatório',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _corpoVazio(FlutterFlowTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.apartment_outlined,
              size: 48,
              color: theme.secondaryText.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma obra disponível',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sincronize o app ou cadastre uma nova obra para criar o relatório.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.primary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleSpacing: 0,
          toolbarHeight: 58,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.safePop(),
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Novo relatório',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Criar RDO a partir de uma obra',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _obrasLoading
                  ? Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: theme.primary,
                        ),
                      ),
                    )
                  : _obras.isEmpty
                      ? _corpoVazio(theme)
                      : Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.disabled,
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              10,
                              16,
                              kBarraNavegacaoPrincipalReservaScroll,
                            ),
                            children: [
                              _secaoIdentificacao(theme),
                              const SizedBox(height: 10),
                              _secaoData(theme),
                              const SizedBox(height: 10),
                              _secaoCopiar(theme),
                              const SizedBox(height: 16),
                              _botoesAcao(theme),
                            ],
                          ),
                        ),
            ),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }
}
