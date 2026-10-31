import 'dart:convert';

import '/custom_code/actions/check_internet_connection.dart';
import '/custom_code/actions/criar_rdo_ia_chat_stream.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class _ChatMsg {
  _ChatMsg({
    required this.tipo,
    required this.conteudo,
    this.erro = false,
  });

  final String tipo; // usuario | ia
  final String conteudo;
  final bool erro;
}

class CriarRdoComIaWidget extends StatefulWidget {
  const CriarRdoComIaWidget({
    super.key,
    required this.obraId,
    this.obraNome,
    this.obraUuid,
  });

  final int? obraId;
  final String? obraNome;
  final String? obraUuid;

  static String routeName = 'criarRdoComIa';
  static String routePath = '/criarRdoComIa';

  @override
  State<CriarRdoComIaWidget> createState() => _CriarRdoComIaWidgetState();
}

class _CriarRdoComIaWidgetState extends State<CriarRdoComIaWidget> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _client = CriarRdoIaChatClient();
  final _mensagens = <_ChatMsg>[];
  final _imagensBase64 = <String>[];

  bool _online = false;
  bool _checandoRede = true;
  bool _carregando = false;
  String _streamingText = '';
  int? _relatorioIdSessao;
  int? _atividadeIdSessao;
  String? _editPathDetectado;

  @override
  void initState() {
    super.initState();
    _verificarInternet();
  }

  @override
  void dispose() {
    _client.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarInternet() async {
    setState(() => _checandoRede = true);
    final ok = await checkInternetConnection();
    if (!mounted) return;
    setState(() {
      _online = ok;
      _checandoRede = false;
    });
  }

  List<Map<String, String>> _buildHistorico() {
    final pares = <Map<String, String>>[];
    for (final msg in _mensagens) {
      if (msg.tipo == 'usuario') {
        pares.add({'role': 'user', 'content': msg.conteudo});
      } else if (msg.tipo == 'ia' && !msg.erro) {
        pares.add({'role': 'assistant', 'content': msg.conteudo});
      }
    }
    if (pares.length > 30) {
      return pares.sublist(pares.length - 30);
    }
    return pares;
  }

  void _detectarEditPath(String texto) {
    final match =
        RegExp(r'''/relatorios/edit/[^\s)\]"'<>]+''').firstMatch(texto);
    if (match != null) {
      _editPathDetectado = match.group(0);
    }
  }

  Future<void> _scrollToBottom() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!_scrollCtrl.hasClients) return;
    await _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  Future<void> _anexarFotos() async {
    if (_carregando || _imagensBase64.length >= 5) return;
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 75);
    if (files.isEmpty || !mounted) return;

    final remaining = 5 - _imagensBase64.length;
    for (final file in files.take(remaining)) {
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? 'image/jpeg';
      final b64 = base64Encode(bytes);
      _imagensBase64.add('data:$mime;base64,$b64');
    }
    if (mounted) setState(() {});
  }

  Future<void> _enviar([String? textoFixo]) async {
    final pergunta = (textoFixo ?? _inputCtrl.text).trim();
    final temFotos = _imagensBase64.isNotEmpty;
    if ((pergunta.isEmpty && !temFotos) || _carregando || !_online) return;

    final textoEnvio = pergunta.isNotEmpty
        ? pergunta
        : 'Seguem as fotos da atividade para registrar.';
    final fotosCount = _imagensBase64.length;

    setState(() {
      _mensagens.add(_ChatMsg(
        tipo: 'usuario',
        conteudo: textoEnvio +
            (fotosCount > 0 ? ' [$fotosCount foto(s)]' : ''),
      ));
      _inputCtrl.clear();
      _carregando = true;
      _streamingText = '';
    });
    await _scrollToBottom();

    final imagensEnvio = List<String>.from(_imagensBase64);

    try {
      final historico = _buildHistorico();
      // Remove a mensagem do usuário recém-adicionada do histórico enviado
      // (o backend recebe a pergunta atual separada).
      if (historico.isNotEmpty && historico.last['role'] == 'user') {
        historico.removeLast();
      }

      final result = await _client.send(
        pergunta: textoEnvio,
        obraId: widget.obraId,
        relatorioId: _relatorioIdSessao,
        atividadeId: _atividadeIdSessao,
        historico: historico,
        imagens: imagensEnvio,
        onPartialText: (partial) {
          if (!mounted) return;
          setState(() => _streamingText = partial);
          _scrollToBottom();
        },
      );

      if (!mounted) return;
      _imagensBase64.clear();
      if (result.relatorioId != null) {
        _relatorioIdSessao = result.relatorioId;
      }
      if (result.atividadeId != null) {
        _atividadeIdSessao = result.atividadeId;
      }
      _detectarEditPath(result.text);
      setState(() {
        _mensagens.add(_ChatMsg(tipo: 'ia', conteudo: result.text));
        _streamingText = '';
        _carregando = false;
      });
    } on CriarRdoIaChatException catch (e) {
      if (!mounted) return;
      if (e.message == 'Requisição cancelada') {
        setState(() {
          _carregando = false;
          _streamingText = '';
        });
        return;
      }
      setState(() {
        _mensagens.add(_ChatMsg(
          tipo: 'ia',
          conteudo: e.message,
          erro: true,
        ));
        _streamingText = '';
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensagens.add(_ChatMsg(
          tipo: 'ia',
          conteudo: 'Não foi possível falar com a IA.',
          erro: true,
        ));
        _streamingText = '';
        _carregando = false;
      });
    }
    await _scrollToBottom();
  }

  String get _tituloObra {
    final nome = widget.obraNome?.trim();
    if (nome != null && nome.isNotEmpty) return nome;
    if (widget.obraId != null) return 'Obra #${widget.obraId}';
    return 'Assistente de RDO';
  }

  List<({String label, String pergunta})> get _sugestoes {
    if (widget.obraId != null) {
      return const [
        (
          label: 'Começar',
          pergunta:
              'Quero criar um novo RDO nesta obra. Quais modelos estão disponíveis?',
        ),
        (
          label: 'RDO de hoje',
          pergunta:
              'Quero criar o RDO de hoje. Me mostre os modelos e siga o fluxo.',
        ),
      ];
    }
    return const [
      (
        label: 'Começar',
        pergunta: 'Quero criar um novo RDO. Liste minhas obras.',
      ),
      (
        label: 'RDO de hoje',
        pergunta:
            'Quero criar o RDO de hoje. Me ajude a escolher a obra e o modelo.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.primary,
          automaticallyImplyLeading: false,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30,
            borderWidth: 1,
            buttonSize: 48,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () {
              if (_carregando) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Aguarde a resposta da IA terminar.'),
                  ),
                );
                return;
              }
              context.safePop();
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Criar RDO com IA',
                style: theme.titleMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: 0,
                ),
              ),
              Text(
                _tituloObra,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall.override(
                  font: GoogleFonts.inter(),
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          actions: [
            if (!_online && !_checandoRede)
              IconButton(
                tooltip: 'Tentar novamente',
                onPressed: _verificarInternet,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
          ],
          centerTitle: false,
          elevation: 0,
        ),
        body: _checandoRede
            ? const Center(child: CircularProgressIndicator())
            : !_online
                ? _buildOffline(theme)
                : Column(
                    children: [
                      Expanded(child: _buildMessages(theme)),
                      if (_editPathDetectado != null) _buildRdoCriadoBanner(theme),
                      _buildComposer(theme),
                    ],
                  ),
      ),
    );
  }

  Widget _buildOffline(FlutterFlowTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: theme.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              'Sem conexão com a internet',
              textAlign: TextAlign.center,
              style: theme.titleMedium.override(
                font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O assistente de IA para criar relatórios só funciona online. Conecte-se e tente novamente.',
              textAlign: TextAlign.center,
              style: theme.bodyMedium.override(
                font: GoogleFonts.inter(),
                color: theme.secondaryText,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _verificarInternet,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(FlutterFlowTheme theme) {
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      children: [
        _buildWelcome(theme),
        for (final msg in _mensagens) ...[
          const SizedBox(height: 10),
          _buildBubble(theme, msg),
        ],
        if (_carregando) ...[
          const SizedBox(height: 10),
          _buildStreamingBubble(theme),
        ],
      ],
    );
  }

  Widget _buildWelcome(FlutterFlowTheme theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatar(theme, isUser: false),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vou te guiar na ordem do preenchimento manual: turno → presenças → materiais recebidos → atividades → gestão de custos → ocorrências → comentários. Você pode pular etapas.',
                  style: theme.bodyMedium.override(
                    font: GoogleFonts.inter(),
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in _sugestoes)
                      ActionChip(
                        label: Text(s.label),
                        onPressed: _carregando
                            ? null
                            : () => _enviar(s.pergunta),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(FlutterFlowTheme theme, _ChatMsg msg) {
    final isUser = msg.tipo == 'usuario';
    final bg = msg.erro
        ? theme.error.withValues(alpha: 0.12)
        : isUser
            ? theme.secondary.withValues(alpha: 0.12)
            : theme.primary.withValues(alpha: 0.08);
    final border = msg.erro
        ? theme.error.withValues(alpha: 0.35)
        : theme.alternate;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isUser) ...[
          _avatar(theme, isUser: false, erro: msg.erro),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: SelectableText(
              msg.conteudo,
              style: theme.bodyMedium.override(
                font: GoogleFonts.inter(),
                color: msg.erro ? theme.error : theme.primaryText,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 8),
          _avatar(theme, isUser: true),
        ],
      ],
    );
  }

  Widget _buildStreamingBubble(FlutterFlowTheme theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatar(theme, isUser: false),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.alternate),
            ),
            child: _streamingText.isNotEmpty
                ? SelectableText(
                    _streamingText,
                    style: theme.bodyMedium.override(
                      font: GoogleFonts.inter(),
                      letterSpacing: 0,
                    ),
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pensando…',
                        style: theme.bodySmall.override(
                          font: GoogleFonts.inter(),
                          color: theme.secondaryText,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _avatar(
    FlutterFlowTheme theme, {
    required bool isUser,
    bool erro = false,
  }) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: erro
          ? theme.error
          : isUser
              ? theme.secondary
              : theme.primary,
      child: Icon(
        isUser ? Icons.person : Icons.auto_awesome,
        size: 16,
        color: Colors.white,
      ),
    );
  }

  Widget _buildRdoCriadoBanner(FlutterFlowTheme theme) {
    return Material(
      color: theme.success.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: theme.success, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'RDO criado no servidor. Sincronize o app para editar offline.',
                style: theme.bodySmall.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  letterSpacing: 0,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                context.pushNamed(
                  RelatoriosObraWidget.routeName,
                  queryParameters: {
                    'obraId': serializeParam(widget.obraId, ParamType.int),
                    'obraUuid':
                        serializeParam(widget.obraUuid, ParamType.String),
                  }.withoutNulls,
                );
              },
              child: const Text('Ver relatórios'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(FlutterFlowTheme theme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          border: Border(top: BorderSide(color: theme.alternate)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imagensBase64.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (var i = 0; i < _imagensBase64.length; i++)
                        Chip(
                          label: Text('Foto ${i + 1}'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: _carregando
                              ? null
                              : () => setState(() => _imagensBase64.removeAt(i)),
                        ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Anexar fotos',
                  onPressed: (_carregando || _imagensBase64.length >= 5)
                      ? null
                      : _anexarFotos,
                  icon: Icon(
                    Icons.photo_camera_outlined,
                    color: theme.primary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    enabled: !_carregando,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _enviar(),
                    decoration: InputDecoration(
                      hintText: 'Descreva o RDO ou peça ajuda…',
                      filled: true,
                      fillColor: theme.primaryBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.alternate),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.alternate),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _carregando ? null : () => _enviar(),
                  icon: _carregando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
