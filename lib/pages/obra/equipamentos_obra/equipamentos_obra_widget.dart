import '/auth/membership_access.dart';
import '/backend/api_requests/api_config.dart';
import '/backend/sqlite/situacao_soft_delete.dart';
import '/backend/sqlite/sqlite_manager.dart' show SQLiteManager;
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/obra/obra_item_list_tile_widget.dart';
import '/componentes/obra/obra_item_metas_fields_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'equipamentos_obra_model.dart';
export 'equipamentos_obra_model.dart';

/// Lista equipamentos da obra (SQLite), cadastro na API e sync — alinhado ao
/// fluxo da tela Vue `EquipamentosTabPersonalizados` e ao padrão visual de
/// `MaoObraWidget`.
class EquipamentosObraWidget extends StatefulWidget {
  const EquipamentosObraWidget({
    super.key,
    required this.obraId,
    required this.obraUuid,
  });

  final int? obraId;
  final String? obraUuid;

  static String routeName = 'equipamentosObra';
  static String routePath = '/equipamentosObra';

  @override
  State<EquipamentosObraWidget> createState() => _EquipamentosObraWidgetState();
}

class _EquipamentosObraWidgetState extends State<EquipamentosObraWidget> {
  late EquipamentosObraModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRefreshingSilently = false;
  final Set<String> _deletingIds = <String>{};
  List<Map<String, dynamic>> _registros = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _equipamentosCatalogo = <Map<String, dynamic>>[];
  String _obraNome = '';

  String _tipoEquipamento = 'avulso';
  String? _equipamentoSelecionadoId;

  final TextEditingController _descricaoAvulsoController =
      TextEditingController();
  String _unidadeObra = 'h';

  final TextEditingController _novoNomeController = TextEditingController();
  final TextEditingController _novoCodigoController = TextEditingController();
  final TextEditingController _novoCategoriaController =
      TextEditingController();
  final TextEditingController _novoMarcaController = TextEditingController();
  final TextEditingController _novoModeloController = TextEditingController();
  final TextEditingController _novoPlacaController = TextEditingController();
  final TextEditingController _novoSerieController = TextEditingController();
  final TextEditingController _novoDescricaoController =
      TextEditingController();
  String _novoUnidadeMedida = 'h';
  final ObraItemMetasController _metasController = ObraItemMetasController();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EquipamentosObraModel());
    _carregarNomeObra();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _fetchRegistros(silent: false));
  }

  Future<void> _carregarNomeObra() async {
    final uuid = (widget.obraUuid ?? '').trim();
    if (uuid.isEmpty) return;
    try {
      final rows = await SQLiteManager.instance.obraDetalhes(
        uuid: uuid,
        userId: FFAppState().creatorId,
        accountOwnerUuid: FFAppState().creatorUuid,
      );
      final nome = rows.firstOrNull?.nome.trim() ?? '';
      if (!mounted || nome.isEmpty) return;
      setState(() => _obraNome = nome);
    } catch (_) {}
  }

  void _voltarParaDetalhes() {
    context.pushNamed(
      DetalhesObraWidget.routeName,
      queryParameters: {
        'obraId': serializeParam(widget.obraId, ParamType.int),
        'obraUuid': serializeParam(widget.obraUuid, ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        '__transition_info__': const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    );
  }

  @override
  void dispose() {
    _descricaoAvulsoController.dispose();
    _novoNomeController.dispose();
    _novoCodigoController.dispose();
    _novoCategoriaController.dispose();
    _novoMarcaController.dispose();
    _novoModeloController.dispose();
    _novoPlacaController.dispose();
    _novoSerieController.dispose();
    _novoDescricaoController.dispose();
    _metasController.dispose();
    _model.dispose();
    super.dispose();
  }

  String _token() => FFAppState().UserToken;

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool _itemVinculadoOrcamento(Map<String, dynamic> item) {
    final v = item['id_orcamento_item'];
    if (v == null) return false;
    if (v is int) return v != 0;
    if (v is num) return v != 0;
    final s = v.toString().trim();
    if (s.isEmpty || s == '0') return false;
    return true;
  }

  String? _obraApiIdentifier() {
    final uuid = widget.obraUuid?.trim();
    if (uuid != null && uuid.isNotEmpty) return uuid;

    final id = widget.obraId;
    if (id != null && id > 0) return id.toString();

    return null;
  }

  String? _itemApiIdentifier(Map<String, dynamic> item) {
    final uuid = item['uuid']?.toString().trim();
    if (uuid != null && uuid.isNotEmpty) return uuid;

    final id = _asInt(item['id']);
    if (id != null && id > 0) return id.toString();

    return null;
  }

  List<Map<String, dynamic>> _extractList(dynamic body) {
    if (body is List) {
      return body
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (body is Map) {
      final candidates = [body['data'], body['value'], body['itens']];
      for (final c in candidates) {
        if (c is List) {
          return c
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _fetchRegistros({required bool silent}) async {
    final obraIdentifier = _obraApiIdentifier();
    if (obraIdentifier == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (silent) {
      if (mounted) setState(() => _isRefreshingSilently = true);
    } else {
      if (mounted) setState(() => _isLoading = true);
    }
    try {
      final response = await http.get(
        Uri.parse(
          '$kApiBaseUrl/api/obras/$obraIdentifier/itens?tipo=equipamento',
        ),
        headers: {
          'Authorization': 'Bearer ${_token()}',
          'Accept': 'application/json',
        },
      );
      final dynamic body =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (body is! Map || body['success'] != false);
      if (!ok) {
        final msg = body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Falha ao carregar equipamentos';
        throw Exception(msg);
      }
      final rows = _extractList(body);
      if (!mounted) return;
      setState(() {
        _registros = rows
            .where((r) {
              final s = _asInt(r['situacao']);
              return s != kSituacaoExcluidoLogico;
            })
            .map(
              (r) => <String, dynamic>{
                'id': _asInt(r['id']),
                'uuid': r['uuid']?.toString(),
                'descricao': r['descricao'],
                'qtd': r['qtd'],
                'qtd_realizada': _asDouble(r['qtd_realizada']) ?? 0,
                'unidade': r['unidade'],
                'valor_unitario': r['valor_unitario'],
                'situacao': r['situacao'],
                'id_orcamento_item': r['id_orcamento_item'],
              },
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar equipamentos: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshingSilently = false;
        });
      }
    }
  }

  Future<void> _fetchEquipamentosCatalogo() async {
    if (_equipamentosCatalogo.isNotEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('$kApiBaseUrl/api/equipamentos'),
        headers: {
          'Authorization': 'Bearer ${_token()}',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final dynamic body = jsonDecode(response.body);
      if (!mounted) return;
      setState(() => _equipamentosCatalogo = _extractList(body));
    } catch (_) {}
  }

  Map<String, dynamic>? _equipamentoPorId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final e in _equipamentosCatalogo) {
      if (e['id']?.toString() == id) return e;
    }
    return null;
  }

  String _descricaoParaApi() {
    if (_tipoEquipamento == 'avulso') {
      return _descricaoAvulsoController.text.trim();
    }
    if (_tipoEquipamento == 'equipamento_existente') {
      final eq = _equipamentoPorId(_equipamentoSelecionadoId);
      if (eq == null) return '';
      final nome = (eq['nome'] ?? '').toString();
      final cod = (eq['codigo'] ?? '').toString();
      return cod.isEmpty ? nome : '$nome ($cod)';
    }
    final nome = _novoNomeController.text.trim();
    final cod = _novoCodigoController.text.trim();
    if (cod.isEmpty) return nome;
    return '$nome ($cod)';
  }

  Widget _buildTipoEquipamentoTabs(
    FlutterFlowTheme theme,
    void Function(String value) onSelect,
  ) {
    const opcoes = [
      ('avulso', 'Avulso', 'Só na obra', Icons.handyman_outlined),
      ('novo_equipamento', 'Novo', 'Catálogo', Icons.tune_outlined),
      (
        'equipamento_existente',
        'Cadastrado',
        'Do sistema',
        Icons.build_circle_outlined
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.primaryBackground.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.alternate),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < opcoes.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Builder(
                builder: (context) {
                  final opt = opcoes[i];
                  final selected = _tipoEquipamento == opt.$1;
                  return Material(
                    color: selected ? theme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => onSelect(opt.$1),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              opt.$4,
                              size: 16,
                              color: selected
                                  ? Colors.white
                                  : theme.primary,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              opt.$2,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : theme.primaryText,
                              ),
                            ),
                            Text(
                              opt.$3,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _abrirCadastroEquipamento() async {
    if (!MembershipAccess.canPermission('create_equipamentos')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para criar equipamentos.',
      );
      return;
    }
    await _fetchEquipamentosCatalogo();
    if (!mounted) return;
    _tipoEquipamento = 'avulso';
    _equipamentoSelecionadoId = null;
    _descricaoAvulsoController.clear();
    _unidadeObra = 'h';
    _novoNomeController.clear();
    _novoCodigoController.clear();
    _novoCategoriaController.clear();
    _novoMarcaController.clear();
    _novoModeloController.clear();
    _novoPlacaController.clear();
    _novoSerieController.clear();
    _novoDescricaoController.clear();
    _novoUnidadeMedida = 'h';
    _metasController.reset();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = FlutterFlowTheme.of(context);
            InputDecoration fieldDeco({
              required String label,
              String? hint,
            }) {
              return rdoFormFieldDecoration(
                context,
                label: label,
                hint: hint,
              );
            }

            String hintTipo() {
              switch (_tipoEquipamento) {
                case 'equipamento_existente':
                  return 'Vincular um equipamento já cadastrado no sistema.';
                case 'novo_equipamento':
                  return 'Criar no catálogo e vincular à obra.';
                case 'avulso':
                default:
                  return 'Somente na obra, sem cadastro no catálogo.';
              }
            }

            Future<void> tentarSalvar() async {
              final desc = _descricaoParaApi();
              if (desc.isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Preencha a descrição ou selecione o equipamento.',
                    ),
                  ),
                );
                return;
              }
              if (_tipoEquipamento == 'equipamento_existente' &&
                  (_equipamentoSelecionadoId == null ||
                      _equipamentoSelecionadoId!.isEmpty)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: Text('Selecione um equipamento.')),
                );
                return;
              }
              if (_tipoEquipamento == 'novo_equipamento' &&
                  _novoNomeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Informe o nome do equipamento.'),
                  ),
                );
                return;
              }
              await _cadastrarEquipamentoApi(
                closeModal: () => Navigator.pop(sheetContext),
              );
              if (mounted) setModalState(() {});
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Container(
                height: MediaQuery.sizeOf(sheetContext).height * 0.94,
                decoration: BoxDecoration(
                  color: theme.primaryBackground,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: theme.primary,
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Fechar',
                                onPressed: _isSaving
                                    ? null
                                    : () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Novo equipamento',
                                      style: GoogleFonts.interTight(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      _obraNome.isEmpty
                                          ? 'Vincular à obra'
                                          : _obraNome,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        children: [
                          RdoSectionCard(
                            title: 'Tipo de cadastro',
                            icon: Icons.category_outlined,
                            subtitle: hintTipo(),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: _buildTipoEquipamentoTabs(
                              theme,
                              (v) =>
                                  setModalState(() => _tipoEquipamento = v),
                            ),
                          ),
                          if (_tipoEquipamento == 'avulso')
                            RdoSectionCard(
                              title: 'Dados na obra',
                              icon: Icons.handyman_outlined,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _descricaoAvulsoController,
                                    style: rdoFormFieldTextStyle(context),
                                    maxLines: 2,
                                    decoration: fieldDeco(
                                      label: 'Descrição *',
                                      hint: 'Ex.: Betoneira 400 L',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _unidadeObra,
                                    decoration:
                                        fieldDeco(label: 'Unidade *'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'h', child: Text('Hora (h)')),
                                      DropdownMenuItem(
                                          value: 'dia', child: Text('Dia')),
                                      DropdownMenuItem(
                                          value: 'mes', child: Text('Mês')),
                                      DropdownMenuItem(
                                          value: 'un', child: Text('Unidade')),
                                    ],
                                    onChanged: (v) => setModalState(
                                      () => _unidadeObra = v ?? 'h',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_tipoEquipamento == 'equipamento_existente')
                            RdoSectionCard(
                              title: 'Equipamento do sistema',
                              icon: Icons.build_circle_outlined,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    initialValue: _equipamentoSelecionadoId,
                                    isExpanded: true,
                                    decoration: fieldDeco(
                                      label: 'Equipamento *',
                                      hint: 'Selecione',
                                    ),
                                    items: _equipamentosCatalogo
                                        .map(
                                          (e) => DropdownMenuItem<String>(
                                            value: e['id']?.toString(),
                                            child: Text(
                                              (e['nome'] ?? 'Sem nome')
                                                  .toString(),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      setModalState(() {
                                        _equipamentoSelecionadoId = v;
                                        if (v != null) {
                                          final eq = _equipamentoPorId(v);
                                          if (eq != null) {
                                            _unidadeObra =
                                                (eq['unidade_medida'] ?? 'h')
                                                    .toString();
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _unidadeObra,
                                    decoration:
                                        fieldDeco(label: 'Unidade na obra *'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'h', child: Text('Hora (h)')),
                                      DropdownMenuItem(
                                          value: 'dia', child: Text('Dia')),
                                      DropdownMenuItem(
                                          value: 'mes', child: Text('Mês')),
                                      DropdownMenuItem(
                                          value: 'un', child: Text('Unidade')),
                                    ],
                                    onChanged: (v) => setModalState(
                                      () => _unidadeObra = v ?? 'h',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_tipoEquipamento == 'novo_equipamento') ...[
                            RdoSectionCard(
                              title: 'Catálogo',
                              icon: Icons.tune_outlined,
                              subtitle: 'Dados do novo equipamento',
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _novoNomeController,
                                    style: rdoFormFieldTextStyle(context),
                                    decoration: fieldDeco(label: 'Nome *'),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _novoCodigoController,
                                          style: rdoFormFieldTextStyle(context),
                                          decoration:
                                              fieldDeco(label: 'Código'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          controller:
                                              _novoCategoriaController,
                                          style: rdoFormFieldTextStyle(context),
                                          decoration:
                                              fieldDeco(label: 'Categoria'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _novoMarcaController,
                                          style: rdoFormFieldTextStyle(context),
                                          decoration: fieldDeco(label: 'Marca'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _novoModeloController,
                                          style: rdoFormFieldTextStyle(context),
                                          decoration:
                                              fieldDeco(label: 'Modelo'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _novoPlacaController,
                                          style: rdoFormFieldTextStyle(context),
                                          decoration: fieldDeco(
                                            label: 'Placa / identificação',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _novoSerieController,
                                          style: rdoFormFieldTextStyle(context),
                                          decoration:
                                              fieldDeco(label: 'Nº série'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _novoUnidadeMedida,
                                    decoration: fieldDeco(
                                      label: 'Unidade (catálogo)',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'h', child: Text('Hora (h)')),
                                      DropdownMenuItem(
                                          value: 'dia', child: Text('Dia')),
                                      DropdownMenuItem(
                                          value: 'mes', child: Text('Mês')),
                                      DropdownMenuItem(
                                          value: 'un', child: Text('Unidade')),
                                    ],
                                    onChanged: (v) => setModalState(
                                      () => _novoUnidadeMedida =
                                          v ?? _novoUnidadeMedida,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _novoDescricaoController,
                                    style: rdoFormFieldTextStyle(context),
                                    maxLines: 2,
                                    decoration:
                                        fieldDeco(label: 'Observações'),
                                  ),
                                ],
                              ),
                            ),
                            RdoSectionCard(
                              title: 'Na obra',
                              icon: Icons.apartment_outlined,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: DropdownButtonFormField<String>(
                                initialValue: _unidadeObra,
                                decoration:
                                    fieldDeco(label: 'Unidade na obra *'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'h', child: Text('Hora (h)')),
                                  DropdownMenuItem(
                                      value: 'dia', child: Text('Dia')),
                                  DropdownMenuItem(
                                      value: 'mes', child: Text('Mês')),
                                  DropdownMenuItem(
                                      value: 'un', child: Text('Unidade')),
                                ],
                                onChanged: (v) => setModalState(
                                  () => _unidadeObra = v ?? 'h',
                                ),
                              ),
                            ),
                          ],
                          RdoSectionCard(
                            title: 'Metas',
                            icon: Icons.flag_outlined,
                            subtitle: 'Opcional',
                            margin: EdgeInsets.zero,
                            child: ObraItemMetasFieldsWidget(
                              obraId: _obraApiIdentifier(),
                              controller: _metasController,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      decoration: BoxDecoration(
                        color: theme.secondaryBackground,
                        border:
                            Border(top: BorderSide(color: theme.alternate)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => Navigator.pop(sheetContext),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.primaryText,
                                  side: BorderSide(color: theme.alternate),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
                                onPressed: _isSaving ? null : tentarSalvar,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_rounded, size: 18),
                                label: Text(
                                  _isSaving ? 'Salvando…' : 'Salvar',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _cadastrarEquipamentoApi({
    required VoidCallback closeModal,
  }) async {
    final obraIdentifier = _obraApiIdentifier();
    if (obraIdentifier == null) return;
    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'tipo_equipamento': _tipoEquipamento,
        'descricao': _descricaoParaApi(),
        'qtd': 0,
        'unidade': _unidadeObra,
        'valor_unitario': 0,
      };

      if (_tipoEquipamento == 'equipamento_existente') {
        payload['id_equipamento'] = _asInt(_equipamentoSelecionadoId);
      }

      if (_tipoEquipamento == 'novo_equipamento') {
        payload['novo_equipamento'] = {
          'nome': _novoNomeController.text.trim(),
          'codigo': _novoCodigoController.text.trim().isEmpty
              ? null
              : _novoCodigoController.text.trim(),
          'categoria': _novoCategoriaController.text.trim().isEmpty
              ? null
              : _novoCategoriaController.text.trim(),
          'unidade_medida': _novoUnidadeMedida,
          'valor_hora': 0,
          'valor_diaria': 0,
          'valor_mensal': 0,
          'marca': _novoMarcaController.text.trim().isEmpty
              ? null
              : _novoMarcaController.text.trim(),
          'modelo': _novoModeloController.text.trim().isEmpty
              ? null
              : _novoModeloController.text.trim(),
          'placa_identificacao': _novoPlacaController.text.trim().isEmpty
              ? null
              : _novoPlacaController.text.trim(),
          'numero_serie': _novoSerieController.text.trim().isEmpty
              ? null
              : _novoSerieController.text.trim(),
          'descricao': _novoDescricaoController.text.trim().isEmpty
              ? null
              : _novoDescricaoController.text.trim(),
        };
      }

      final metas = _metasController.toPayload();
      if (metas.isNotEmpty) {
        payload['metas'] = metas;
      }

      final response = await http.post(
        Uri.parse(
          '$kApiBaseUrl/api/obras/$obraIdentifier/itens/equipamento',
        ),
        headers: {
          'Authorization': 'Bearer ${_token()}',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      final dynamic body =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (body is! Map || body['success'] != false);
      if (!ok) {
        final msg = body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Falha ao cadastrar equipamento';
        throw Exception(msg);
      }

      closeModal();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Equipamento cadastrado na obra com sucesso!'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );

      await actions.syncEquipamentos();
      await actions.syncObrasItens();
      if (mounted) await _fetchRegistros(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cadastrar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmarExcluir(Map<String, dynamic> item) async {
    if (!MembershipAccess.canPermission('delete_equipamentos')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para excluir equipamentos.',
      );
      return;
    }
    final itemIdentifier = _itemApiIdentifier(item);
    if (itemIdentifier == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível identificar o item.')),
      );
      return;
    }
    if (_itemVinculadoOrcamento(item)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Item vinculado ao orçamento — não pode excluir.',
          ),
        ),
      );
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir equipamento'),
        content: Text(
          'Deseja excluir "${(item['descricao'] ?? '').toString()}" desta obra?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await _excluirEquipamento(itemIdentifier);
    }
  }

  Future<void> _excluirEquipamento(String itemIdentifier) async {
    if (_deletingIds.contains(itemIdentifier)) return;
    setState(() => _deletingIds.add(itemIdentifier));
    try {
      final response = await http.delete(
        Uri.parse('$kApiBaseUrl/api/obras/itens/$itemIdentifier'),
        headers: {
          'Authorization': 'Bearer ${_token()}',
          'Accept': 'application/json',
        },
      );
      final dynamic body =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (body is! Map || body['success'] != false);
      if (!ok) {
        final msg = body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Falha ao excluir';
        throw Exception(msg);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Equipamento removido com sucesso!'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );

      await actions.syncEquipamentos();
      await actions.syncObrasItens();
      if (mounted) await _fetchRegistros(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(itemIdentifier));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final canCreate =
        MembershipAccess.canPermission('create_equipamentos');

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
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
            onPressed: _voltarParaDetalhes,
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Equipamentos',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _obraNome.isEmpty
                      ? 'Equipamentos vinculados à obra'
                      : _obraNome,
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
          actions: [
            IconButton(
              tooltip: 'Atualizar',
              icon: _isRefreshingSilently
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 21),
              onPressed: (_isLoading || _isRefreshingSilently)
                  ? null
                  : () => _fetchRegistros(silent: true),
            ),
            if (canCreate)
              IconButton(
                tooltip: 'Novo equipamento',
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
                onPressed: _abrirCadastroEquipamento,
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: theme.primary,
                onRefresh: () => _fetchRegistros(silent: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    kBarraNavegacaoPrincipalReservaScroll,
                  ),
                  children: [
                    if (canCreate)
                      RdoSectionCard(
                        title: 'Incluir equipamento',
                        icon: Icons.add_circle_outline_rounded,
                        subtitle: 'Avulso, novo no catálogo ou já cadastrado',
                        margin: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.icon(
                          onPressed: _abrirCadastroEquipamento,
                          icon: const Icon(Icons.construction_rounded, size: 18),
                          label: Text(
                            'Novo equipamento',
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
                      ),
                    RdoSectionCard(
                      title: 'Lista da obra',
                      icon: Icons.construction_outlined,
                      margin: EdgeInsets.zero,
                      trailing: _registros.isEmpty
                          ? null
                          : RdoContadorChip('${_registros.length}'),
                      contentPadding: EdgeInsets.zero,
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 36),
                              child: Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5),
                                ),
                              ),
                            )
                          : _registros.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 28, 16, 28),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.construction_outlined,
                                        size: 40,
                                        color: theme.secondaryText
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Nenhum equipamento na obra',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: theme.primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Cadastre um equipamento para vincular a esta obra.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          color: theme.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    for (var i = 0;
                                        i < _registros.length;
                                        i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: theme.alternate,
                                        ),
                                      _buildEquipamentoListItem(
                                        context,
                                        item: _registros[i],
                                      ),
                                    ],
                                  ],
                                ),
                    ),
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

  Widget _buildEquipamentoListItem(
    BuildContext context, {
    required Map<String, dynamic> item,
  }) {
    final itemIdentifier = _itemApiIdentifier(item);
    final qtd = _asDouble(item['qtd']) ?? 0;
    final realizada = _asDouble(item['qtd_realizada']) ?? 0;
    final unidade = (item['unidade'] ?? 'un').toString();
    final isDeleting =
        itemIdentifier != null && _deletingIds.contains(itemIdentifier);
    final vinc = _itemVinculadoOrcamento(item);
    final canDelete = MembershipAccess.canPermission('delete_equipamentos');
    final podeExcluir = canDelete &&
        itemIdentifier != null &&
        !isDeleting &&
        !_isSaving &&
        !vinc;

    return ObraItemListTileWidget(
      titulo: (item['descricao'] ?? 'Sem nome').toString(),
      subtitulo: vinc ? 'Vinculado ao orçamento' : null,
      qtd: qtd,
      qtdRealizada: realizada,
      unidade: unidade,
      mostrarExcluir: canDelete,
      podeExcluir: podeExcluir,
      isDeleting: isDeleting,
      deleteTooltip: vinc
          ? 'Vinculado ao orçamento — não pode excluir'
          : 'Excluir',
      onExcluir: () => _confirmarExcluir(item),
    );
  }
}
