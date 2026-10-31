import 'dart:convert';
import 'dart:io';

import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/forms/avaliativo_emojis_checklist/avaliativo_emojis_checklist_widget.dart';
import '/componentes/forms/avaliativo_sim_nao_checklist/avaliativo_sim_nao_checklist_widget.dart';
import '/componentes/forms/campo_cadastro_checklist/campo_cadastro_checklist_widget.dart';
import '/componentes/forms/campo_data_checklist/campo_data_checklist_widget.dart';
import '/componentes/forms/campo_numero_int_checklist/campo_numero_int_checklist_widget.dart';
import '/componentes/forms/campo_texto_checklist/campo_texto_checklist_widget.dart';
import '/componentes/forms/dropdown_opcoes_checklist/dropdown_opcoes_checklist_widget.dart';
import '/custom_code/actions/checklist_complementos.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'checklist_respondendo_model.dart';
export 'checklist_respondendo_model.dart';

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
  bool _finalizando = false;

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

  Map<String, dynamic> _progresso() {
    try {
      final raw =
          actions.calcularProgressoChecklist(FFAppState().checklistAtualJson);
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {
      'total_itens': 0,
      'itens_respondidos': 0,
      'progresso_total': 0,
      'pode_finalizar': false,
    };
  }

  String _tipoItem(dynamic item) {
    final raw = getJsonField(item, r"$['type']");
    switch ((raw ?? '').toString().trim().toLowerCase()) {
      case 'texto longo':
      case 'texto':
        return 'Texto';
      case 'opções':
      case 'opcoes':
      case 'opção':
      case 'opcao':
        return 'Opção';
      case 'avaliativo sim/não':
      case 'avaliativo sim/nao':
      case 'sim/não':
      case 'sim/nao':
        return 'Avaliativo Sim/Não';
      case 'avaliativo emojis':
      case 'emojis':
        return 'Avaliativo Emojis';
      case 'número':
      case 'numero':
        return 'Número';
      case 'data':
        return 'Data';
      case 'cadastro':
        return 'Cadastro';
      case 'anexo':
      case 'arquivo':
        return 'Anexo';
      default:
        return (raw ?? 'Texto').toString();
    }
  }

  bool get _somenteLeitura {
    final dados =
        functions.getDadosFromChecklist(FFAppState().checklistAtualJson);
    final status = (dados is Map ? dados['status'] : null)?.toString() ?? '';
    return status == 'respondido' || status == 'concluido';
  }

  Future<void> _mostrarComentario(dynamic areaId, dynamic itemId,
      String comentarioAtual) async {
    final controller = TextEditingController(text: comentarioAtual);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Comentário'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Comentário do item',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await actions.salvarComentarioItemChecklist(
        FFAppState().checklistAtualJson,
        areaId.toString(),
        itemId.toString(),
        controller.text,
      );
      if (mounted) safeSetState(() {});
    }
    controller.dispose();
  }

  Future<void> _mostrarPlanoAcao(
    dynamic areaId,
    dynamic itemId,
    Map? planoAtual,
  ) async {
    final descCtrl = TextEditingController(
      text: (planoAtual?['descricao'] ?? '').toString(),
    );
    final prazoCtrl = TextEditingController(
      text: (planoAtual?['prazo'] ?? '').toString(),
    );
    final respCtrl = TextEditingController(
      text: (planoAtual?['responsavel_nome'] ??
              planoAtual?['responsavel'] ??
              '')
          .toString(),
    );
    var prioridade = (planoAtual?['prioridade'] ?? 'media').toString();
    var anexosPlano = checklistListaAnexos(planoAtual?['anexos']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Plano de ação'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: respCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Responsável',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: prazoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Prazo (AAAA-MM-DD)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: ['baixa', 'media', 'alta'].contains(prioridade)
                      ? prioridade
                      : 'media',
                  decoration: const InputDecoration(
                    labelText: 'Prioridade',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'baixa', child: Text('Baixa')),
                    DropdownMenuItem(value: 'media', child: Text('Média')),
                    DropdownMenuItem(value: 'alta', child: Text('Alta')),
                  ],
                  onChanged: (v) => setLocal(() => prioridade = v ?? 'media'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final path =
                        await actions.pickChecklistAnexoLocal(context: ctx);
                    if (path == null || path.isEmpty) return;
                    setLocal(() {
                      anexosPlano = [
                        ...anexosPlano,
                        checklistAnexoFromLocalPath(path),
                      ];
                    });
                  },
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Anexar foto ou arquivo'),
                ),
                if (anexosPlano.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...List.generate(anexosPlano.length, (i) {
                    final a = anexosPlano[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file, size: 20),
                      title: Text(
                        checklistNomeAnexo(a),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setLocal(() {
                          anexosPlano = [...anexosPlano]..removeAt(i);
                        }),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (descCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Informe a descrição do plano de ação.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await actions.salvarPlanoAcaoItemChecklist(
        FFAppState().checklistAtualJson,
        areaId.toString(),
        itemId.toString(),
        descCtrl.text,
        prazoCtrl.text,
        prioridade,
        null,
        respCtrl.text,
        anexos: anexosPlano,
      );
      if (mounted) safeSetState(() {});
    }
    descCtrl.dispose();
    prazoCtrl.dispose();
    respCtrl.dispose();
  }

  Future<void> _mostrarAnexos({
    required dynamic areaId,
    required dynamic itemId,
    required List<Map<String, dynamic>> anexosAtuais,
    required bool complementar,
    String titulo = 'Anexos',
  }) async {
    var anexos = [...anexosAtuais];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(titulo),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (anexos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Nenhum arquivo anexado.'),
                    ),
                  ...List.generate(anexos.length, (i) {
                    final a = anexos[i];
                    final path = checklistPathAnexo(a);
                    final isImage = path.toLowerCase().endsWith('.jpg') ||
                        path.toLowerCase().endsWith('.jpeg') ||
                        path.toLowerCase().endsWith('.png');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: isImage && File(path).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.file(
                                  File(path),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.insert_drive_file),
                                ),
                              )
                            : const Icon(Icons.insert_drive_file),
                        title: Text(
                          checklistNomeAnexo(a),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _somenteLeitura
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => setLocal(() {
                                  anexos = [...anexos]..removeAt(i);
                                }),
                              ),
                      ),
                    );
                  }),
                  if (!_somenteLeitura)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final path =
                            await actions.pickChecklistAnexoLocal(context: ctx);
                        if (path == null || path.isEmpty) return;
                        setLocal(() {
                          anexos = [
                            ...anexos,
                            checklistAnexoFromLocalPath(path),
                          ];
                        });
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Adicionar foto ou arquivo'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_somenteLeitura ? 'Fechar' : 'Cancelar'),
            ),
            if (!_somenteLeitura)
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salvar'),
              ),
          ],
        ),
      ),
    );

    if (ok == true && !_somenteLeitura) {
      if (complementar) {
        await actions.salvarAnexosComplementaresItemChecklist(
          FFAppState().checklistAtualJson,
          areaId.toString(),
          itemId.toString(),
          anexos,
        );
      } else {
        await actions.salvarAnexosRespostaItemChecklist(
          FFAppState().checklistAtualJson,
          areaId.toString(),
          itemId.toString(),
          anexos,
        );
      }
      if (mounted) safeSetState(() {});
    }
  }

  bool _templateExigeComentarioGeral() {
    try {
      final envelope = json.decode(FFAppState().checklistAtualJson);
      if (envelope is! Map) return false;
      final template = envelope['template_data'] ?? envelope['json_respostas'];
      if (template is! Map) return false;
      final cfg = template['configuracoes'] ?? template['config'];
      if (cfg is! Map) return false;
      final preench = cfg['preenchimentos'] ?? cfg;
      if (preench is! Map) return false;
      final v = preench['comentarioGeral'] ?? preench['comentario_geral'];
      return v == true || v == 1 || v == '1' || v == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<String?> _pedirComentarioGeral({required bool obrigatorio}) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: !obrigatorio,
      builder: (ctx) => AlertDialog(
        title: Text(obrigatorio
            ? 'Comentário geral (obrigatório)'
            : 'Comentário geral'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Observações finais do checklist',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (!obrigatorio)
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pular'),
            ),
          TextButton(
            onPressed: () {
              if (obrigatorio && controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Informe o comentário geral para finalizar.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (ok != true) return null;
    if (obrigatorio && text.isEmpty) return null;
    return text;
  }

  Future<int?> _idServidorChecklistAtual() async {
    try {
      final envelope = json.decode(FFAppState().checklistAtualJson);
      if (envelope is! Map) return null;
      final uuid = (envelope['uuid'] ?? '').toString().trim();
      if (uuid.isEmpty) return null;
      final db = await SQLiteManager.instance.database;
      final rows = await db.query(
        'sync_id_mapping',
        columns: ['id_servidor'],
        where: 'tabela = ? AND uuid = ?',
        whereArgs: ['checklists_preenchidos', uuid],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final id = rows.first['id_servidor'];
      if (id is int) return id;
      return int.tryParse(id?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> _exportarPdf() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para exportar o PDF.')),
      );
      return;
    }
    final serverId = await _idServidorChecklistAtual();
    if (serverId == null || serverId < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sincronize o checklist antes de gerar o PDF.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gerando PDF...')),
    );
    final path = await ChecklistExportarPdf.downloadToTemp(
      token: token,
      checklistId: serverId,
      baseFileName: 'checklist-$serverId',
    );
    if (!mounted) return;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o PDF.')),
      );
      return;
    }
    final opened = await OpenFilex.open(path);
    if (!mounted) return;
    if (opened.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened.message.isNotEmpty
                ? 'PDF: ${opened.message}'
                : 'Não foi possível abrir o PDF.',
          ),
        ),
      );
    }
  }

  Future<void> _finalizar() async {
    if (_somenteLeitura || _finalizando) return;
    final prog = _progresso();
    if (prog['pode_finalizar'] != true) {
      final pend = (prog['complementos_pendentes'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pend > 0
                ? 'Há $pend complemento(s) obrigatório(s) pendente(s) (comentário, plano ou anexo).'
                : 'Responda todos os itens obrigatórios antes de finalizar.',
          ),
        ),
      );
      return;
    }

    final exigeComentario = _templateExigeComentarioGeral();
    final comentario = await _pedirComentarioGeral(obrigatorio: exigeComentario);
    if (exigeComentario && (comentario == null || comentario.isEmpty)) {
      return;
    }

    setState(() => _finalizando = true);
    try {
      final result = await actions.finalizarChecklist(
        FFAppState().checklistAtualJson,
        comentario ?? '',
        '',
      );
      final decoded = json.decode(result);
      if (decoded is Map && decoded['sucesso'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Checklist finalizado. Nota: ${decoded['nota_final'] ?? 0}%',
            ),
          ),
        );
        context.safePop();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decoded is Map
                  ? (decoded['mensagem']?.toString() ?? 'Erro ao finalizar')
                  : 'Erro ao finalizar',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _finalizando = false);
    }
  }

  Widget _campoResposta({
    required String tipo,
    required dynamic areaItem,
    required dynamic perguntaItem,
    required int perguntaIndex,
    required int totalPerguntas,
  }) {
    final areaId = getJsonField(areaItem, r"$['id']");
    final itemId = getJsonField(perguntaItem, r"$['id']");

    switch (tipo) {
      case 'Texto':
        return CampoTextoChecklistWidget(
          key: Key('txt_${perguntaIndex}_$totalPerguntas'),
          index: itemId,
          areaId: areaId,
          perguntaId: itemId,
        );
      case 'Avaliativo Emojis':
        return AvaliativoEmojisChecklistWidget(
          key: Key('emo_${areaId}_$itemId'),
          index: itemId,
          areaId: areaId,
          perguntaId: itemId,
          valorAtual:
              getJsonField(perguntaItem, r"$['respostaEmoji']")?.toString(),
          opcoes: perguntaItem is Map &&
                  perguntaItem['emojiRatingOptions'] is List
              ? List<dynamic>.from(
                  perguntaItem['emojiRatingOptions'] as List)
              : null,
        );
      case 'Avaliativo Sim/Não':
        final raw = getJsonField(perguntaItem, r"$['respostaBoolean']");
        bool? valor;
        if (raw is bool) {
          valor = raw;
        } else if (raw != null) {
          valor = raw.toString() == 'true' || raw.toString() == '1';
        }
        return AvaliativoSimNaoChecklistWidget(
          key: Key('bool_${perguntaIndex}_$totalPerguntas'),
          areaId: areaId,
          itemId: itemId,
          valorAtual: valor,
        );
      case 'Opção':
        return DropdownOpcoesChecklistWidget(
          key: Key('opt_${perguntaIndex}_$totalPerguntas'),
          areaId: areaId,
          itemId: itemId,
          opcoes: perguntaItem['options'] is List
              ? List<dynamic>.from(perguntaItem['options'] as List)
              : null,
          valorAtual:
              getJsonField(perguntaItem, r"$['respostaOpcao']")?.toString(),
        );
      case 'Número':
        return CampoNumeroIntChecklistWidget(
          key: Key('num_${perguntaIndex}_$totalPerguntas'),
          index: itemId,
          areaId: areaId,
          perguntaId: itemId,
        );
      case 'Data':
        return CampoDataChecklistWidget(
          key: Key('dat_${perguntaIndex}_$totalPerguntas'),
          index: itemId,
          areaId: areaId,
          perguntaId: itemId,
        );
      case 'Cadastro':
        return CampoCadastroChecklistWidget(
          key: Key('cad_${perguntaIndex}_$totalPerguntas'),
          index: itemId,
          areaId: areaId,
          perguntaId: itemId,
        );
      case 'Anexo':
        final anexosResposta = checklistListaAnexos(
          perguntaItem is Map ? perguntaItem['anexos'] : null,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (anexosResposta.isEmpty)
              Text(
                'Nenhum arquivo na resposta.',
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.inter(),
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
              ),
            ...anexosResposta.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        checklistNomeAnexo(a),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FFButtonWidget(
                onPressed: () => _mostrarAnexos(
                  areaId: areaId,
                  itemId: itemId,
                  anexosAtuais: anexosResposta,
                  complementar: false,
                  titulo: 'Anexos da resposta',
                ),
                text: anexosResposta.isEmpty
                    ? 'Adicionar anexos'
                    : 'Gerenciar anexos (${anexosResposta.length})',
                icon: const Icon(Icons.attach_file, size: 14),
                options: FFButtonOptions(
                  height: 36,
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  textStyle: FlutterFlowTheme.of(context).bodySmall,
                  elevation: 0,
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        );
      default:
        return CampoTextoChecklistWidget(
          key: Key('def_${perguntaIndex}_$totalPerguntas'),
          index: itemId,
          areaId: areaId,
          perguntaId: itemId,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    final dados =
        functions.getDadosFromChecklist(FFAppState().checklistAtualJson);
    final nome = (dados is Map
            ? (dados['template_name'] ?? dados['nome'] ?? 'Checklist')
            : 'Checklist')
        .toString();
    final prog = _progresso();
    final total = (prog['total_itens'] as num?)?.toInt() ?? 0;
    final respondidos = (prog['itens_respondidos'] as num?)?.toInt() ?? 0;
    final pct = (prog['progresso_total'] as num?)?.toInt() ?? 0;
    final podeFinalizar =
        prog['pode_finalizar'] == true && !_somenteLeitura;
    final areas =
        functions.getAreasFromChecklist(FFAppState().checklistAtualJson);

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
            children: [
              Container(
                width: double.infinity,
                color: FlutterFlowTheme.of(context).primary,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nome,
                            style: FlutterFlowTheme.of(context)
                                .headlineSmall
                                .override(
                                  font: GoogleFonts.interTight(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (_somenteLeitura)
                          FlutterFlowIconButton(
                            borderRadius: 20.0,
                            buttonSize: 40.0,
                            fillColor: const Color(0x33FFFFFF),
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              color: Colors.white,
                              size: 20.0,
                            ),
                            onPressed: _exportarPdf,
                          ),
                        FlutterFlowIconButton(
                          borderRadius: 20.0,
                          buttonSize: 40.0,
                          fillColor: const Color(0x33FFFFFF),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20.0,
                          ),
                          onPressed: () => context.safePop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progresso: $respondidos/$total perguntas',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(),
                                    color: Colors.white,
                                    fontSize: 14.0,
                                  ),
                            ),
                            Text(
                              _somenteLeitura
                                  ? 'Checklist respondido'
                                  : '$pct% concluído',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.inter(),
                                    color: const Color(0xCCFFFFFF),
                                    fontSize: 12.0,
                                  ),
                            ),
                          ],
                        ),
                        Text(
                          '${areas.length} área${areas.length == 1 ? '' : 's'}',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(),
                                    color: Colors.white,
                                    fontSize: 14.0,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Container(
                      width: double.infinity,
                      height: 8.0,
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (pct.clamp(0, 100) / 100.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).tertiary,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
                  itemCount: areas.length,
                  itemBuilder: (context, areasIndex) {
                    final areasItem = areas[areasIndex];
                    final perguntasRaw =
                        getJsonField(areasItem, r"$['items']");
                    final perguntas = perguntasRaw is List
                        ? perguntasRaw
                        : <dynamic>[];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).primaryBackground,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    color:
                                        FlutterFlowTheme.of(context).primary,
                                    size: 20.0,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Text(
                                      getJsonField(
                                        areasItem,
                                        r"$['name']",
                                      ).toString(),
                                      style: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .override(
                                            font: GoogleFonts.interTight(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12.0),
                              ...List.generate(perguntas.length, (i) {
                                final perguntaItem = perguntas[i];
                                final tipo = _tipoItem(perguntaItem);
                                final areaId = getJsonField(
                                  areasItem,
                                  r"$['id']",
                                );
                                final itemId = getJsonField(
                                  perguntaItem,
                                  r"$['id']",
                                );
                                final comentario = (getJsonField(
                                          perguntaItem,
                                          r"$['respostaComentario']",
                                        ) ??
                                        getJsonField(
                                          perguntaItem,
                                          r"$['comentario']",
                                        ) ??
                                        '')
                                    .toString();
                                final planoRaw = perguntaItem is Map
                                    ? perguntaItem['planoAcao']
                                    : null;
                                final plano =
                                    planoRaw is Map ? planoRaw : null;
                                final itemMap = perguntaItem is Map
                                    ? Map<String, dynamic>.from(perguntaItem)
                                    : <String, dynamic>{};
                                final anexosComp = checklistListaAnexos(
                                  itemMap['anexosComplementares'],
                                );
                                final mostraComentario =
                                    checklistMostraComplemento(
                                        itemMap, 'comentario');
                                final mostraPlano =
                                    checklistMostraComplemento(
                                        itemMap, 'plano_acao');
                                final mostraAnexo =
                                    checklistMostraComplemento(
                                        itemMap, 'anexo');
                                final exigeComentario =
                                    checklistExigeComplemento(
                                        itemMap, 'comentario');
                                final exigePlano = checklistExigeComplemento(
                                    itemMap, 'plano_acao');
                                final exigeAnexo = checklistExigeComplemento(
                                    itemMap, 'anexo');
                                final pendencias =
                                    checklistPendenciasComplementos(itemMap);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          getJsonField(
                                            perguntaItem,
                                            r"$['description']",
                                          ).toString(),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        const SizedBox(height: 12.0),
                                        IgnorePointer(
                                          ignoring: _somenteLeitura,
                                          child: _campoResposta(
                                            tipo: tipo,
                                            areaItem: areasItem,
                                            perguntaItem: perguntaItem,
                                            perguntaIndex: i,
                                            totalPerguntas: perguntas.length,
                                          ),
                                        ),
                                        if (comentario.trim().isNotEmpty) ...[
                                          const SizedBox(height: 8.0),
                                          Text(
                                            'Comentário: $comentario',
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  font: GoogleFonts.inter(),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                ),
                                          ),
                                        ],
                                        if (plano != null &&
                                            (plano['descricao'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 4.0),
                                          Text(
                                            'Plano: ${plano['descricao']}'
                                            '${(plano['responsavel_nome'] ?? plano['responsavel'] ?? '').toString().trim().isNotEmpty ? ' · ${(plano['responsavel_nome'] ?? plano['responsavel']).toString()}' : ''}'
                                            '${checklistListaAnexos(plano['anexos']).isNotEmpty ? ' · ${checklistListaAnexos(plano['anexos']).length} anexo(s)' : ''}',
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  font: GoogleFonts.inter(),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                ),
                                          ),
                                        ],
                                        if (anexosComp.isNotEmpty) ...[
                                          const SizedBox(height: 4.0),
                                          Text(
                                            'Anexos: ${anexosComp.map(checklistNomeAnexo).join(', ')}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  font: GoogleFonts.inter(),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                ),
                                          ),
                                        ],
                                        if (pendencias.isNotEmpty) ...[
                                          const SizedBox(height: 4.0),
                                          Text(
                                            'Pendente: ${pendencias.join(', ')}',
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  font: GoogleFonts.inter(),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                ),
                                          ),
                                        ],
                                        const SizedBox(height: 12.0),
                                        Wrap(
                                          spacing: 8.0,
                                          runSpacing: 8.0,
                                          children: [
                                            if (mostraComentario)
                                              FFButtonWidget(
                                                onPressed: _somenteLeitura
                                                    ? null
                                                    : () => _mostrarComentario(
                                                          areaId,
                                                          itemId,
                                                          comentario,
                                                        ),
                                                text: exigeComentario
                                                    ? 'Comentário *'
                                                    : 'Comentário',
                                                icon: Icon(
                                                  comentario.trim().isEmpty
                                                      ? Icons
                                                          .chat_bubble_outline
                                                      : Icons.chat_bubble,
                                                  size: 14.0,
                                                ),
                                                options: FFButtonOptions(
                                                  height: 32.0,
                                                  padding:
                                                      const EdgeInsetsDirectional
                                                          .fromSTEB(
                                                          8.0, 4.0, 8.0, 4.0),
                                                  iconPadding: EdgeInsets.zero,
                                                  iconColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .secondaryText,
                                                  color:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground,
                                                  textStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(),
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryText,
                                                          ),
                                                  elevation: 0.0,
                                                  borderSide: BorderSide(
                                                    color:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .alternate,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          4.0),
                                                ),
                                              ),
                                            if (mostraAnexo)
                                              FFButtonWidget(
                                                onPressed: () => _mostrarAnexos(
                                                  areaId: areaId,
                                                  itemId: itemId,
                                                  anexosAtuais: anexosComp,
                                                  complementar: true,
                                                  titulo: exigeAnexo
                                                      ? 'Anexos *'
                                                      : 'Anexos',
                                                ),
                                                text: anexosComp.isEmpty
                                                    ? (exigeAnexo
                                                        ? 'Anexo *'
                                                        : 'Anexo')
                                                    : 'Anexo (${anexosComp.length})',
                                                icon: const Icon(
                                                  Icons.attach_file,
                                                  size: 14.0,
                                                ),
                                                options: FFButtonOptions(
                                                  height: 32.0,
                                                  padding:
                                                      const EdgeInsetsDirectional
                                                          .fromSTEB(
                                                          8.0, 4.0, 8.0, 4.0),
                                                  iconPadding: EdgeInsets.zero,
                                                  iconColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .secondaryText,
                                                  color:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground,
                                                  textStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(),
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryText,
                                                          ),
                                                  elevation: 0.0,
                                                  borderSide: BorderSide(
                                                    color:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .alternate,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          4.0),
                                                ),
                                              ),
                                            if (mostraPlano)
                                              FFButtonWidget(
                                                onPressed: _somenteLeitura
                                                    ? null
                                                    : () => _mostrarPlanoAcao(
                                                          areaId,
                                                          itemId,
                                                          plano,
                                                        ),
                                                text: exigePlano
                                                    ? 'Plano de Ação *'
                                                    : 'Plano de Ação',
                                                icon: const Icon(
                                                  Icons.assignment,
                                                  size: 14.0,
                                                ),
                                                options: FFButtonOptions(
                                                  height: 32.0,
                                                  padding:
                                                      const EdgeInsetsDirectional
                                                          .fromSTEB(
                                                          8.0, 4.0, 8.0, 4.0),
                                                  iconPadding: EdgeInsets.zero,
                                                  iconColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .secondaryText,
                                                  color:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground,
                                                  textStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(),
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryText,
                                                          ),
                                                  elevation: 0.0,
                                                  borderSide: BorderSide(
                                                    color:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .alternate,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          4.0),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!_somenteLeitura)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: FFButtonWidget(
                      onPressed: (_finalizando || !podeFinalizar)
                          ? null
                          : _finalizar,
                      text: _finalizando
                          ? 'Finalizando...'
                          : (podeFinalizar
                              ? 'Finalizar checklist'
                              : 'Responda os obrigatórios'),
                      options: FFButtonOptions(
                        width: double.infinity,
                        height: 52.0,
                        color: podeFinalizar
                            ? FlutterFlowTheme.of(context).primary
                            : FlutterFlowTheme.of(context).alternate,
                        textStyle:
                            FlutterFlowTheme.of(context).titleMedium.override(
                                  font: GoogleFonts.interTight(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                        elevation: 0.0,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
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
