import 'dart:async';
import 'dart:convert';

import '/componentes/obra/obra_item_metas_fields_widget.dart';
import '/componentes/relatorios/includes/cadastro_obra_rede_guard.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

/// Abre cadastro de mão de obra vinculada à obra em dialog fullscreen.
/// Retorna o UUID do [obra_itens] criado, ou null se cancelado.
Future<String?> showCadastrarMaoObraObraDialog({
  required BuildContext context,
  required String obraUuid,
  int? obraId,
}) async {
  if (!await garantirInternetParaCadastroObra(context)) return null;
  if (!context.mounted) return null;
  return showDialog<String?>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (dialogContext) => CadastrarMaoObraObraDialogWidget(
      obraUuid: obraUuid,
      obraId: obraId,
    ),
  );
}

class CadastrarMaoObraObraDialogWidget extends StatefulWidget {
  const CadastrarMaoObraObraDialogWidget({
    super.key,
    required this.obraUuid,
    this.obraId,
  });

  final String obraUuid;
  final int? obraId;

  @override
  State<CadastrarMaoObraObraDialogWidget> createState() =>
      _CadastrarMaoObraObraDialogWidgetState();
}

class _CadastrarMaoObraObraDialogWidgetState
    extends State<CadastrarMaoObraObraDialogWidget> {
  bool _isSaving = false;
  bool _loadingData = true;
  String _tipoVinculacao = 'funcao_generica';
  String? _profissionalSelecionadoId;
  List<Map<String, dynamic>> _profissionais = <Map<String, dynamic>>[];
  List<String> _funcoesMaoObra = <String>[];

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
    unawaited(_loadInitialData());
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
    return '${m.group(3)!}-${m.group(2)!}-${m.group(1)!}';
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchProfissionais(force: true),
      _fetchFuncoesMaoObra(),
    ]);
    if (mounted) setState(() => _loadingData = false);
  }

  Future<String?> _fetchProfissionais({bool force = false}) async {
    if (!force && _profissionais.isNotEmpty) return null;
    try {
      final response = await http
          .get(
            Uri.parse('https://api.rdopro.com.br/api/mao-obra-profissionais'),
            headers: _apiHeaders(json: false),
          )
          .timeout(const Duration(seconds: 15));

      final dynamic body =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Falha ao carregar profissionais.';
      }

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

      if (mounted) setState(() => _profissionais = list);
      if (list.isEmpty) return 'Nenhum profissional cadastrado encontrado.';
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
        headers: _apiHeaders(json: false),
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
      if (mounted) {
        setState(() => _funcoesMaoObra = list.toSet().toList()..sort());
      }
    } catch (_) {}
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

  Future<void> _salvar() async {
    if (!await garantirInternetParaCadastroObra(context)) return;

    final obraIdentifier = _obraApiIdentifier();
    if (obraIdentifier == null) return;

    final desc = (_tipoVinculacao == 'profissional_existente')
        ? _descricaoController.text.trim()
        : (_tipoVinculacao == 'novo_profissional')
            ? _novoNomeController.text.trim()
            : _descricaoController.text.trim();

    if (desc.isEmpty) {
      _snack('Preencha a descrição ou nome.');
      return;
    }
    if (_tipoVinculacao == 'profissional_existente' &&
        (_profissionalSelecionadoId == null ||
            _profissionalSelecionadoId!.isEmpty)) {
      _snack('Selecione um profissional.');
      return;
    }
    if (_tipoVinculacao == 'novo_profissional' &&
        _novoNomeController.text.trim().isEmpty) {
      _snack('Informe o nome do novo profissional.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'tipo_mao_obra': _tipoVinculacao,
        'descricao': desc,
        'qtd': 0,
        'unidade': 'un',
        'valor_unitario': 0,
        'cargo_funcao': _cargoFuncaoController.text.trim().isEmpty
            ? desc
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
            : 'Falha ao cadastrar mão de obra';
        throw Exception(msg);
      }

      await actions.syncMaoObra();
      await actions.syncObrasItens();

      if (!mounted) return;
      final itemUuid = _extractItemUuid(body);
      Navigator.pop(context, itemUuid);
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

  Widget _buildTipoMaoObraTabs(FlutterFlowTheme theme) {
    Widget tab(String value, String label, IconData icon) {
      final selected = _tipoVinculacao == value;
      return Expanded(
        child: Material(
          color: selected ? theme.secondaryBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          elevation: selected ? 1 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          child: InkWell(
            onTap: () => setState(() => _tipoVinculacao = value),
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

  String _hintTipo() {
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

  Future<void> _selecionarProfissional() async {
    FocusScope.of(context).unfocus();
    final loadError = await _fetchProfissionais(force: true);
    if (loadError != null) {
      if (!mounted) return;
      _snack(loadError);
      return;
    }
    if (!mounted) return;
    final selectedId = await showDialog<String>(
      context: context,
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
              final nome =
                  (p['nome_completo'] ?? p['nome'] ?? 'Sem nome').toString();
              final funcao = (p['cargo_funcao'] ?? '').toString();
              return ListTile(
                dense: true,
                leading: const Icon(Icons.person_outline),
                title: Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: funcao.trim().isEmpty
                    ? null
                    : Text(funcao, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    setState(() => _profissionalSelecionadoId = selectedId);
    final selected = _profissionais.firstWhere(
      (e) => e['id']?.toString() == selectedId,
      orElse: () => <String, dynamic>{},
    );
    _descricaoController.text =
        (selected['nome_completo'] ?? selected['nome'] ?? '').toString();
    _cargoFuncaoController.text =
        (selected['cargo_funcao'] ?? '').toString();
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
            'Nova mão de obra na obra',
            style: theme.titleLarge.override(
              font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
            ),
          ),
          centerTitle: false,
        ),
        body: _loadingData
            ? Center(
                child: CircularProgressIndicator(color: theme.primary),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cadastre e vincule à obra sem sair do relatório.',
                            style: theme.bodySmall.override(
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTipoMaoObraTabs(theme),
                          const SizedBox(height: 8),
                          Text(
                            _hintTipo(),
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
                                  'Dados da mão de obra',
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
                                    decoration: _fieldDeco(theme,
                                        label: 'Profissional *',
                                        hint: 'Selecione',
                                        icon: Icons.person_search_outlined),
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
                                      style: theme.bodyMedium,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  FFButtonWidget(
                                    onPressed:
                                        _isSaving ? null : _selecionarProfissional,
                                    text: 'Selecionar profissional',
                                    icon: const Icon(
                                      Icons.arrow_drop_down_circle_outlined,
                                      size: 18,
                                    ),
                                    options: FFButtonOptions(
                                      height: 44,
                                      color: theme.primaryBackground,
                                      textStyle: theme.labelLarge,
                                      borderSide:
                                          BorderSide(color: theme.alternate),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ],
                                if (_tipoVinculacao == 'novo_profissional') ...[
                                  TextFormField(
                                    controller: _novoNomeController,
                                    decoration: _fieldDeco(theme,
                                        label: 'Nome completo *',
                                        icon: Icons.person_outline),
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
                                                .digitsOnly,
                                          ],
                                          onChanged: (v) => _setMaskedValue(
                                            _novoCpfController,
                                            _formatCpf(v),
                                          ),
                                          decoration: _fieldDeco(theme,
                                              label: 'CPF',
                                              icon: Icons.badge_outlined),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _novoTelefoneController,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          onChanged: (v) => _setMaskedValue(
                                            _novoTelefoneController,
                                            _formatTelefoneBr(v),
                                          ),
                                          decoration: _fieldDeco(theme,
                                              label: 'Telefone',
                                              icon: Icons.phone_outlined),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _novoEmailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _fieldDeco(theme,
                                        label: 'E-mail',
                                        icon: Icons.email_outlined),
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _novoDataAdmissaoController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (v) => _setMaskedValue(
                                      _novoDataAdmissaoController,
                                      _formatDateBr(v),
                                    ),
                                    decoration: _fieldDeco(theme,
                                        label: 'Data de admissão',
                                        hint: 'dd/mm/aaaa',
                                        icon: Icons.calendar_today_outlined),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (_tipoVinculacao == 'novo_profissional' &&
                                    _funcoesMaoObra.isNotEmpty) ...[
                                  DropdownButtonFormField<String>(
                                    initialValue: _funcoesMaoObra.contains(
                                            _cargoFuncaoController.text.trim())
                                        ? _cargoFuncaoController.text.trim()
                                        : null,
                                    decoration: _fieldDeco(theme,
                                        label: 'Cargo / função *',
                                        hint: 'Selecione uma função',
                                        icon: Icons.work_outline_rounded),
                                    items: _funcoesMaoObra
                                        .map(
                                          (f) => DropdownMenuItem<String>(
                                            value: f,
                                            child: Text(f,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v == null || v.isEmpty) return;
                                      setState(
                                          () => _cargoFuncaoController.text = v);
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _cargoFuncaoController,
                                    decoration: _fieldDeco(theme,
                                        label: 'Cargo / função (manual)',
                                        hint:
                                            'Se preferir, ajuste ou digite outro cargo',
                                        icon: Icons.edit_outlined),
                                  ),
                                ] else ...[
                                  TextFormField(
                                    controller: _cargoFuncaoController,
                                    decoration: _fieldDeco(theme,
                                        label: 'Cargo / função',
                                        hint: 'Ex.: Pedreiro, Mestre de obras',
                                        icon: Icons.work_outline_rounded),
                                  ),
                                ],
                                if (_funcoesMaoObra.isNotEmpty &&
                                    _tipoVinculacao != 'novo_profissional') ...[
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    initialValue: _funcoesMaoObra.contains(
                                            _cargoFuncaoController.text.trim())
                                        ? _cargoFuncaoController.text.trim()
                                        : null,
                                    decoration: _fieldDeco(theme,
                                        label: 'Função predefinida',
                                        hint: 'Selecionar',
                                        icon: Icons.badge_outlined),
                                    items: _funcoesMaoObra
                                        .map(
                                          (f) => DropdownMenuItem<String>(
                                            value: f,
                                            child: Text(f),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v == null || v.isEmpty) return;
                                      setState(
                                          () => _cargoFuncaoController.text = v);
                                    },
                                  ),
                                ],
                                if (_tipoVinculacao == 'funcao_generica') ...[
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _descricaoController,
                                    maxLines: 2,
                                    decoration: _fieldDeco(theme,
                                        label: 'Descrição *',
                                        hint:
                                            'Ex.: Pedreiro para alvenaria, ajudante geral',
                                        icon: Icons.notes_outlined),
                                  ),
                                ],
                              ],
                            ),
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
