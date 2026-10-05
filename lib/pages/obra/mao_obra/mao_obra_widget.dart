import 'dart:async';

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
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'mao_obra_model.dart';
export 'mao_obra_model.dart';

/// crie uma página chamada insumos da obra, ela irá listar os insumos em
/// estoque da obra cada item da lista vai ter uma descrição, uma unidade de
/// medição a qtd e coloque tbm um botão de voltar pagina
class MaoObraWidget extends StatefulWidget {
  const MaoObraWidget({
    super.key,
    required this.obraId,
    required this.obraUuid,
  });

  final int? obraId;
  final String? obraUuid;

  static String routeName = 'maoObra';
  static String routePath = '/maoObra';

  @override
  State<MaoObraWidget> createState() => _MaoObraWidgetState();
}

class _MaoObraWidgetState extends State<MaoObraWidget> {
  late MaoObraModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  bool _isSaving = false;

  /// Atualização leve pela API sem esconder a lista inteira.
  bool _isRefreshingSilently = false;
  final Set<String> _deletingIds = <String>{};
  List<Map<String, dynamic>> _registros = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _profissionais = <Map<String, dynamic>>[];
  List<String> _funcoesMaoObra = <String>[];
  String _obraNome = '';

  String _tipoVinculacao = 'funcao_generica';
  String? _profissionalSelecionadoId;

  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _cargoFuncaoController = TextEditingController();
  final TextEditingController _novoNomeController = TextEditingController();
  final TextEditingController _novoCpfController = TextEditingController();
  final TextEditingController _novoTelefoneController = TextEditingController();
  final TextEditingController _novoEmailController = TextEditingController();
  final TextEditingController _novoDataAdmissaoController =
      TextEditingController();
  final ObraItemMetasController _metasController = ObraItemMetasController();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MaoObraModel());
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
    _descricaoController.dispose();
    _cargoFuncaoController.dispose();
    _novoNomeController.dispose();
    _novoCpfController.dispose();
    _novoTelefoneController.dispose();
    _novoEmailController.dispose();
    _novoDataAdmissaoController.dispose();
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

  /// Mesma ideia do Vue: `vinculada: !!item.id_orcamento_item`.
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

  String _tipoMaoObraLabel(String? tipo) {
    switch (tipo) {
      case 'profissional_existente':
        return 'Cadastrado';
      case 'novo_profissional':
        return 'Personalizado';
      case 'funcao_generica':
      default:
        return 'Função';
    }
  }

  String _onlyDigits(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

  void _setMaskedValue(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String _formatCpf(String raw) {
    final d = _onlyDigits(raw);
    if (d.isEmpty) return '';
    final digits = d.length > 11 ? d.substring(0, 11) : d;
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) b.write('.');
      if (i == 9) b.write('-');
      b.write(digits[i]);
    }
    return b.toString();
  }

  String _formatTelefoneBr(String raw) {
    final d = _onlyDigits(raw);
    if (d.isEmpty) return '';
    final digits = d.length > 11 ? d.substring(0, 11) : d;
    if (digits.length <= 2) return '($digits';
    final ddd = digits.substring(0, 2);
    final rest = digits.substring(2);
    if (rest.length <= 4) return '($ddd) $rest';
    if (rest.length == 8) {
      return '($ddd) ${rest.substring(0, 4)}-${rest.substring(4)}';
    }
    final first = rest.length >= 5 ? rest.substring(0, 5) : rest;
    final second = rest.length > 5 ? rest.substring(5) : '';
    return second.isEmpty ? '($ddd) $first' : '($ddd) $first-$second';
  }

  String _formatDateBr(String raw) {
    final d = _onlyDigits(raw);
    if (d.isEmpty) return '';
    final digits = d.length > 8 ? d.substring(0, 8) : d;
    if (digits.length <= 2) return digits;
    if (digits.length <= 4) {
      return '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}';
  }

  String? _toApiDateFromBr(String? brDate) {
    if (brDate == null || brDate.trim().isEmpty) return null;
    final m = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(brDate.trim());
    if (m == null) return null;
    final dd = m.group(1)!;
    final mm = m.group(2)!;
    final yyyy = m.group(3)!;
    return '$yyyy-$mm-$dd';
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
          '$kApiBaseUrl/api/obras/$obraIdentifier/itens?tipo=mao_obra',
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
            : 'Falha ao carregar mão de obra';
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
                'cargo_funcao': r['cargo_funcao'],
                'tipo_mao_obra': r['tipo_mao_obra'],
                'situacao': r['situacao'],
                'id_orcamento_item': r['id_orcamento_item'],
              },
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar mão de obra: $e')),
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

  Future<String?> _fetchProfissionais({bool force = false}) async {
    if (!force && _profissionais.isNotEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('$kApiBaseUrl/api/mao-obra-profissionais'),
        headers: {
          'Authorization': 'Bearer ${_token()}',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final dynamic body =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final msg = body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Falha ao carregar profissionais.';
        return msg;
      }

      // Espelho 1:1 do frontend AddNewFuncionarioPersonalizado.vue:
      // if success && data[] | else profissionais.data[] | else body[].
      List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
      if (body is Map && body['success'] == true && body['data'] is List) {
        list = (body['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (body is Map &&
          body['profissionais'] is Map &&
          (body['profissionais'] as Map)['data'] is List) {
        list = ((body['profissionais'] as Map)['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (body is List) {
        list = body
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (!mounted) return null;
      setState(() => _profissionais = list);
      if (list.isEmpty) {
        return 'Nenhum profissional cadastrado encontrado.';
      }
      return null;
    } on TimeoutException {
      return 'Tempo esgotado ao carregar profissionais. Tente novamente.';
    } catch (e) {
      return 'Erro ao carregar profissionais: $e';
    }
  }

  Future<void> _fetchFuncoesMaoObra() async {
    try {
      final response = await http.get(
        Uri.parse('$kApiBaseUrl/api/funcoes-mao-obra'),
        headers: {
          'Authorization': 'Bearer ${_token()}',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final dynamic body =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      final rows = _extractList(body);
      final list = <String>[];
      for (final r in rows) {
        final nome = (r['nome'] ?? '').toString().trim();
        if (nome.isNotEmpty) list.add(nome);
      }
      if (!mounted) return;
      setState(() => _funcoesMaoObra = list.toSet().toList()..sort());
    } catch (_) {}
  }

  Widget _buildTipoMaoObraTabs(
    FlutterFlowTheme theme,
    void Function(String value) onSelect,
  ) {
    const opcoes = [
      ('funcao_generica', 'Função', 'Só na obra', Icons.badge_outlined),
      ('novo_profissional', 'Personalizado', 'Novo cadastro', Icons.tune_outlined),
      (
        'profissional_existente',
        'Cadastrado',
        'Do sistema',
        Icons.how_to_reg_outlined,
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
                  final selected = _tipoVinculacao == opt.$1;
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

  Future<void> _abrirCadastroMaoObra() async {
    if (!MembershipAccess.canPermission('create_mao_obra')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para criar mão de obra.',
      );
      return;
    }
    await _fetchProfissionais();
    await _fetchFuncoesMaoObra();
    if (!mounted) return;
    _tipoVinculacao = 'funcao_generica';
    _profissionalSelecionadoId = null;
    _descricaoController.clear();
    _cargoFuncaoController.clear();
    _novoNomeController.clear();
    _novoCpfController.clear();
    _novoTelefoneController.clear();
    _novoEmailController.clear();
    _novoDataAdmissaoController.clear();
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
              switch (_tipoVinculacao) {
                case 'profissional_existente':
                  return 'Vincular a um profissional já cadastrado no sistema.';
                case 'novo_profissional':
                  return 'Criar um novo profissional e vincular à obra.';
                case 'funcao_generica':
                default:
                  return 'Apenas descrição da função, sem vínculo com cadastro.';
              }
            }

            Future<void> selecionarProfissional() async {
              FocusScope.of(sheetContext).unfocus();
              final rootNav =
                  Navigator.of(sheetContext, rootNavigator: true);
              showDialog<void>(
                context: sheetContext,
                useRootNavigator: true,
                barrierDismissible: false,
                builder: (ctx) => const AlertDialog(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Carregando profissionais...'),
                      ),
                    ],
                  ),
                ),
              );
              final loadError = await _fetchProfissionais(force: true);
              if (rootNav.canPop()) {
                rootNav.pop();
              }
              if (!sheetContext.mounted) return;
              if (loadError != null) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text(loadError)),
                );
                return;
              }
              final selectedId = await showDialog<String>(
                context: sheetContext,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Vincular a profissional cadastrado'),
                  content: SizedBox(
                    width: 420,
                    height: 360,
                    child: ListView.separated(
                      itemCount: _profissionais.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final p = _profissionais[idx];
                        final id = p['id']?.toString();
                        final nome = (p['nome_completo'] ??
                                p['nome'] ??
                                'Sem nome')
                            .toString();
                        final funcao =
                            (p['cargo_funcao'] ?? '').toString();
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.person_outline),
                          title: Text(
                            nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: funcao.trim().isEmpty
                              ? null
                              : Text(
                                  funcao,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: id == null
                              ? null
                              : () => Navigator.pop(dialogContext, id),
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              );
              if (selectedId == null || !mounted) return;
              setModalState(
                  () => _profissionalSelecionadoId = selectedId);
              final selected = _profissionais.firstWhere(
                (e) => e['id']?.toString() == selectedId,
                orElse: () => <String, dynamic>{},
              );
              _descricaoController.text =
                  (selected['nome_completo'] ?? '').toString();
              _cargoFuncaoController.text =
                  (selected['cargo_funcao'] ?? '').toString();
            }

            Future<void> tentarSalvar() async {
              final desc = (_tipoVinculacao == 'profissional_existente')
                  ? _descricaoController.text.trim()
                  : (_tipoVinculacao == 'novo_profissional')
                      ? _novoNomeController.text.trim()
                      : _descricaoController.text.trim();
              if (desc.isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Preencha a descrição ou nome.'),
                  ),
                );
                return;
              }
              if (_tipoVinculacao == 'profissional_existente' &&
                  (_profissionalSelecionadoId == null ||
                      _profissionalSelecionadoId!.isEmpty)) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Selecione um profissional.'),
                  ),
                );
                return;
              }
              if (_tipoVinculacao == 'novo_profissional' &&
                  _novoNomeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  const SnackBar(
                    content: Text('Informe o nome do novo profissional.'),
                  ),
                );
                return;
              }
              await _cadastrarMaoObraApi(
                descricao: desc,
                closeModal: () => Navigator.pop(sheetContext),
              );
              if (mounted) setModalState(() {});
            }

            Widget cargoFuncaoFields() {
              if (_tipoVinculacao == 'novo_profissional' &&
                  _funcoesMaoObra.isNotEmpty) {
                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _funcoesMaoObra.contains(
                              _cargoFuncaoController.text.trim())
                          ? _cargoFuncaoController.text.trim()
                          : null,
                      decoration: fieldDeco(
                        label: 'Cargo / função *',
                        hint: 'Selecione uma função',
                      ),
                      items: _funcoesMaoObra
                          .map(
                            (f) => DropdownMenuItem<String>(
                              value: f,
                              child: Text(
                                f,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null || v.isEmpty) return;
                        setModalState(() => _cargoFuncaoController.text = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cargoFuncaoController,
                      style: rdoFormFieldTextStyle(context),
                      decoration: fieldDeco(
                        label: 'Cargo / função (manual)',
                        hint: 'Se preferir, ajuste ou digite outro cargo',
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  TextFormField(
                    controller: _cargoFuncaoController,
                    style: rdoFormFieldTextStyle(context),
                    decoration: fieldDeco(
                      label: 'Cargo / função',
                      hint: 'Ex.: Pedreiro, Mestre de obras',
                    ),
                  ),
                  if (_funcoesMaoObra.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _funcoesMaoObra.contains(
                              _cargoFuncaoController.text.trim())
                          ? _cargoFuncaoController.text.trim()
                          : null,
                      decoration: fieldDeco(
                        label: 'Função predefinida',
                        hint: 'Selecionar',
                      ),
                      items: _funcoesMaoObra
                          .map(
                            (f) => DropdownMenuItem<String>(
                              value: f,
                              child: Text(f),
                            ),
                          )
                          .toList(),
                      onChanged: (_tipoVinculacao == 'novo_profissional')
                          ? null
                          : (v) {
                              if (v == null || v.isEmpty) return;
                              setModalState(
                                  () => _cargoFuncaoController.text = v);
                            },
                    ),
                  ],
                ],
              );
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
                                      'Nova mão de obra',
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
                            child: _buildTipoMaoObraTabs(
                              theme,
                              (v) =>
                                  setModalState(() => _tipoVinculacao = v),
                            ),
                          ),
                          if (_tipoVinculacao == 'funcao_generica')
                            RdoSectionCard(
                              title: 'Dados na obra',
                              icon: Icons.badge_outlined,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _descricaoController,
                                    style: rdoFormFieldTextStyle(context),
                                    maxLines: 2,
                                    decoration: fieldDeco(
                                      label: 'Descrição *',
                                      hint:
                                          'Ex.: Pedreiro para alvenaria, ajudante geral',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  cargoFuncaoFields(),
                                ],
                              ),
                            ),
                          if (_tipoVinculacao == 'profissional_existente')
                            RdoSectionCard(
                              title: 'Profissional do sistema',
                              icon: Icons.how_to_reg_outlined,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  InputDecorator(
                                    decoration: fieldDeco(
                                      label: 'Profissional *',
                                      hint: 'Selecione',
                                    ),
                                    child: Text(
                                      (() {
                                        final selected =
                                            _profissionais.firstWhere(
                                          (e) =>
                                              e['id']?.toString() ==
                                              _profissionalSelecionadoId,
                                          orElse: () => <String, dynamic>{},
                                        );
                                        final nome = (selected['nome_completo'] ??
                                                selected['nome'] ??
                                                '')
                                            .toString()
                                            .trim();
                                        return nome.isEmpty
                                            ? 'Nenhum selecionado'
                                            : nome;
                                      })(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: rdoFormFieldTextStyle(context),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: selecionarProfissional,
                                    icon: const Icon(
                                      Icons.arrow_drop_down_circle_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Selecionar profissional',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.primaryText,
                                      side: BorderSide(color: theme.alternate),
                                      minimumSize:
                                          const Size(double.infinity, 44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  cargoFuncaoFields(),
                                ],
                              ),
                            ),
                          if (_tipoVinculacao == 'novo_profissional')
                            RdoSectionCard(
                              title: 'Novo profissional',
                              icon: Icons.tune_outlined,
                              subtitle: 'Dados do cadastro',
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _novoNomeController,
                                    style: rdoFormFieldTextStyle(context),
                                    decoration:
                                        fieldDeco(label: 'Nome completo *'),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _novoCpfController,
                                          style: rdoFormFieldTextStyle(context),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          ],
                                          onChanged: (v) => _setMaskedValue(
                                            _novoCpfController,
                                            _formatCpf(v),
                                          ),
                                          decoration: fieldDeco(label: 'CPF'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _novoTelefoneController,
                                          style: rdoFormFieldTextStyle(context),
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          ],
                                          onChanged: (v) => _setMaskedValue(
                                            _novoTelefoneController,
                                            _formatTelefoneBr(v),
                                          ),
                                          decoration:
                                              fieldDeco(label: 'Telefone'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _novoEmailController,
                                    style: rdoFormFieldTextStyle(context),
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: fieldDeco(label: 'E-mail'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _novoDataAdmissaoController,
                                    style: rdoFormFieldTextStyle(context),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    onChanged: (v) => _setMaskedValue(
                                      _novoDataAdmissaoController,
                                      _formatDateBr(v),
                                    ),
                                    decoration: fieldDeco(
                                      label: 'Data de admissão',
                                      hint: 'dd/mm/aaaa',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  cargoFuncaoFields(),
                                ],
                              ),
                            ),
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

  Future<void> _cadastrarMaoObraApi({
    required String descricao,
    required VoidCallback closeModal,
  }) async {
    final obraIdentifier = _obraApiIdentifier();
    if (obraIdentifier == null) return;
    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'tipo_mao_obra': _tipoVinculacao,
        'descricao': descricao,
        'qtd': 0,
        'unidade': 'un',
        'valor_unitario': 0,
        'cargo_funcao': _cargoFuncaoController.text.trim().isEmpty
            ? descricao
            : _cargoFuncaoController.text.trim(),
      };

      if (_tipoVinculacao == 'profissional_existente') {
        payload['id_profissional'] = _asInt(_profissionalSelecionadoId);
      }

      if (_tipoVinculacao == 'novo_profissional') {
        payload['novo_profissional'] = {
          'nome_completo': _novoNomeController.text.trim(),
          'cpf': _novoCpfController.text.trim().isEmpty
              ? null
              : _novoCpfController.text.trim(),
          'telefone': _novoTelefoneController.text.trim().isEmpty
              ? null
              : _novoTelefoneController.text.trim(),
          'email': _novoEmailController.text.trim().isEmpty
              ? null
              : _novoEmailController.text.trim(),
          'valor_hora': 0,
          'valor_diaria': 0,
          'data_admissao': _novoDataAdmissaoController.text.trim().isEmpty
              ? null
              : (_toApiDateFromBr(_novoDataAdmissaoController.text.trim()) ??
                  _novoDataAdmissaoController.text.trim()),
        };
      }

      final metas = _metasController.toPayload();
      if (metas.isNotEmpty) {
        payload['metas'] = metas;
      }

      final response = await http.post(
        Uri.parse(
          '$kApiBaseUrl/api/obras/$obraIdentifier/itens/mao-obra',
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
            : 'Falha ao cadastrar mão de obra';
        throw Exception(msg);
      }

      closeModal();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('Mão de obra cadastrada e vinculada com sucesso!'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );

      // Mantém o cache local em dia para outras telas que ainda consultem SQLite.
      await actions.syncMaoObra();
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

  Future<void> _confirmarExcluirVinculo(Map<String, dynamic> item) async {
    if (!MembershipAccess.canPermission('delete_mao_obra')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para excluir mão de obra.',
      );
      return;
    }
    final itemIdentifier = _itemApiIdentifier(item);
    if (itemIdentifier == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível identificar o vínculo.')),
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
        title: const Text('Excluir vínculo'),
        content: Text(
          'Deseja excluir o vínculo "${(item['descricao'] ?? 'sem descrição').toString()}"?',
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
      await _excluirVinculo(itemIdentifier);
    }
  }

  Future<void> _excluirVinculo(String itemIdentifier) async {
    if (_deletingIds.contains(itemIdentifier)) return;
    setState(() => _deletingIds.add(itemIdentifier));
    try {
      final response = await http.delete(
        Uri.parse(
          '$kApiBaseUrl/api/obras/itens/$itemIdentifier',
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
            : 'Falha ao excluir vínculo';
        throw Exception(msg);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vínculo excluído com sucesso!'),
          backgroundColor: FlutterFlowTheme.of(context).success,
        ),
      );

      await actions.syncMaoObra();
      await actions.syncObrasItens();
      if (mounted) await _fetchRegistros(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir vínculo: $e')),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(itemIdentifier));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final canCreate = MembershipAccess.canPermission('create_mao_obra');

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
                  'Mão de obra',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _obraNome.isEmpty
                      ? 'Profissionais vinculados à obra'
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
                tooltip: 'Nova mão de obra',
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
                onPressed: _abrirCadastroMaoObra,
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
                        title: 'Incluir mão de obra',
                        icon: Icons.add_circle_outline_rounded,
                        subtitle:
                            'Função genérica, novo profissional ou cadastrado',
                        margin: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.icon(
                          onPressed: _abrirCadastroMaoObra,
                          icon: const Icon(Icons.engineering_rounded, size: 18),
                          label: Text(
                            'Nova mão de obra',
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
                      icon: Icons.groups_2_outlined,
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
                                        Icons.groups_2_outlined,
                                        size: 40,
                                        color: theme.secondaryText
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Nenhuma mão de obra na obra',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: theme.primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Cadastre mão de obra para vincular a esta obra.',
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
                                      _buildMaoObraListItem(
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

  String? _subtituloMaoObraItem(Map<String, dynamic> item) {
    final cargo = (item['cargo_funcao'] ?? '').toString().trim();
    if (cargo.isNotEmpty) return cargo;
    final tipo = _tipoMaoObraLabel(item['tipo_mao_obra']?.toString());
    if (tipo == 'Função') return null;
    return tipo;
  }

  Widget _buildMaoObraListItem(
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
    final canDelete = MembershipAccess.canPermission('delete_mao_obra');
    final podeExcluir = canDelete &&
        itemIdentifier != null &&
        !isDeleting &&
        !_isSaving &&
        !vinc;

    return ObraItemListTileWidget(
      titulo: (item['descricao'] ?? 'Sem descrição').toString(),
      subtitulo: _subtituloMaoObraItem(item),
      qtd: qtd,
      qtdRealizada: realizada,
      unidade: unidade,
      mostrarExcluir: canDelete,
      podeExcluir: podeExcluir,
      isDeleting: isDeleting,
      deleteTooltip: vinc
          ? 'Vinculado ao orçamento — não pode excluir'
          : 'Excluir vínculo',
      onExcluir: () => _confirmarExcluirVinculo(item),
    );
  }
}
