// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart';
import '/app_state.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:io';

import '/backend/sqlite/situacao_soft_delete.dart';

class _FotoItem {
  _FotoItem({
    required this.id,
    required this.arquivo,
    required this.arquivoServidor,
    required this.nome,
    required this.relatorioStatusId,
  });

  final int id;
  final String arquivo;
  /// URL S3 após sync (`arquivo` pode continuar sendo caminho local até o RDO aprovado).
  final String arquivoServidor;
  final String nome;
  /// `relatorios.status_id`: 3 = aprovado — aí usamos preferencialmente [arquivoServidor].
  final int relatorioStatusId;
}

int _parseRelatorioStatusId(dynamic v) {
  if (v == null) return 1;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 1;
}

bool _isHttpUrlStr(String s) {
  final l = s.trim().toLowerCase();
  return l.startsWith('http://') || l.startsWith('https://');
}

class FotosAtividadeGrid extends StatefulWidget {
  const FotosAtividadeGrid({
    this.width = 300,
    this.height,
    this.reloadTrigger = false,
    required this.atividadeId,
  });

  final double width;
  final double? height;
  final bool reloadTrigger;
  final int atividadeId;

  @override
  State<FotosAtividadeGrid> createState() => _FotosAtividadeGridState();
}

class _FotosAtividadeGridState extends State<FotosAtividadeGrid> {
  List<_FotoItem> _itens = [];
  String debugInfo = 'Carregando...';
  bool _lastReloadTrigger = false;

  @override
  void initState() {
    super.initState();
    _loadFotos();
    _lastReloadTrigger = widget.reloadTrigger;
  }

  @override
  void didUpdateWidget(FotosAtividadeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadTrigger != _lastReloadTrigger) {
      _lastReloadTrigger = widget.reloadTrigger;
      _loadFotos();
    }
  }

  Future<void> _loadFotos() async {
    try {
      final database = SQLiteManager.instance.database;
      List<Map<String, dynamic>> results;
      try {
        results = await database.rawQuery(
          '''
          SELECT f.id, f.arquivo, f.nome, f.situacao,
                 COALESCE(f.arquivo_servidor, '') AS arquivo_servidor,
                 COALESCE(r.status_id, 1) AS relatorio_status_id
          FROM relatorio_atividade_fotos f
          LEFT JOIN relatorio_atividades a ON a.id = f.relatorio_atividade_id
          LEFT JOIN relatorios r ON r.id = a.relatorio_id
          WHERE f.relatorio_atividade_id = ?
            AND (f.situacao IS NULL OR CAST(f.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
          ORDER BY f.id DESC
          ''',
          [widget.atividadeId],
        );
      } catch (_) {
        results = await database.rawQuery(
          '''
          SELECT f.id, f.arquivo, f.nome, f.situacao,
                 COALESCE(r.status_id, 1) AS relatorio_status_id
          FROM relatorio_atividade_fotos f
          LEFT JOIN relatorio_atividades a ON a.id = f.relatorio_atividade_id
          LEFT JOIN relatorios r ON r.id = a.relatorio_id
          WHERE f.relatorio_atividade_id = ?
            AND (f.situacao IS NULL OR CAST(f.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
          ORDER BY f.id DESC
          ''',
          [widget.atividadeId],
        );
      }

      final visivel = results;

      if (visivel.isEmpty) {
        setState(() {
          _itens = [];
          debugInfo = 'Nenhuma foto encontrada para esta atividade.';
        });
        return;
      }

      setState(() {
        _itens = visivel
            .map(
              (r) => _FotoItem(
                id: r['id'] as int,
                arquivo: r['arquivo'] as String? ?? '',
                arquivoServidor: r['arquivo_servidor'] as String? ?? '',
                nome: r['nome'] as String? ?? '',
                relatorioStatusId: _parseRelatorioStatusId(r['relatorio_status_id']),
              ),
            )
            .where((f) =>
                f.arquivo.trim().isNotEmpty ||
                _isHttpUrlStr(f.arquivoServidor))
            .toList();
        debugInfo = 'Foram carregadas ${_itens.length} fotos.';
      });
    } catch (e) {
      try {
        final database = SQLiteManager.instance.database;
        List<Map<String, dynamic>> results;
        try {
          results = await database.rawQuery(
            '''
            SELECT f.id, f.arquivo, f.nome,
                   COALESCE(f.arquivo_servidor, '') AS arquivo_servidor,
                   COALESCE(r.status_id, 1) AS relatorio_status_id
            FROM relatorio_atividade_fotos f
            LEFT JOIN relatorio_atividades a ON a.id = f.relatorio_atividade_id
            LEFT JOIN relatorios r ON r.id = a.relatorio_id
            WHERE f.relatorio_atividade_id = ?
              AND (f.situacao IS NULL OR CAST(f.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
            ORDER BY f.id DESC
            ''',
            [widget.atividadeId],
          );
        } catch (_) {
          results = await database.rawQuery(
            '''
            SELECT id, arquivo, nome
            FROM relatorio_atividade_fotos
            WHERE relatorio_atividade_id = ?
              AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
            ORDER BY id DESC
            ''',
            [widget.atividadeId],
          );
        }
        if (!mounted) return;
        setState(() {
          _itens = results
              .map(
                (r) => _FotoItem(
                  id: r['id'] as int,
                  arquivo: r['arquivo'] as String? ?? '',
                  arquivoServidor: r['arquivo_servidor'] as String? ?? '',
                  nome: r['nome'] as String? ?? '',
                  relatorioStatusId:
                      _parseRelatorioStatusId(r['relatorio_status_id']),
                ),
              )
              .where((f) =>
                  f.arquivo.trim().isNotEmpty ||
                  _isHttpUrlStr(f.arquivoServidor))
              .toList();
          debugInfo = results.isEmpty
              ? 'Nenhuma foto encontrada para esta atividade.'
              : 'Foram carregadas ${_itens.length} fotos.';
        });
      } catch (e2) {
        if (!mounted) return;
        setState(() => debugInfo = 'Erro ao carregar fotos: $e2');
      }
    }
  }

  Future<void> _confirmarRemover(BuildContext context, int fotoId) async {
    final theme = FlutterFlowTheme.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover foto'),
        content: const Text(
          'Deseja remover esta foto? Ela deixará de aparecer na atividade.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: theme.error),
            child: Text('Remover', style: TextStyle(color: theme.primaryBackground)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await softDeleteFotoAtividade(fotoId);
      if (!context.mounted) return;
      await _loadFotos();
      try {
        FFAppState().reloadFotosTrigger = !FFAppState().reloadFotosTrigger;
        FFAppState().update(() {});
      } catch (_) {}
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Foto removida.',
            style: TextStyle(color: theme.primaryText),
          ),
          backgroundColor: theme.secondary,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            style: TextStyle(color: theme.primaryBackground),
          ),
          backgroundColor: theme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('fotos_${widget.atividadeId}_${widget.reloadTrigger}'),
      width: widget.width,
      height: widget.height,
      child: _itens.isEmpty
          ? Center(
              child: Text(
                debugInfo,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            )
          : _buildGridView(context),
    );
  }

  Widget _buildGridView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _itens.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (context, index) {
                final item = _itens[index];
                return _buildThumb(context, item);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumb(BuildContext context, _FotoItem item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImageForItem(item),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                tooltip: 'Remover foto',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: () => _confirmarRemover(context, item.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Enquanto o RDO não está aprovado (`status_id != 3`), prioriza arquivo local; depois, URL do S3.
  Widget _buildImageForItem(_FotoItem item) {
    final preferServidor = item.relatorioStatusId == 3;
    final srv = item.arquivoServidor.trim();
    final loc = item.arquivo.trim();

    final srvOk = _isHttpUrlStr(srv);
    final locHttp = _isHttpUrlStr(loc);

    if (preferServidor) {
      if (srvOk) {
        return Image.network(
          srv,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      }
      if (locHttp) {
        return Image.network(
          loc,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      }
    }

    if (loc.isNotEmpty && !locHttp) {
      try {
        final lower = loc.toLowerCase();
        late final File file;
        if (lower.startsWith('file://')) {
          final uri = Uri.parse(loc);
          file = uri.scheme == 'file' ? File.fromUri(uri) : File(loc);
        } else {
          file = File(loc);
        }
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
          );
        }
      } catch (_) {}
    }

    if (srvOk) {
      return Image.network(
        srv,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }
    if (locHttp) {
      return Image.network(
        loc,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }

    return _buildErrorWidget();
  }

  Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo, color: Colors.grey[500]),
          const SizedBox(height: 4),
          Text(
            'Imagem não\nencontrada',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
