import 'dart:async';

import '/componentes/obra/obra_item_metas_fields_widget.dart';
import '/componentes/relatorios/includes/cadastro_obra_rede_guard.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

Future<String?> showCadastrarEquipamentoObraDialog({
  required BuildContext context,
  required String obraUuid,
  int? obraId,
}) {
  return showDialog<String?>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (dialogContext) => CadastrarEquipamentoObraDialogWidget(
      obraUuid: obraUuid,
      obraId: obraId,
    ),
  );
}

class CadastrarEquipamentoObraDialogWidget extends StatefulWidget {
  const CadastrarEquipamentoObraDialogWidget({
    super.key,
    required this.obraUuid,
    this.obraId,
  });

  final String obraUuid;
  final int? obraId;

  @override
  State<CadastrarEquipamentoObraDialogWidget> createState() =>
      _CadastrarEquipamentoObraDialogWidgetState();
}

class _CadastrarEquipamentoObraDialogWidgetState
    extends State<CadastrarEquipamentoObraDialogWidget> {
  bool _isSaving = false;
  bool _loadingData = true;
  String _tipoEquipamento = 'avulso';
  String? _equipamentoSelecionadoId;
  List<Map<String, dynamic>> _equipamentosCatalogo = <Map<String, dynamic>>[];

  static const List<DropdownMenuItem<String>> _unidadeObraItems = [
    DropdownMenuItem(value: 'h', child: Text('Hora (h)')),
    DropdownMenuItem(value: 'dia', child: Text('Dia')),
    DropdownMenuItem(value: 'mes', child: Text('Mês')),
    DropdownMenuItem(value: 'un', child: Text('Unidade')),
  ];

  final TextEditingController _descricaoAvulsoController =
      TextEditingController();
  String _unidadeObra = 'h';
  final TextEditingController _novoNomeController = TextEditingController();
  final TextEditingController _novoCodigoController = TextEditingController();
  final TextEditingController _novoCategoriaController =
      TextEditingController();
  String _novoUnidadeMedida = 'h';
  final TextEditingController _novoMarcaController = TextEditingController();
  final TextEditingController _novoModeloController = TextEditingController();
  final TextEditingController _novoPlacaController = TextEditingController();
  final TextEditingController _novoSerieController = TextEditingController();
  final TextEditingController _novoDescricaoController =
      TextEditingController();
  final ObraItemMetasController _metasController = ObraItemMetasController();

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitialData());
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
    super.dispose();
  }

  Map<String, String> _apiHeaders({bool json = true}) {
    final headers = <String, String>{
      'Authorization': 'Bearer ${FFAppState().UserToken}',
      'Accept': 'application/json',
    };
    if (json) headers['Content-Type'] = 'application/json';
    final tenantId = FFAppState().activeTenantUserId;
    if (tenantId > 0) {
      headers['X-Tenant-User-Id'] = tenantId.toString();
    }
    return headers;
  }

  String? _obraApiIdentifier() {
    final uuid = widget.obraUuid.trim();
    if (uuid.isNotEmpty) return uuid;
    final id = widget.obraId;
    if (id != null && id > 0) return id.toString();
    return null;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _extractList(dynamic body) {
    if (body is List) {
      return body
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (body is Map) {
      for (final key in ['data', 'value', 'itens']) {
        final c = body[key];
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

  String? _extractItemUuid(dynamic body) {
    if (body is! Map) return null;
    final data = body['data'];
    if (data is Map) {
      final item = data['item'];
      if (item is Map && item['uuid'] != null) {
        return item['uuid'].toString();
      }
      if (data['uuid'] != null) return data['uuid'].toString();
    }
    return null;
  }

  Future<void> _loadInitialData() async {
    await _fetchEquipamentosCatalogo();
    if (mounted) setState(() => _loadingData = false);
  }

  Future<void> _fetchEquipamentosCatalogo() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.rdopro.com.br/api/equipamentos'),
        headers: _apiHeaders(json: false),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final dynamic body =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (mounted) {
        setState(() => _equipamentosCatalogo = _extractList(body));
      }
    } catch (_) {}
  }

  Future<void> _salvar() async {
    if (!await garantirInternetParaCadastroObra(context)) return;

    final obraIdentifier = _obraApiIdentifier();
    if (obraIdentifier == null) return;

    final desc = _descricaoParaApi();
    if (desc.isEmpty) {
      _snack('Preencha a descrição ou selecione o equipamento.');
      return;
    }
    if (_tipoEquipamento == 'equipamento_existente' &&
        (_equipamentoSelecionadoId == null ||
            _equipamentoSelecionadoId!.isEmpty)) {
      _snack('Selecione um equipamento.');
      return;
    }
    if (_tipoEquipamento == 'novo_equipamento' &&
        _novoNomeController.text.trim().isEmpty) {
      _snack('Informe o nome do equipamento.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'tipo_equipamento': _tipoEquipamento,
        'descricao': desc,
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
          'https://api.rdopro.com.br/api/obras/$obraIdentifier/itens/equipamento',
        ),
        headers: _apiHeaders(),
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

      await actions.syncEquipamentos();
      await actions.syncObrasItens();

      if (!mounted) return;
      Navigator.pop(context, _extractItemUuid(body));
    } catch (e) {
      if (!mounted) return;
      _snack('Erro ao cadastrar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _fieldDeco(
    FlutterFlowTheme theme, {
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
      prefixIcon:
          icon != null ? Icon(icon, size: 20, color: theme.secondaryText) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.alternate),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.alternate),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primary, width: 1.5),
      ),
      labelStyle: theme.labelMedium,
      hintStyle: theme.labelMedium.override(color: theme.secondaryText),
    );
  }

  Widget _buildTipoEquipamentoTabs(FlutterFlowTheme theme) {
    Widget tab(String value, String label, IconData icon) {
      final selected = _tipoEquipamento == value;
      return Expanded(
        child: Material(
          color: selected ? theme.secondaryBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          elevation: selected ? 1 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          child: InkWell(
            onTap: () => setState(() => _tipoEquipamento = value),
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
          tab('avulso', 'Avulso', Icons.handyman_outlined),
          tab('novo_equipamento', 'Personalizado', Icons.tune_outlined),
          tab(
            'equipamento_existente',
            'Cadastrado',
            Icons.build_circle_outlined,
          ),
        ],
      ),
    );
  }

  String _hintTipo() {
    switch (_tipoEquipamento) {
      case 'equipamento_existente':
        return 'Vincular a um equipamento já cadastrado no sistema.';
      case 'novo_equipamento':
        return 'Criar um novo equipamento e vincular à obra.';
      case 'avulso':
      default:
        return 'Apenas descrição na obra, sem cadastro no catálogo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: theme.secondaryBackground,
        appBar: AppBar(
          backgroundColor: theme.secondaryBackground,
          elevation: 0,
          leading: IconButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: theme.primaryText),
            tooltip: 'Fechar',
          ),
          title: Text(
            'Novo equipamento na obra',
            style: theme.titleLarge.override(
              font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        body: _loadingData
            ? Center(child: CircularProgressIndicator(color: theme.primary))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cadastre na obra e vincule à atividade.',
                            style: theme.bodySmall.override(
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTipoEquipamentoTabs(theme),
                          const SizedBox(height: 8),
                          Text(
                            _hintTipo(),
                            style: theme.labelSmall.override(
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_tipoEquipamento == 'equipamento_existente') ...[
                            DropdownButtonFormField<String>(
                              initialValue: _equipamentoSelecionadoId,
                              decoration: _fieldDeco(theme,
                                  label: 'Equipamento *',
                                  icon: Icons.search),
                              items: _equipamentosCatalogo
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
                                setState(() {
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
                          ],
                          if (_tipoEquipamento == 'novo_equipamento') ...[
                            TextFormField(
                              controller: _novoNomeController,
                              decoration: _fieldDeco(theme,
                                  label: 'Nome *',
                                  icon: Icons.precision_manufacturing_outlined),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _novoCodigoController,
                                    decoration: _fieldDeco(theme,
                                        label: 'Código', icon: Icons.tag),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _novoCategoriaController,
                                    decoration: _fieldDeco(theme,
                                        label: 'Categoria',
                                        icon: Icons.category_outlined),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _novoMarcaController,
                                    decoration: _fieldDeco(theme,
                                        label: 'Marca',
                                        icon: Icons.business_outlined),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _novoModeloController,
                                    decoration: _fieldDeco(theme,
                                        label: 'Modelo',
                                        icon: Icons.settings_outlined),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _novoPlacaController,
                                    decoration: _fieldDeco(theme,
                                        label: 'Placa / ID',
                                        icon: Icons.pin_outlined),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _novoSerieController,
                                    decoration: _fieldDeco(theme,
                                        label: 'Nº série',
                                        icon: Icons.numbers),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _novoUnidadeMedida,
                              decoration: _fieldDeco(theme,
                                  label: 'Unidade (catálogo)',
                                  icon: Icons.straighten),
                              items: _unidadeObraItems,
                              onChanged: (v) => setState(
                                () => _novoUnidadeMedida = v ?? 'h',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _novoDescricaoController,
                              maxLines: 2,
                              decoration: _fieldDeco(theme,
                                  label: 'Observações',
                                  icon: Icons.notes_outlined),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_tipoEquipamento == 'avulso') ...[
                            TextFormField(
                              controller: _descricaoAvulsoController,
                              maxLines: 2,
                              decoration: _fieldDeco(theme,
                                  label: 'Descrição *',
                                  hint: 'Ex.: Betoneira 400 L',
                                  icon: Icons.description_outlined),
                            ),
                            const SizedBox(height: 12),
                          ],
                          DropdownButtonFormField<String>(
                            initialValue: _unidadeObra,
                            decoration: _fieldDeco(theme,
                                label: 'Unidade *', icon: Icons.straighten),
                            items: _unidadeObraItems,
                            onChanged: (v) =>
                                setState(() => _unidadeObra = v ?? 'h'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: ObraItemMetasFieldsWidget(
                      obraId: _obraApiIdentifier(),
                      controller: _metasController,
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: FFButtonWidget(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.pop(context),
                              text: 'Cancelar',
                              options: FFButtonOptions(
                                height: 48,
                                color: theme.secondaryBackground,
                                borderSide:
                                    BorderSide(color: theme.alternate),
                                borderRadius: BorderRadius.circular(12),
                                textStyle: theme.titleSmall,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FFButtonWidget(
                              onPressed: _isSaving ? null : _salvar,
                              text: _isSaving ? 'Salvando...' : 'Salvar',
                              icon: _isSaving
                                  ? null
                                  : Icon(Icons.check_rounded,
                                      size: 18, color: theme.info),
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
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
