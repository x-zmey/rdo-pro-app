import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '/app_state.dart';
import '/backend/api_requests/api_config.dart';

class CriarRdoIaChatResult {
  const CriarRdoIaChatResult({
    required this.text,
    this.relatorioId,
    this.atividadeId,
  });

  final String text;
  final int? relatorioId;
  final int? atividadeId;
}

class CriarRdoIaChatException implements Exception {
  CriarRdoIaChatException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Cliente SSE de `POST /api/ia/criar-rdo-chat/stream` (mesmo fluxo do web).
class CriarRdoIaChatClient {
  http.Client? _client;

  void cancel() {
    _client?.close();
    _client = null;
  }

  Future<CriarRdoIaChatResult> send({
    required String pergunta,
    int? obraId,
    int? relatorioId,
    int? atividadeId,
    List<Map<String, String>> historico = const [],
    List<String> imagens = const [],
    void Function(String partial)? onPartialText,
  }) async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      throw CriarRdoIaChatException(
        'Faça login para usar a IA.',
        statusCode: 401,
      );
    }

    cancel();
    final client = http.Client();
    _client = client;

    final payload = <String, dynamic>{
      'pergunta': pergunta,
      'historico': historico,
    };
    if (obraId != null) payload['obra_id'] = obraId;
    if (relatorioId != null) payload['relatorio_id'] = relatorioId;
    if (atividadeId != null) payload['atividade_id'] = atividadeId;
    if (imagens.isNotEmpty) payload['imagens'] = imagens;

    final request = http.Request(
      'POST',
      Uri.parse('$kApiBaseUrl/api/ia/criar-rdo-chat/stream'),
    );
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    });
    request.body = jsonEncode(payload);

    try {
      final streamed = await client.send(request);
      final contentType = streamed.headers['content-type'] ?? '';

      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final body = await streamed.stream.bytesToString();
        String message = 'Erro HTTP ${streamed.statusCode}';
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map && decoded['error'] != null) {
            message = decoded['error'].toString();
          }
        } catch (_) {}
        throw CriarRdoIaChatException(
          message,
          statusCode: streamed.statusCode,
        );
      }

      if (!contentType.contains('text/event-stream')) {
        final body = await streamed.stream.bytesToString();
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          final raw = decoded['content'] ??
              (decoded['message'] is Map
                  ? decoded['message']['content']
                  : null) ??
              '';
          final text = raw.toString();
          if (text.trim().isEmpty) {
            throw CriarRdoIaChatException('Resposta vazia da IA');
          }
          return CriarRdoIaChatResult(
            text: text,
            relatorioId: _asPositiveInt(decoded['relatorio_id']),
            atividadeId: _asPositiveInt(decoded['atividade_id']),
          );
        }
        throw CriarRdoIaChatException('Resposta inválida da IA');
      }

      return _parseSse(
        streamed.stream,
        onPartialText: onPartialText,
      );
    } on CriarRdoIaChatException {
      rethrow;
    } on http.ClientException catch (e) {
      if (e.message.toLowerCase().contains('closed') ||
          e.message.toLowerCase().contains('cancel')) {
        throw CriarRdoIaChatException('Requisição cancelada');
      }
      throw CriarRdoIaChatException(
        'Não foi possível conectar ao serviço de IA.',
      );
    } catch (e) {
      if (e is CriarRdoIaChatException) rethrow;
      throw CriarRdoIaChatException(
        e.toString().contains('cancel')
            ? 'Requisição cancelada'
            : 'Não foi possível falar com a IA.',
      );
    } finally {
      if (identical(_client, client)) {
        _client = null;
      }
      client.close();
    }
  }

  Future<CriarRdoIaChatResult> _parseSse(
    Stream<List<int>> byteStream, {
    void Function(String partial)? onPartialText,
  }) async {
    final decoder = utf8.decoder.bind(byteStream);
    var buffer = '';
    var fullText = '';
    String? sseError;
    int? relatorioId;
    int? atividadeId;

    await for (final chunk in decoder) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.isEmpty ? '' : lines.removeLast();

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('event:')) continue;
        if (!line.startsWith('data:')) continue;

        final jsonStr = line.startsWith('data: ')
            ? line.substring(6)
            : line.substring(5);
        Map<String, dynamic>? parsed;
        try {
          final decoded = jsonDecode(jsonStr);
          if (decoded is Map<String, dynamic>) {
            parsed = decoded;
          } else if (decoded is Map) {
            parsed = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          continue;
        }
        if (parsed == null) continue;

        final text = parsed['text'];
        if (text != null) {
          fullText += text.toString();
          onPartialText?.call(fullText);
        }

        final rid = _asPositiveInt(parsed['relatorio_id']);
        if (rid != null) relatorioId = rid;
        final aid = _asPositiveInt(parsed['atividade_id']);
        if (aid != null) atividadeId = aid;

        if (parsed['error'] != null) {
          sseError = parsed['error'].toString();
        }
      }
    }

    if ((sseError ?? '').isNotEmpty && fullText.trim().isEmpty) {
      throw CriarRdoIaChatException(sseError!);
    }
    if (fullText.trim().isEmpty) {
      throw CriarRdoIaChatException('Resposta vazia da IA');
    }

    return CriarRdoIaChatResult(
      text: fullText,
      relatorioId: relatorioId,
      atividadeId: atividadeId,
    );
  }
}

int? _asPositiveInt(dynamic value) {
  if (value == null) return null;
  final n = value is int ? value : int.tryParse(value.toString());
  if (n == null || n <= 0) return null;
  return n;
}
