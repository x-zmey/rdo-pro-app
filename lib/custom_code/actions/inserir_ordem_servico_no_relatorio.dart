// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'index.dart'; // Imports other custom actions

// DO NOT REMOVER OR MODIFY THE CODE ABOVE!

import '/backend/sqlite/situacao_soft_delete.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math';

// ===== FUNÇÃO ÚNICA =====

Future<String> inserirOrdemServicoNoRelatorio(
  int relatorioId,
  String relatorioUuid,
  int ordemServicoId,
  String ordemServicoUuid,
  String? observacao,
  int createdBy,
  String createdByUuid,
  double? fatorMultiplicacaoQtd,
) async {
  try {
    final database = await SQLiteManager.instance.database;

    // Gerar UUID
    String generateUuid() {
      final random = Random();
      final hexDigits = '0123456789abcdef';
      String generatePart(int length) {
        return List.generate(length, (index) => hexDigits[random.nextInt(16)])
            .join();
      }

      return '${generatePart(8)}-${generatePart(4)}-4${generatePart(3)}-${generatePart(4)}-${generatePart(12)}';
    }

    final uuidOrdemServico = generateUuid();
    int relatorioOrdemServicoId = 0;
    String relatorioOrdemServicoUuid = '';
    int custosInseridos = 0;
    String codigoOrdem = '';
    String dataEmissaoOrdem = '';

    // Iniciar transação
    await database.transaction((txn) async {
      // 1. Verificar se a ordem de serviço existe e pegar informações
      final verificaOrdem = '''
        SELECT codigo, data_emissao FROM ordens_servico WHERE uuid = ?
      ''';
      final verificaResult =
          await txn.rawQuery(verificaOrdem, [ordemServicoUuid]);

      if (verificaResult.isEmpty) {
        throw Exception('Ordem de serviço não encontrada');
      }

      codigoOrdem = verificaResult.first['codigo'] as String? ?? '';
      dataEmissaoOrdem = verificaResult.first['data_emissao'] as String? ?? '';

      // 2. Verificar se já existe no relatório
      final verificaExistente = '''
        SELECT COUNT(*) as count FROM relatorio_ordem_servico 
        WHERE relatorio_uuid = ? AND ordem_servico_uuid = ?
        AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
      ''';
      final existenteResult = await txn
          .rawQuery(verificaExistente, [relatorioUuid, ordemServicoUuid]);
      final existenteCount = (existenteResult.first['count'] as int?) ?? 0;

      if (existenteCount > 0) {
        throw Exception('Esta ordem já foi adicionada ao relatório');
      }

      // 3. Inserir na tabela relatorio_ordem_servico
      final now = DateTime.now().toIso8601String();

      final queryRelatorioOrdemServico = '''
        INSERT INTO relatorio_ordem_servico (
          uuid, relatorio_id, relatorio_uuid, ordem_servico_id, ordem_servico_uuid, observacao, 
          created_by, created_at, updated_at, situacao, synced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''';

      relatorioOrdemServicoId =
          await txn.rawInsert(queryRelatorioOrdemServico, [
        uuidOrdemServico,
        relatorioId,
        relatorioUuid,
        ordemServicoId,
        ordemServicoUuid,
        observacao ?? '',
        createdByUuid,
        now,
        now,
        kSituacaoAtivo,
        0
      ]);
      relatorioOrdemServicoUuid = uuidOrdemServico;

      // 4. Buscar custos da ordem
      final queryCustos = '''
        SELECT id, uuid, descricao, qtd_prevista, valor_unitario 
        FROM ordem_servico_custos 
        WHERE ordem_servico_uuid = ?
          AND (situacao IS NULL OR CAST(situacao AS INTEGER) != $kSituacaoExcluidoLogico)
      ''';

      final custos = await txn.rawQuery(queryCustos, [ordemServicoUuid]);
      custosInseridos = custos.length;

      // 5. Inserir cada custo
      for (final custo in custos) {
        final ordemServicoCustoUuid = custo['uuid'] as String? ?? '';
        final ordemServicoCustoId = custo['id'] as int? ?? 0;
        final valorUnitario = custo['valor_unitario'] as double? ?? 0.0;
        final descricao = custo['descricao'] as String? ?? '';

        // Realizado no dia: inicia em zero; o usuário informa a quantidade no relatório
        const qtdRealizada = 0.0;
        final valorTotalReal = qtdRealizada * valorUnitario;
        final uuidCusto = generateUuid();

        final queryInserirCusto = '''
          INSERT INTO relatorio_custos (
            uuid, relatorio_id, relatorio_uuid, relatorio_ordem_servico_id, relatorio_ordem_servico_uuid,
            ordem_servico_custo_id, ordem_servico_custo_uuid, qtd_realizada, valor_unitario_real,
            valor_total_real, observacao, created_by, created_at, updated_at, situacao, synced
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''';

        await txn.rawInsert(queryInserirCusto, [
          uuidCusto,
          relatorioId,
          relatorioUuid,
          relatorioOrdemServicoId,
          relatorioOrdemServicoUuid,
          ordemServicoCustoId,
          ordemServicoCustoUuid,
          qtdRealizada,
          valorUnitario,
          valorTotalReal,
          'Cópia de: $descricao',
          createdByUuid,
          now,
          now,
          kSituacaoAtivo,
          0
        ]);
      }
    });

    await SQLiteManager.instance.touchRelatorioModificadoLocal(
      relatorioId: relatorioId,
    );

    // Atualizar AppState com resultados
    try {
      FFAppState().update(() {
        FFAppState().ultimaOrdemAdicionadaId = relatorioOrdemServicoId;
        FFAppState().ultimaOrdemAdicionadaUuid = relatorioOrdemServicoUuid;
        FFAppState().ultimosCustosInseridos = custosInseridos;
        FFAppState().ultimaAcaoSucesso = true;
        FFAppState().ultimaAcaoMensagem =
            'Ordem $codigoOrdem adicionada com $custosInseridos custos';
        FFAppState().codigoUltimaOrdem = codigoOrdem;
        FFAppState().dataEmissaoUltimaOrdem = dataEmissaoOrdem;
      });
    } catch (e) {
      print('⚠️ Erro ao atualizar AppState: $e');
    }

    // Retorno em formato simples
    return 'SUCCESS:$relatorioOrdemServicoId:$custosInseridos:$codigoOrdem';
  } catch (e) {
    print('❌ Erro: $e');

    // Atualizar AppState com erro
    try {
      FFAppState().update(() {
        FFAppState().ultimaAcaoSucesso = false;
        FFAppState().ultimaAcaoMensagem = 'Erro: ${e.toString()}';
        FFAppState().ultimoErroAcao = e.toString();
      });
    } catch (e) {
      print('⚠️ Erro ao atualizar AppState: $e');
    }

    return 'ERROR:${e.toString()}';
  }
}
