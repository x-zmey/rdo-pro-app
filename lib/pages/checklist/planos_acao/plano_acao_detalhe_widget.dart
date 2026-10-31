import 'dart:convert';
import 'dart:math';

import '/backend/sqlite/sqlite_manager.dart';
import '/custom_code/actions/checklist_complementos.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class PlanoAcaoDetalheWidget extends StatefulWidget {
  const PlanoAcaoDetalheWidget({
    super.key,
    this.planoId,
    this.planoUuid,
  });

  final int? planoId;
  final String? planoUuid;

  static String routeName = 'planoAcaoDetalhe';
  static String routePath = '/planoAcaoDetalhe';

  @override
  State<PlanoAcaoDetalheWidget> createState() => _PlanoAcaoDetalheWidgetState();
}

class _PlanoAcaoDetalheWidgetState extends State<PlanoAcaoDetalheWidget> {
  Map<String, dynamic>? _plano;
  List<Map<String, dynamic>> _solucoes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final db = await SQLiteManager.instance.database;
    List<Map<String, dynamic>> rows = [];
    if (widget.planoUuid != null && widget.planoUuid!.trim().isNotEmpty) {
      rows = await db.query(
        'planos_acoes',
        where: 'uuid = ?',
        whereArgs: [widget.planoUuid!.trim()],
        limit: 1,
      );
    }
    if (rows.isEmpty && widget.planoId != null) {
      rows = await db.query(
        'planos_acoes',
        where: 'id = ?',
        whereArgs: [widget.planoId],
        limit: 1,
      );
    }
    if (rows.isEmpty) {
      if (mounted) {
        setState(() {
          _plano = null;
          _loading = false;
        });
      }
      return;
    }
    final plano = Map<String, dynamic>.from(rows.first);
    final planoId = plano['id'] as int?;
    final solRows = planoId == null
        ? <Map<String, dynamic>>[]
        : await db.query(
            'solucoes_planos_acoes',
            where: 'plano_acao_id = ?',
            whereArgs: [planoId],
            orderBy: 'created_at DESC',
          );
    if (!mounted) return;
    setState(() {
      _plano = plano;
      _solucoes = solRows.map((e) => Map<String, dynamic>.from(e)).toList();
      _loading = false;
    });
  }

  String _generateUuid() {
    final random = Random();
    const hex = '0123456789abcdef';
    String part(int n) =>
        List.generate(n, (_) => hex[random.nextInt(16)]).join();
    return '${part(8)}-${part(4)}-4${part(3)}-${part(4)}-${part(12)}';
  }

  Future<void> _atualizarStatus(String status) async {
    final plano = _plano;
    if (plano == null) return;
    final db = await SQLiteManager.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'planos_acoes',
      {
        'status': status,
        'synced': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [plano['id']],
    );
    await _carregar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status atualizado: $status')),
    );
  }

  Future<void> _adicionarSolucao() async {
    final plano = _plano;
    if (plano == null) return;
    final tituloCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var anexos = <Map<String, dynamic>>[];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Registrar solução'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
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
                  label: Text(
                    anexos.isEmpty
                        ? 'Anexar evidência'
                        : 'Anexos (${anexos.length})',
                  ),
                ),
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
                if (tituloCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Informe o título.')),
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

    if (ok != true) {
      tituloCtrl.dispose();
      descCtrl.dispose();
      return;
    }

    // Upload anexos se online (best-effort); senão mantém local para sync.
    var anexosFinais = anexos;
    final token = FFAppState().UserToken.trim();
    if (token.isNotEmpty && anexos.isNotEmpty) {
      try {
        anexosFinais = await actions.uploadListaAnexosLocais(
          anexos: anexos,
          token: token,
          destino: 'planos-acoes/solucoes',
        );
      } catch (_) {}
    }

    final db = await SQLiteManager.instance.database;
    final now = DateTime.now().toIso8601String();
    final createdBy = FFAppState().creatorUuid.trim().isNotEmpty
        ? FFAppState().creatorUuid.trim()
        : (FFAppState().UserID > 0 ? FFAppState().UserID.toString() : '0');
    await db.insert('solucoes_planos_acoes', {
      'uuid': _generateUuid(),
      'plano_acao_id': plano['id'],
      'plano_acao_uuid': plano['uuid'],
      'titulo': tituloCtrl.text.trim(),
      'descricao': descCtrl.text.trim(),
      'custo': null,
      'quantidade': 1,
      'status': 'Pendente',
      'anexos': json.encode(anexosFinais),
      'created_by': createdBy,
      'synced': 0,
      'sync_try_count': 0,
      'created_at': now,
      'updated_at': now,
    });

    // Se plano ainda aberto, marca em andamento
    await db.update(
      'planos_acoes',
      {'synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [plano['id']],
    );

    tituloCtrl.dispose();
    descCtrl.dispose();
    await _carregar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solução registrada. Será sincronizada.')),
    );
  }

  List<Map<String, dynamic>> _anexosPlano() {
    final raw = _plano?['anexos'];
    if (raw is String) {
      try {
        return checklistListaAnexos(json.decode(raw));
      } catch (_) {
        return [];
      }
    }
    return checklistListaAnexos(raw);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.primaryBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final plano = _plano;
    if (plano == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: theme.primaryBackground,
          leading: FlutterFlowIconButton(
            borderRadius: 30,
            buttonSize: 60,
            icon: Icon(Icons.arrow_back_rounded, color: theme.primaryText),
            onPressed: () => context.safePop(),
          ),
        ),
        body: const Center(child: Text('Plano não encontrado.')),
      );
    }

    final anexos = _anexosPlano();
    final status = (plano['status'] ?? 'Em andamento').toString();

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.primaryBackground,
        elevation: 0,
        leading: FlutterFlowIconButton(
          borderRadius: 30,
          buttonSize: 60,
          icon: Icon(Icons.arrow_back_rounded, color: theme.primaryText),
          onPressed: () => context.safePop(),
        ),
        title: Text(
          'Plano de ação',
          style: theme.headlineMedium.override(
            font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              (plano['descricao'] ?? '').toString(),
              style: theme.titleMedium.override(
                font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              [
                if ((plano['area'] ?? '').toString().isNotEmpty)
                  'Área: ${plano['area']}',
                if ((plano['pergunta'] ?? '').toString().isNotEmpty)
                  'Pergunta: ${plano['pergunta']}',
                if ((plano['prazo'] ?? '').toString().isNotEmpty)
                  'Prazo: ${plano['prazo']}',
                'Prioridade: ${plano['prioridade'] ?? 'media'}',
                'Status: $status',
              ].join('\n'),
              style: theme.bodyMedium.override(
                font: GoogleFonts.inter(),
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            Text('Atualizar status', style: theme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in ['Em andamento', 'Concluído', 'Cancelado'])
                  ChoiceChip(
                    label: Text(s),
                    selected: status == s,
                    onSelected: (_) => _atualizarStatus(s),
                  ),
              ],
            ),
            if (anexos.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Anexos do plano', style: theme.titleSmall),
              const SizedBox(height: 8),
              ...anexos.map(
                (a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(checklistNomeAnexo(a)),
                  subtitle: Text(
                    checklistPathAnexo(a),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Soluções', style: theme.titleSmall),
                ),
                FFButtonWidget(
                  onPressed: _adicionarSolucao,
                  text: 'Nova',
                  icon: const Icon(Icons.add, size: 18),
                  options: FFButtonOptions(
                    height: 36,
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
                    color: theme.primary,
                    textStyle: theme.bodySmall.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      color: Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_solucoes.isEmpty)
              Text(
                'Nenhuma solução registrada.',
                style: theme.bodySmall.override(
                  font: GoogleFonts.inter(),
                  color: theme.secondaryText,
                ),
              )
            else
              ..._solucoes.map((s) {
                List anexosSol = [];
                final raw = s['anexos'];
                if (raw is String) {
                  try {
                    anexosSol = checklistListaAnexos(json.decode(raw));
                  } catch (_) {}
                } else {
                  anexosSol = checklistListaAnexos(raw);
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text((s['titulo'] ?? '').toString()),
                    subtitle: Text(
                      [
                        if ((s['descricao'] ?? '').toString().isNotEmpty)
                          s['descricao'].toString(),
                        'Status: ${s['status'] ?? 'Pendente'}',
                        if (anexosSol.isNotEmpty)
                          '${anexosSol.length} anexo(s)',
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
