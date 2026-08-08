import '/auth/membership_access.dart';
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
import 'insumos_obra_model.dart';
export 'insumos_obra_model.dart';

/// Lista insumos da obra pela API, cadastro na API e sync — alinhado ao Vue
/// `MaterialTabPersonalizados` / `AddNewMaterialPersonalizado` e ao padrão de
/// `EquipamentosObraWidget`.
class InsumosObraWidget extends StatefulWidget {
  const InsumosObraWidget({
    super.key,
    required this.obraId,
    required this.obraUuid,
  });

  final int? obraId;
  final String? obraUuid;

  static String routeName = 'insumosObra';
  static String routePath = '/insumosObra';

  @override
  State<InsumosObraWidget> createState() => _InsumosObraWidgetState();
}

class _InsumosObraWidgetState extends State<InsumosObraWidget> {
  late InsumosObraModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRefreshingSilently = false;
  final Set<String> _deletingIds = <String>{};
  List<Map<String, dynamic>> _registros = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _insumosCatalogo = <Map<String, dynamic>>[];
  String _obraNome = '';

  String _tipoInsumo = 'avulso';
  String? _insumoSelecionadoId;

  final TextEditingController _descricaoAvulsoController =
      TextEditingController();
  String _unidadeObra = 'un';
  final TextEditingController _categoriaObraController =
      TextEditingController();

  final TextEditingController _novoNomeController = TextEditingController();
  final TextEditingController _novoCodigoController = TextEditingController();
  final TextEditingController _novoCategoriaController =
      TextEditingController();
  String _novoUnidadeMedida = 'un';
  final TextEditingController _novoDescricaoController =
      TextEditingController();
  final ObraItemMetasController _metasController = ObraItemMetasController();

  static const List<DropdownMenuItem<String>> _unidadeMenuItems = [
    DropdownMenuItem(value: 'un', child: Text('Unidade')),
    DropdownMenuItem(value: 'sc', child: Text('Saco')),
    DropdownMenuItem(value: 'kg', child: Text('Quilograma')),
    DropdownMenuItem(value: 'm', child: Text('Metro')),
    DropdownMenuItem(value: 'm²', child: Text('Metro quadrado')),
    DropdownMenuItem(value: 'm³', child: Text('Metro cúbico')),
    DropdownMenuItem(value: 'l', child: Text('Litro')),
    DropdownMenuItem(value: 'par', child: Text('Par')),
    DropdownMenuItem(value: 'cento', child: Text('Cento')),
    DropdownMenuItem(value: 'mil', child: Text('Milheiro')),
  ];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => InsumosObraModel());
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
    _categoriaObraController.dispose();
    _novoNomeController.dispose();
    _novoCodigoController.dispose();
    _novoCategoriaController.dispose();
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
    return double.tryParse(value.toString().replaceAll(',', '.'));
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
          'https://api.rdopro.com.br/api/obras/$obraIdentifier/itens?tipo=insumo',
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
            : 'Falha ao carregar insumos';
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
        SnackBar(content: Text('Erro ao carregar insumos: $e')),
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

  Future<void> _fetchInsumosCatalogo() async {
    if (_insumosCatalogo.isNotEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('https://api.rdopro.com.br/api/insumos'),
        headers: {
          'Authorization': 'Bearer ${_token()}',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final dynamic body = jsonDecode(response.body);
      if (!mounted) return;
      setState(() => _insumosCatalogo = _extractList(body));
    } catch (_) {}
  }

  Map<String, dynamic>? _insumoPorId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final e in _insumosCatalogo) {
      if (e['id']?.toString() == id) return e;
    }
    return null;
  }

  String _descricaoParaApi() {
    if (_tipoInsumo == 'avulso') {
      return _descricaoAvulsoController.text.trim();
    }
    if (_tipoInsumo == 'insumo_existente') {
      final ins = _insumoPorId(_insumoSelecionadoId);
      if (ins == null) return '';
      final nome = (ins['nome'] ?? '').toString();
      final cod = (ins['codigo'] ?? '').toString();
      return cod.isEmpty ? nome : '$nome ($cod)';
    }
    final nome = _novoNomeController.text.trim();
    final cod = _novoCodigoController.text.trim();
    if (cod.isEmpty) return nome;
    return '$nome ($cod)';
  }

  Widget _buildTipoInsumoTabs(
    FlutterFlowTheme theme,
    void Function(String value) onSelect,
  ) {
    const opcoes = [
      ('avulso', 'Avulso', 'Só na obra', Icons.shopping_bag_outlined),
      ('novo_insumo', 'Novo', 'Catálogo', Icons.tune_outlined),
      (
        'insumo_existente',
        'Cadastrado',
        'Do sistema',
        Icons.fact_check_outlined,
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
                  final selected = _tipoInsumo == opt.$1;
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

  Future<void> _abrirCadastroInsumo() async {
    if (!MembershipAccess.canPermission('create_insumos')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para criar insumos.',
      );
      return;
    }
    await _fetchInsumosCatalogo();
    if (!mounted) return;
    _tipoInsumo = 'avulso';
    _insumoSelecionadoId = null;
    _descricaoAvulsoController.clear();
    _unidadeObra = 'un';
    _categoriaObraController.clear();
    _novoNomeController.clear();
    _novoCodigoController.clear();
    _novoCategoriaController.clear();
    _novoUnidadeMedida = 'un';
    _novoDescricaoController.clear();
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
              switch (_tipoInsumo) {
                case 'insumo_existente':
                  return 'Vincular a um insumo já cadastrado no sistema.';
                case 'novo_insumo':
                  return 'Criar um novo insumo no catálogo e vincular à obra.';
                case 'avulso':
                default:
                  return 'Apenas descrição na obra, sem cadastro no catálogo.';
              }
            }

            Future<void> tentarSalvar() async {
              final desc = _descricaoParaApi();
              if (desc.isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Preencha a descrição ou selecione o insumo.',
                    ),
                  ),
                );
                return;
              }
              if (_tipoInsumo == 'insumo_existente' &&
                  (_insumoSelecionadoId == null ||
                      _insumoSelecionadoId!.isEmpty)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(content: Text('Selecione um insumo.')),
                );
                return;
              }
              if (_tipoInsumo == 'novo_insumo' &&
                  _novoNomeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Informe o nome do insumo.'),
                  ),
                );
                return;
              }
              await _cadastrarInsumoApi(
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
                                      'Novo insumo',
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
                            child: _buildTipoInsumoTabs(
                              theme,
                              (v) => setModalState(() => _tipoInsumo = v),
                            ),
                          ),
                          if (_tipoInsumo == 'avulso')
                            RdoSectionCard(
                              title: 'Dados na obra',
                              icon: Icons.shopping_bag_outlined,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _descricaoAvulsoController,
                                    style: rdoFormFieldTextStyle(context),
                                    maxLines: 2,
                                    decoration: fieldDeco(
                                      label: 'Descrição *',
                                      hint: 'Ex.: Cimento CP II 50 kg',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _unidadeObra,
                                    decoration:
                                        fieldDeco(label: 'Unidade *'),
                                    items: _unidadeMenuItems,
                                    onChanged: (v) => setModalState(
                                      () => _unidadeObra = v ?? 'un',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_tipoInsumo == 'insumo_existente')
                            RdoSectionCard(
                              title: 'Insumo do sistema',
                              icon: Icons.fact_check_outlined,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    initialValue: _insumoSelecionadoId,
                                    isExpanded: true,
                                    decoration: fieldDeco(
                                      label: 'Insumo *',
                                      hint: 'Selecione',
                                    ),
                                    items: _insumosCatalogo
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
                                        _insumoSelecionadoId = v;
                                        if (v != null) {
                                          final ins = _insumoPorId(v);
                                          if (ins != null) {
                                            _unidadeObra =
                                                (ins['unidade_medida'] ?? 'un')
                                                    .toString();
                                            _categoriaObraController.text =
                                                (ins['categoria'] ?? '')
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
                                    items: _unidadeMenuItems,
                                    onChanged: (v) => setModalState(
                                      () => _unidadeObra = v ?? 'un',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _categoriaObraController,
                                    style: rdoFormFieldTextStyle(context),
                                    decoration:
                                        fieldDeco(label: 'Categoria'),
                                  ),
                                ],
                              ),
                            ),
                          if (_tipoInsumo == 'novo_insumo') ...[
                            RdoSectionCard(
                              title: 'Catálogo',
                              icon: Icons.tune_outlined,
                              subtitle: 'Dados do novo insumo',
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
                                  DropdownButtonFormField<String>(
                                    initialValue: _novoUnidadeMedida,
                                    decoration: fieldDeco(
                                      label: 'Unidade (catálogo)',
                                    ),
                                    items: _unidadeMenuItems,
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
                                        fieldDeco(label: 'Descrição'),
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
                                items: _unidadeMenuItems,
                                onChanged: (v) => setModalState(
                                  () => _unidadeObra = v ?? 'un',
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

  Future<void> _cadastrarInsumoApi({
    required VoidCallback closeModal,
  }) async {
    final obraIdentifier = _obraApiIdentifier();
    if (obraIdentifier == null) return;
    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'tipo_insumo': _tipoInsumo,
        'descricao': _descricaoParaApi(),
        'qtd': 0,
        'unidade': _unidadeObra,
        'valor_unitario': 0,
      };

      if (_tipoInsumo == 'insumo_existente') {
        payload['id_insumo'] = _asInt(_insumoSelecionadoId);
      }

      if (_tipoInsumo == 'novo_insumo') {
        payload['novo_insumo'] = {
          'nome': _novoNomeController.text.trim(),
          'codigo': _novoCodigoController.text.trim().isEmpty
              ? null
              : _novoCodigoController.text.trim(),
          'categoria': _novoCategoriaController.text.trim().isEmpty
              ? null
              : _novoCategoriaController.text.trim(),
          'unidade_medida': _novoUnidadeMedida,
          'preco_unitario': 0,
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
          'https://api.rdopro.com.br/api/obras/$obraIdentifier/itens/insumo',
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
            : 'Falha ao cadastrar insumo';
        throw Exception(msg);
      }

      closeModal();
      if (!mounted) return;
      setState(() => _insumosCatalogo = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Insumo cadastrado na obra com sucesso!'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );

      await actions.syncInsumos();
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
    if (!MembershipAccess.canPermission('delete_insumos')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para excluir insumos.',
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
        title: const Text('Excluir insumo'),
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
      await _excluirInsumo(itemIdentifier);
    }
  }

  Future<void> _excluirInsumo(String itemIdentifier) async {
    if (_deletingIds.contains(itemIdentifier)) return;
    setState(() => _deletingIds.add(itemIdentifier));
    try {
      final response = await http.delete(
        Uri.parse('https://api.rdopro.com.br/api/obras/itens/$itemIdentifier'),
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
          content: const Text('Insumo removido com sucesso!'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );

      await actions.syncInsumos();
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
    final canCreate = MembershipAccess.canPermission('create_insumos');

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
                  'Insumos',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _obraNome.isEmpty
                      ? 'Insumos vinculados à obra'
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
                tooltip: 'Novo insumo',
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
                onPressed: _abrirCadastroInsumo,
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
                        title: 'Incluir insumo',
                        icon: Icons.add_circle_outline_rounded,
                        subtitle: 'Avulso, novo no catálogo ou já cadastrado',
                        margin: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.icon(
                          onPressed: _abrirCadastroInsumo,
                          icon: const Icon(Icons.inventory_2_outlined, size: 18),
                          label: Text(
                            'Novo insumo',
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
                      icon: Icons.inventory_2_outlined,
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
                                        Icons.inventory_2_outlined,
                                        size: 40,
                                        color: theme.secondaryText
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Nenhum insumo na obra',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: theme.primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Cadastre um insumo para vincular a esta obra.',
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
                                      _buildInsumoListItem(
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

  Widget _buildInsumoListItem(
    BuildContext context, {
    required Map<String, dynamic> item,
  }) {
    final itemIdentifier = _itemApiIdentifier(item);
    final qtd = _asDouble(item['qtd']) ?? 0;
    final realizada = _asDouble(item['qtd_realizada']) ?? 0;
    final unidade = (item['unidade'] ?? 'un').toString();
    final isDeleting = itemIdentifier != null &&
        _deletingIds.contains(itemIdentifier);
    final vinc = _itemVinculadoOrcamento(item);
    final canDelete = MembershipAccess.canPermission('delete_insumos');
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
