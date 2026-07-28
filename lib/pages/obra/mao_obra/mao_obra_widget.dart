import 'dart:async';

import '/auth/membership_access.dart';
import '/backend/sqlite/situacao_soft_delete.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/obra/obra_item_list_tile_widget.dart';
import '/componentes/obra/obra_item_metas_fields_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _fetchRegistros(silent: false));
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
    if (digits.length <= 4)
      return '${digits.substring(0, 2)}/${digits.substring(2)}';
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
          'https://api.rdopro.com.br/api/obras/$obraIdentifier/itens?tipo=mao_obra',
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
        Uri.parse('https://api.rdopro.com.br/api/mao-obra-profissionais'),
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
        Uri.parse('https://api.rdopro.com.br/api/funcoes-mao-obra'),
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
    Widget tab(String value, String label, IconData icon) {
      final selected = _tipoVinculacao == value;
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
          tab('funcao_generica', 'Função', Icons.badge_outlined),
          tab('novo_profissional', 'Personalizado', Icons.tune_outlined),
          tab(
            'profissional_existente',
            'Cadastrado',
            Icons.how_to_reg_outlined,
          ),
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
                              Icons.engineering_rounded,
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
                                  'Nova mão de obra',
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
                            _buildTipoMaoObraTabs(
                              theme,
                              (v) =>
                                  setModalState(() => _tipoVinculacao = v),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hintTipo(),
                              style: theme.labelSmall.override(
                                color: theme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 16),
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
                                    'Dados da obra',
                                    style: theme.titleSmall.override(
                                      font: GoogleFonts.interTight(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color: theme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_tipoVinculacao ==
                                      'profissional_existente') ...[
                                    InputDecorator(
                                      decoration: fieldDeco(
                                        label: 'Profissional *',
                                        hint: 'Selecione',
                                        icon: Icons.person_search_outlined,
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
                                          final nome =
                                              (selected['nome_completo'] ??
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
                                        style: theme.bodyMedium,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    FFButtonWidget(
                                      onPressed: () async {
                                        FocusScope.of(sheetContext).unfocus();
                                        final rootNav = Navigator.of(
                                            sheetContext,
                                            rootNavigator: true);
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
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Carregando profissionais...',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        final loadError =
                                            await _fetchProfissionais(
                                                force: true);
                                        if (rootNav.canPop()) {
                                          rootNav.pop();
                                        }
                                        if (loadError != null) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(sheetContext)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(loadError),
                                            ),
                                          );
                                          return;
                                        }
                                        final selectedId =
                                            await showDialog<String>(
                                          context: sheetContext,
                                          builder: (dialogContext) =>
                                              AlertDialog(
                                            title: const Text(
                                              'Vincular a profissional cadastrado',
                                            ),
                                            content: SizedBox(
                                              width: 420,
                                              height: 360,
                                              child: ListView.separated(
                                                itemCount:
                                                    _profissionais.length,
                                                separatorBuilder: (_, __) =>
                                                    const Divider(height: 1),
                                                itemBuilder: (_, idx) {
                                                  final p = _profissionais[idx];
                                                  final id =
                                                      p['id']?.toString();
                                                  final nome =
                                                      (p['nome_completo'] ??
                                                              p['nome'] ??
                                                              'Sem nome')
                                                          .toString();
                                                  final funcao =
                                                      (p['cargo_funcao'] ?? '')
                                                          .toString();
                                                  return ListTile(
                                                    dense: true,
                                                    leading: const Icon(
                                                        Icons.person_outline),
                                                    title: Text(
                                                      nome,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    subtitle:
                                                        funcao.trim().isEmpty
                                                            ? null
                                                            : Text(
                                                                funcao,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                    onTap: id == null
                                                        ? null
                                                        : () => Navigator.pop(
                                                              dialogContext,
                                                              id,
                                                            ),
                                                  );
                                                },
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    dialogContext),
                                                child: const Text('Fechar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (selectedId == null || !mounted)
                                          return;
                                        setModalState(() =>
                                            _profissionalSelecionadoId =
                                                selectedId);
                                        final selected =
                                            _profissionais.firstWhere(
                                          (e) =>
                                              e['id']?.toString() == selectedId,
                                          orElse: () => <String, dynamic>{},
                                        );
                                        _descricaoController.text =
                                            (selected['nome_completo'] ?? '')
                                                .toString();
                                        _cargoFuncaoController.text =
                                            (selected['cargo_funcao'] ?? '')
                                                .toString();
                                      },
                                      text: 'Selecionar profissional',
                                      icon: const Icon(
                                        Icons.arrow_drop_down_circle_outlined,
                                        size: 18,
                                      ),
                                      options: FFButtonOptions(
                                        height: 44,
                                        color: theme.primaryBackground,
                                        textStyle: theme.labelLarge,
                                        borderSide: BorderSide(
                                          color: theme.alternate,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ],
                                  if (_tipoVinculacao ==
                                      'novo_profissional') ...[
                                    Text(
                                      'Novo profissional',
                                      style: theme.labelLarge.override(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _novoNomeController,
                                      decoration: fieldDeco(
                                        label: 'Nome completo *',
                                        icon: Icons.person_outline,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _novoCpfController,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly
                                            ],
                                            onChanged: (v) => _setMaskedValue(
                                              _novoCpfController,
                                              _formatCpf(v),
                                            ),
                                            decoration: fieldDeco(
                                              label: 'CPF',
                                              icon: Icons.badge_outlined,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _novoTelefoneController,
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly
                                            ],
                                            onChanged: (v) => _setMaskedValue(
                                              _novoTelefoneController,
                                              _formatTelefoneBr(v),
                                            ),
                                            decoration: fieldDeco(
                                              label: 'Telefone',
                                              icon: Icons.phone_outlined,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _novoEmailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: fieldDeco(
                                        label: 'E-mail',
                                        icon: Icons.email_outlined,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _novoDataAdmissaoController,
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
                                        icon: Icons.calendar_today_outlined,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  if (_tipoVinculacao == 'novo_profissional' &&
                                      _funcoesMaoObra.isNotEmpty) ...[
                                    DropdownButtonFormField<String>(
                                      initialValue: _funcoesMaoObra.contains(
                                              _cargoFuncaoController.text
                                                  .trim())
                                          ? _cargoFuncaoController.text.trim()
                                          : null,
                                      decoration: fieldDeco(
                                        label: 'Cargo / função *',
                                        hint: 'Selecione uma função',
                                        icon: Icons.work_outline_rounded,
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
                                        _cargoFuncaoController.text = v;
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _cargoFuncaoController,
                                      decoration: fieldDeco(
                                        label: 'Cargo / função (manual)',
                                        hint:
                                            'Se preferir, ajuste ou digite outro cargo',
                                        icon: Icons.edit_outlined,
                                      ),
                                    ),
                                  ] else ...[
                                    TextFormField(
                                      controller: _cargoFuncaoController,
                                      decoration: fieldDeco(
                                        label: 'Cargo / função',
                                        hint: 'Ex.: Pedreiro, Mestre de obras',
                                        icon: Icons.work_outline_rounded,
                                      ),
                                    ),
                                  ],
                                  if (_funcoesMaoObra.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      initialValue: _funcoesMaoObra.contains(
                                              _cargoFuncaoController.text
                                                  .trim())
                                          ? _cargoFuncaoController.text.trim()
                                          : null,
                                      decoration: fieldDeco(
                                        label: 'Função predefinida',
                                        hint: 'Selecionar',
                                        icon: Icons.badge_outlined,
                                      ),
                                      items: _funcoesMaoObra
                                          .map(
                                            (f) => DropdownMenuItem<String>(
                                              value: f,
                                              child: Text(f),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (_tipoVinculacao ==
                                              'novo_profissional')
                                          ? null
                                          : (v) {
                                              if (v == null || v.isEmpty)
                                                return;
                                              _cargoFuncaoController.text = v;
                                            },
                                    ),
                                  ],
                                  if (_tipoVinculacao == 'funcao_generica') ...[
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: _descricaoController,
                                      maxLines: 2,
                                      decoration: fieldDeco(
                                        label: 'Descrição *',
                                        hint:
                                            'Ex.: Pedreiro para alvenaria, ajudante geral',
                                        icon: Icons.notes_outlined,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
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
                                            final desc = (_tipoVinculacao ==
                                                'profissional_existente')
                                                ? _descricaoController.text
                                                    .trim()
                                                : (_tipoVinculacao ==
                                                        'novo_profissional')
                                                    ? _novoNomeController.text
                                                        .trim()
                                                    : _descricaoController.text
                                                        .trim();
                                            if (desc.isEmpty) {
                                              ScaffoldMessenger.of(sheetContext)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Preencha a descrição ou nome.'),
                                                ),
                                              );
                                              return;
                                            }
                                            if (_tipoVinculacao ==
                                                    'profissional_existente' &&
                                                (_profissionalSelecionadoId ==
                                                        null ||
                                                    _profissionalSelecionadoId!
                                                        .isEmpty)) {
                                              ScaffoldMessenger.of(sheetContext)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Selecione um profissional.'),
                                                ),
                                              );
                                              return;
                                            }
                                            if (_tipoVinculacao ==
                                                    'novo_profissional' &&
                                                _novoNomeController.text
                                                    .trim()
                                                    .isEmpty) {
                                              ScaffoldMessenger.of(sheetContext)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Informe o nome do novo profissional.'),
                                                ),
                                              );
                                              return;
                                            }
                                            await _cadastrarMaoObraApi(
                                              descricao: desc,
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
          'https://api.rdopro.com.br/api/obras/$obraIdentifier/itens/mao-obra',
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
          'https://api.rdopro.com.br/api/obras/itens/$itemIdentifier',
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
          leading: FlutterFlowIconButton(
            borderColor: FlutterFlowTheme.of(context).alternate,
            borderRadius: 12.0,
            borderWidth: 1.0,
            buttonSize: 40.0,
            fillColor: FlutterFlowTheme.of(context).secondaryBackground,
            icon: Icon(
              Icons.arrow_back_ios,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 20.0,
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
            'Mão de obra',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_registros.length} ${_registros.length == 1 ? 'vínculo encontrado' : 'vínculos encontrados'}',
                              style: FlutterFlowTheme.of(context).labelMedium,
                            ),
                          ),
                          if (_isRefreshingSilently)
                            SizedBox(
                              width: 18,
                              height: 18,
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
                      buttonSize: 38,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                      onPressed: (_isLoading || _isRefreshingSilently)
                          ? null
                          : () => _fetchRegistros(silent: true),
                    ),
                    const SizedBox(width: 8),
                    if (MembershipAccess.canPermission('create_mao_obra'))
                      FFButtonWidget(
                        onPressed: _abrirCadastroMaoObra,
                        text: 'Adicionar',
                        icon: const Icon(Icons.person_add_alt_1, size: 16),
                        options: FFButtonOptions(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                      EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
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
                                    Icons.groups_2_outlined,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Nenhuma mão de obra vinculada',
                                    style: FlutterFlowTheme.of(context)
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Use o botão Adicionar para cadastrar e vincular.',
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
                                return _buildMaoObraListItem(
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
      marginBottom: 5,
      deleteTooltip: vinc
          ? 'Vinculado ao orçamento — não pode excluir'
          : 'Excluir vínculo',
      onExcluir: () => _confirmarExcluirVinculo(item),
    );
  }
}
