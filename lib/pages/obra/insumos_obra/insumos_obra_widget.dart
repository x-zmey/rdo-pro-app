import '/auth/membership_access.dart';
import '/backend/sqlite/situacao_soft_delete.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/obra/obra_item_list_tile_widget.dart';
import '/componentes/obra/obra_item_metas_fields_widget.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _fetchRegistros(silent: false));
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
    Widget tab(String value, String label, IconData icon) {
      final selected = _tipoInsumo == value;
      return Expanded(
        child: Material(
          color: selected ? theme.secondaryBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          elevation: selected ? 1 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          child: InkWell(
            onTap: () => onSelect(value),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? theme.primary : theme.secondaryText,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.labelSmall.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      color: selected ? theme.primary : theme.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(
        children: [
          tab('avulso', 'Avulso', Icons.shopping_bag_outlined),
          tab('novo_insumo', 'Personalizado', Icons.tune_outlined),
          tab('insumo_existente', 'Cadastrado', Icons.fact_check_outlined),
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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = FlutterFlowTheme.of(context);
            InputDecoration fieldDeco({
              required String label,
              String? hint,
              IconData? icon,
            }) {
              return InputDecoration(
                labelText: label,
                hintText: hint,
                isDense: true,
                filled: true,
                fillColor: theme.primaryBackground,
                prefixIcon: icon != null
                    ? Icon(icon, size: 20, color: theme.secondaryText)
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: theme.alternate, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: theme.alternate, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: theme.primary, width: 1.5),
                ),
                labelStyle: theme.labelMedium,
                hintStyle: theme.labelMedium.override(
                  color: theme.secondaryText,
                ),
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

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.92,
                ),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20.0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.alternate,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: theme.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Novo insumo',
                                  style: theme.headlineSmall.override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cadastro na API e sincronização com o app.',
                                  style: theme.bodySmall.override(
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(sheetContext),
                            icon: Icon(Icons.close_rounded,
                                color: theme.secondaryText),
                            tooltip: 'Fechar',
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 24, thickness: 1, color: theme.alternate),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTipoInsumoTabs(
                              theme,
                              (v) => setModalState(() => _tipoInsumo = v),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hintTipo(),
                              style: theme.labelSmall.override(
                                color: theme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_tipoInsumo == 'insumo_existente') ...[
                              DropdownButtonFormField<String>(
                                initialValue: _insumoSelecionadoId,
                                decoration: fieldDeco(
                                  label: 'Insumo *',
                                  hint: 'Selecione',
                                  icon: Icons.search,
                                ),
                                items: _insumosCatalogo
                                    .map(
                                      (e) => DropdownMenuItem<String>(
                                        value: e['id']?.toString(),
                                        child: Text(
                                          (e['nome'] ?? 'Sem nome').toString(),
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
                                            (ins['categoria'] ?? '').toString();
                                      }
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_tipoInsumo == 'novo_insumo') ...[
                              Container(
                                width: double.infinity,
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
                                      'Novo insumo (catálogo)',
                                      style: theme.titleSmall.override(
                                        font: GoogleFonts.interTight(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: theme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _novoNomeController,
                                      decoration: fieldDeco(
                                        label: 'Nome *',
                                        icon: Icons.label_outline,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _novoCodigoController,
                                            decoration: fieldDeco(
                                              label: 'Código',
                                              icon: Icons.tag,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextFormField(
                                            controller:
                                                _novoCategoriaController,
                                            decoration: fieldDeco(
                                              label: 'Categoria',
                                              icon: Icons.category_outlined,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      initialValue: _novoUnidadeMedida,
                                      decoration: fieldDeco(
                                        label: 'Unidade (catálogo)',
                                        icon: Icons.straighten,
                                      ),
                                      items: _unidadeMenuItems,
                                      onChanged: (v) => setModalState(
                                        () => _novoUnidadeMedida =
                                            v ?? _novoUnidadeMedida,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _novoDescricaoController,
                                      maxLines: 2,
                                      decoration: fieldDeco(
                                        label: 'Descrição',
                                        icon: Icons.notes_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_tipoInsumo == 'avulso') ...[
                              TextFormField(
                                controller: _descricaoAvulsoController,
                                maxLines: 2,
                                decoration: fieldDeco(
                                  label: 'Descrição *',
                                  hint: 'Ex.: Cimento CP II 50 kg',
                                  icon: Icons.description_outlined,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            DropdownButtonFormField<String>(
                              initialValue: _unidadeObra,
                              decoration: fieldDeco(
                                label: 'Unidade *',
                                icon: Icons.straighten,
                              ),
                              items: _unidadeMenuItems,
                              onChanged: (v) => setModalState(
                                () => _unidadeObra = v ?? 'un',
                              ),
                            ),
                            if (_tipoInsumo == 'insumo_existente') ...[
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _categoriaObraController,
                                decoration: fieldDeco(
                                  label: 'Categoria',
                                  icon: Icons.category_outlined,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            ObraItemMetasFieldsWidget(
                              obraId: _obraApiIdentifier(),
                              controller: _metasController,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FFButtonWidget(
                                    onPressed: _isSaving
                                        ? null
                                        : () => Navigator.pop(sheetContext),
                                    text: 'Cancelar',
                                    options: FFButtonOptions(
                                      height: 48,
                                      color: theme.secondaryBackground,
                                      borderSide: BorderSide(
                                        color: theme.alternate,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      textStyle: theme.titleSmall,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FFButtonWidget(
                                    onPressed: _isSaving
                                        ? null
                                        : () async {
                                            final desc = _descricaoParaApi();
                                            if (desc.isEmpty) {
                                              ScaffoldMessenger.of(sheetContext)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Preencha a descrição ou selecione o insumo.',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            if (_tipoInsumo ==
                                                    'insumo_existente' &&
                                                (_insumoSelecionadoId == null ||
                                                    _insumoSelecionadoId!
                                                        .isEmpty)) {
                                              ScaffoldMessenger.of(sheetContext)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Selecione um insumo.',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            if (_tipoInsumo == 'novo_insumo' &&
                                                _novoNomeController.text
                                                    .trim()
                                                    .isEmpty) {
                                              ScaffoldMessenger.of(sheetContext)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Informe o nome do insumo.',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            await _cadastrarInsumoApi(
                                              closeModal: () =>
                                                  Navigator.pop(sheetContext),
                                            );
                                            if (mounted) setModalState(() {});
                                          },
                                    text: _isSaving ? 'Salvando...' : 'Salvar',
                                    icon: _isSaving
                                        ? null
                                        : Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                            color: theme.info,
                                          ),
                                    options: FFButtonOptions(
                                      height: 48,
                                      color: theme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                      textStyle: theme.titleSmall.override(
                                        font: GoogleFonts.interTight(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: theme.info,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: false,
          toolbarHeight: 52.0,
          leading: FlutterFlowIconButton(
            borderColor: FlutterFlowTheme.of(context).alternate,
            borderRadius: 10.0,
            borderWidth: 1.0,
            buttonSize: 36.0,
            fillColor: FlutterFlowTheme.of(context).secondaryBackground,
            icon: Icon(
              Icons.arrow_back_ios,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 16.0,
            ),
            onPressed: () async {
              context.pushNamed(
                DetalhesObraWidget.routeName,
                queryParameters: {
                  'obraId': serializeParam(
                    widget.obraId,
                    ParamType.int,
                  ),
                  'obraUuid': serializeParam(
                    widget.obraUuid,
                    ParamType.String,
                  ),
                }.withoutNulls,
                extra: <String, dynamic>{
                  '__transition_info__': TransitionInfo(
                    hasTransition: true,
                    transitionType: PageTransitionType.rightToLeft,
                  ),
                },
              );
            },
          ),
          title: Text(
            'Insumos',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontSize: 18.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_registros.length} ${_registros.length == 1 ? 'item encontrado' : 'itens encontrados'}',
                              style: FlutterFlowTheme.of(context).labelMedium,
                            ),
                          ),
                          if (_isRefreshingSilently)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    FlutterFlowIconButton(
                      borderRadius: 20,
                      buttonSize: 34,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: FlutterFlowTheme.of(context).primary,
                        size: 18,
                      ),
                      onPressed: (_isLoading || _isRefreshingSilently)
                          ? null
                          : () => _fetchRegistros(silent: true),
                    ),
                    const SizedBox(width: 6),
                    if (MembershipAccess.canPermission('create_insumos'))
                      FFButtonWidget(
                        onPressed: _abrirCadastroInsumo,
                        text: 'Novo',
                        icon: const Icon(Icons.add, size: 16),
                        options: FFButtonOptions(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          color: FlutterFlowTheme.of(context).primary,
                          textStyle:
                              FlutterFlowTheme.of(context).labelMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context).info,
                                  ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(12.0, 10.0, 12.0, 12.0),
                  child: _isLoading
                      ? Center(
                          child: LinearProgressIndicator(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        )
                      : _registros.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).alternate,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Nenhum insumo na obra',
                                    style: FlutterFlowTheme.of(context)
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Use Novo para cadastrar e vincular insumos à obra.',
                                    style:
                                        FlutterFlowTheme.of(context).bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                bottom: kBarraNavegacaoPrincipalReservaScroll,
                              ),
                              itemCount: _registros.length,
                              itemBuilder: (context, listViewIndex) {
                                return _buildInsumoListItem(
                                  context,
                                  item: _registros[listViewIndex],
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const BarraNavegacaoPrincipal(),
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
      qtd: qtd,
      qtdRealizada: realizada,
      unidade: unidade,
      mostrarExcluir: canDelete,
      podeExcluir: podeExcluir,
      isDeleting: isDeleting,
      marginBottom: 5,
      deleteTooltip: vinc
          ? 'Vinculado ao orçamento — não pode excluir'
          : 'Excluir',
      onExcluir: () => _confirmarExcluir(item),
    );
  }
}
