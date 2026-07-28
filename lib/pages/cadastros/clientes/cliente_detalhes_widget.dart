import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/pages/cadastros/cadastrar_cliente/cadastrar_cliente_widget.dart';
import '/pages/obra/detalhes_obra/detalhes_obra_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'cliente_detalhes_model.dart';
export 'cliente_detalhes_model.dart';

/// Detalhes do cliente — equivalente a `frontend/.../clientes/view/[id].vue`.
/// Recebe o id ou uuid do servidor (`GET /api/clientes/{id|uuid}/show`).
class ClienteDetalhesWidget extends StatefulWidget {
  const ClienteDetalhesWidget({
    super.key,
    this.clienteServidorId,
    this.clienteUuid,
  });

  static String routeName = 'ClienteDetalhes';
  static String routePath = '/clienteDetalhes';

  final int? clienteServidorId;
  final String? clienteUuid;

  @override
  State<ClienteDetalhesWidget> createState() => _ClienteDetalhesWidgetState();
}

class _ClienteDetalhesWidgetState extends State<ClienteDetalhesWidget> {
  late ClienteDetalhesModel _model;

  bool _carregando = true;
  String? _erro;
  Map<String, dynamic>? _cliente;
  List<Map<String, dynamic>> _obras = [];

  final TextEditingController _buscaObra = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ClienteDetalhesModel());
    _buscaObra.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  @override
  void dispose() {
    _buscaObra.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final id = widget.clienteServidorId;
    final uuid = widget.clienteUuid?.trim();
    if ((uuid == null || uuid.isEmpty) && (id == null || id <= 0)) {
      setState(() {
        _carregando = false;
        _erro = 'Cliente não informado.';
      });
      return;
    }

    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      setState(() {
        _carregando = false;
        _erro = 'Faça login para ver os dados.';
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    final resp = await ClienteDetalhesCall.call(
      id: id,
      clienteUuid: uuid ?? '',
      token: token,
    );
    if (!mounted) return;

    if (!resp.succeeded || resp.jsonBody is! Map) {
      setState(() {
        _carregando = false;
        _erro = _mensagemErroCliente(resp);
        _cliente = null;
        _obras = [];
      });
      return;
    }

    final m = Map<String, dynamic>.from(resp.jsonBody as Map);
    final obrasRaw = m['obras'];
    final obras = <Map<String, dynamic>>[];
    if (obrasRaw is List) {
      for (final e in obrasRaw) {
        if (e is Map) obras.add(Map<String, dynamic>.from(e));
      }
    }

    setState(() {
      _carregando = false;
      _erro = null;
      _cliente = m;
      _obras = obras;
    });
  }

  String _mensagemErroCliente(ApiCallResponse resp) {
    final jb = resp.jsonBody;
    if (jb is Map && jb['error'] != null) return '${jb['error']}';
    if (resp.statusCode == 404) return 'Cliente não encontrado';
    return resp.bodyText.isNotEmpty
        ? resp.bodyText
        : 'Erro ao carregar cliente';
  }

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  int _countObras(int situacaoId) =>
      _obras.where((o) => _int(o['situacao_id']) == situacaoId).length;

  List<Map<String, dynamic>> get _obrasFiltradas {
    final q = _buscaObra.text.trim().toLowerCase();
    if (q.isEmpty) return _obras;
    return _obras.where((o) {
      bool c(String? x) => (x ?? '').toLowerCase().contains(q);
      return c(o['nome']?.toString()) ||
          c(o['cidade']?.toString()) ||
          c(o['engenheiro']?.toString()) ||
          c(o['contrato']?.toString());
    }).toList();
  }

  String _iniciais(String? nome) {
    if (nome == null || nome.trim().isEmpty) return '?';
    final p =
        nome.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.length >= 2) {
      return '${p.first[0]}${p.last[0]}'.toUpperCase();
    }
    return p.first[0].toUpperCase();
  }

  String _formatDocumento(String? doc, int juridica) {
    if (doc == null || doc.isEmpty) return 'Não informado';
    final d = doc.replaceAll(RegExp(r'\D'), '');
    if (juridica == 1) {
      if (d.length != 14) return doc;
      return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
    }
    if (d.length != 11) return doc;
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
  }

  String _formatTelefone(String? tel) {
    if (tel == null || tel.isEmpty) return 'Não informado';
    final t = tel.replaceAll(RegExp(r'\D'), '');
    if (t.length == 11) {
      return '(${t.substring(0, 2)}) ${t.substring(2, 7)}-${t.substring(7)}';
    }
    if (t.length == 10) {
      return '(${t.substring(0, 2)}) ${t.substring(2, 6)}-${t.substring(6)}';
    }
    return tel;
  }

  String _formatSexo(String? sexo) {
    if (sexo == null || sexo.isEmpty) return 'Não informado';
    const map = {'M': 'Masculino', 'F': 'Feminino', 'O': 'Outro'};
    return map[sexo] ?? sexo;
  }

  String _formatEndereco(Map<String, dynamic> c) {
    final partes = <String>[];
    final rua = c['rua']?.toString().trim();
    final num = c['numero']?.toString().trim();
    if (rua != null && rua.isNotEmpty) {
      partes.add(num != null && num.isNotEmpty ? '$rua, nº $num' : rua);
    }
    final comp = c['complemento']?.toString().trim();
    if (comp != null && comp.isNotEmpty) partes.add(comp);
    final bairro = c['bairro']?.toString().trim();
    if (bairro != null && bairro.isNotEmpty) partes.add(bairro);
    final cidade = c['cidade']?.toString().trim();
    if (cidade != null && cidade.isNotEmpty) partes.add(cidade);
    final est = c['estado']?.toString().trim();
    if (est != null && est.isNotEmpty) partes.add(est);
    return partes.isEmpty ? 'Endereço não informado' : partes.join(', ');
  }

  String _formatDate(dynamic v) {
    if (v == null) return 'Não informado';
    final s = v.toString();
    if (s.contains('/') && !s.contains('T')) return s;
    try {
      final d = DateTime.parse(s);
      return DateFormat('dd/MM/yyyy').format(d.toLocal());
    } catch (_) {
      return s;
    }
  }

  Color _corSituacaoObra(int id) {
    switch (id) {
      case 1:
        return Colors.green.shade700;
      case 2:
        return Colors.orange.shade700;
      case 3:
        return Colors.red.shade700;
      case 4:
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _labelSituacaoObra(int id) {
    switch (id) {
      case 1:
        return 'Ativa';
      case 2:
        return 'Em Andamento';
      case 3:
        return 'Concluída';
      case 4:
        return 'Cancelada';
      default:
        return 'Desconhecido';
    }
  }

  Future<void> _abrirEditar() async {
    final uuid = _cliente?['uuid']?.toString();
    if (uuid == null || uuid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('UUID do cliente indisponível.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    await context.pushNamed(
      CadastrarClienteWidget.routeName,
      queryParameters: {
        'clienteUuid': serializeParam(uuid, ParamType.String),
      }.withoutNulls,
    );
    if (mounted) await _carregar();
  }

  void _abrirObra(Map<String, dynamic> obra) {
    final uuid = obra['uuid']?.toString();
    if (uuid == null || uuid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obra sem UUID no servidor.')),
      );
      return;
    }
    final idSrv = _int(obra['id']);
    context.pushNamed(
      DetalhesObraWidget.routeName,
      queryParameters: {
        'obraId': serializeParam(idSrv > 0 ? idSrv : null, ParamType.int),
        'obraUuid': serializeParam(uuid, ParamType.String),
      }.withoutNulls,
    );
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
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primary,
          automaticallyImplyLeading: true,
          title: Text(
            'Detalhes do cliente',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
                  color: Colors.white,
                  fontSize: 20,
                ),
          ),
          elevation: 0,
        ),
        body: _corpo(context),
      ),
    );
  }

  Widget _corpo(BuildContext context) {
    if (_carregando) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                color: FlutterFlowTheme.of(context).primary),
            const SizedBox(height: 16),
            Text(
              'Carregando dados do cliente...',
              style: FlutterFlowTheme.of(context).titleMedium,
            ),
          ],
        ),
      );
    }

    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 56, color: FlutterFlowTheme.of(context).error),
              const SizedBox(height: 12),
              Text(
                _erro!,
                textAlign: TextAlign.center,
                style: TextStyle(color: FlutterFlowTheme.of(context).error),
              ),
              const SizedBox(height: 16),
              FFButtonWidget(
                onPressed: _carregar,
                text: 'Tentar novamente',
                options: FFButtonOptions(
                  color: FlutterFlowTheme.of(context).primary,
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        color: FlutterFlowTheme.of(context).info,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final c = _cliente!;
    final juridica = _int(c['juridica']);
    final situacao = _int(c['situacao']);
    final ativo = situacao == 1;

    return RefreshIndicator(
      onRefresh: _carregar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Clientes',
                    style: TextStyle(
                      color: FlutterFlowTheme.of(context).primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.safePop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Voltar à lista'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Detalhes do Cliente',
                    style: FlutterFlowTheme.of(context).headlineSmall.override(
                          font: GoogleFonts.interTight(
                              fontWeight: FontWeight.bold),
                        ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _abrirEditar,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Editar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).primary,
                    foregroundColor: FlutterFlowTheme.of(context).info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, bc) {
                final w = bc.maxWidth;
                final cols = w >= 900 ? 4 : (w >= 520 ? 2 : 1);
                final tileW = (w - (cols - 1) * 12) / cols;
                Widget stat(String titulo, int valor, IconData icon) {
                  return SizedBox(
                    width: tileW,
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: FlutterFlowTheme.of(context)
                                  .primary
                                  .withValues(alpha: 0.12),
                              child: Icon(icon,
                                  color: FlutterFlowTheme.of(context).primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titulo,
                                    style: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .override(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                  Text(
                                    '$valor',
                                    style: FlutterFlowTheme.of(context)
                                        .headlineMedium
                                        .override(
                                          font: GoogleFonts.interTight(
                                              fontWeight: FontWeight.bold),
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    stat('TOTAL DE OBRAS', _obras.length,
                        Icons.business_outlined),
                    stat('OBRAS ATIVAS', _countObras(1),
                        Icons.check_circle_outline),
                    stat('EM ANDAMENTO', _countObras(2),
                        Icons.schedule_outlined),
                    stat('CONCLUÍDAS', _countObras(3), Icons.task_alt_outlined),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: FlutterFlowTheme.of(context).primary,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          child: Text(
                            _iniciais(c['nome']?.toString()),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: FlutterFlowTheme.of(context).primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${c['nome'] ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    label: Text(
                                      ativo ? 'ATIVO' : 'INATIVO',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: ativo
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Chip(
                                    avatar: Icon(
                                      juridica == 1
                                          ? Icons.domain
                                          : Icons.person_outline,
                                      size: 16,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                    ),
                                    label: Text(
                                      juridica == 1 ? 'PJ' : 'PF',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                      ),
                                    ),
                                    backgroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final narrow = box.maxWidth < 560;
                        final cols = [
                          _colInfo(context, c, juridica),
                          _colInfo2(context, c),
                        ];
                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              cols[0],
                              const SizedBox(height: 8),
                              cols[1],
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: cols[0]),
                            Expanded(child: cols[1]),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Obras do cliente',
              style: FlutterFlowTheme.of(context).titleLarge.override(
                    font: GoogleFonts.interTight(fontWeight: FontWeight.bold),
                  ),
            ),
            Text(
              '${_obras.length} ${_obras.length == 1 ? 'obra encontrada' : 'obras encontradas'}',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _buscaObra,
              decoration: InputDecoration(
                hintText: 'Buscar obra por nome, cidade, engenheiro...',
                prefixIcon: Icon(Icons.search,
                    color: FlutterFlowTheme.of(context).secondaryText),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            if (_obrasFiltradas.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.business_center_outlined,
                          size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma obra encontrada',
                        style: FlutterFlowTheme.of(context).titleMedium,
                      ),
                      Text(
                        _buscaObra.text.trim().isEmpty
                            ? 'Este cliente ainda não possui obras cadastradas'
                            : 'Nenhuma obra corresponde à busca',
                        textAlign: TextAlign.center,
                        style: FlutterFlowTheme.of(context).bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, bc) {
                  final w = bc.maxWidth;
                  final cross = w >= 900 ? 3 : (w >= 520 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _obrasFiltradas.length,
                    itemBuilder: (context, i) {
                      final obra = _obrasFiltradas[i];
                      final sid = _int(obra['situacao_id']);
                      final foto = obra['foto_url']?.toString();
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Stack(
                              children: [
                                SizedBox(
                                  height: 140,
                                  child: foto != null && foto.isNotEmpty
                                      ? Image.network(
                                          foto,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, __, ___) =>
                                              _placeholderObra(context),
                                        )
                                      : _placeholderObra(context),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Chip(
                                    label: Text(
                                      _labelSituacaoObra(sid),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: _corSituacaoObra(sid),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.65),
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${obra['nome'] ?? ''}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.place_outlined,
                                                size: 14,
                                                color: Colors.white70),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${obra['cidade'] ?? 'Local não informado'}/${obra['estado'] ?? ''}',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _miniLinha(
                                      context,
                                      Icons.event_outlined,
                                      'Início',
                                      '${obra['data_inicio'] ?? '—'}'),
                                  _miniLinha(
                                      context,
                                      Icons.event_outlined,
                                      'Término',
                                      '${obra['data_final'] ?? '—'}'),
                                  _miniLinha(
                                      context,
                                      Icons.engineering_outlined,
                                      'Engenheiro',
                                      obra['engenheiro']?.toString() ??
                                          'Não informado'),
                                  _miniLinha(
                                      context,
                                      Icons.description_outlined,
                                      'Contrato',
                                      obra['contrato']?.toString() ??
                                          'Não informado'),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            TextButton.icon(
                              onPressed: () => _abrirObra(obra),
                              icon: const Icon(Icons.visibility_outlined,
                                  size: 18),
                              label: const Text('Detalhes'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderObra(BuildContext context) {
    return Container(
      color: FlutterFlowTheme.of(context).alternate,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 48, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _miniLinha(
      BuildContext context, IconData icon, String leg, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 14, color: FlutterFlowTheme.of(context).secondaryText),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leg, style: FlutterFlowTheme.of(context).labelSmall),
                Text(valor, style: FlutterFlowTheme.of(context).bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colInfo(BuildContext context, Map<String, dynamic> c, int juridica) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(context, Icons.badge_outlined, 'DOCUMENTO',
            _formatDocumento(c['documento']?.toString(), juridica)),
        _infoRow(context, Icons.wc_outlined, 'SEXO',
            _formatSexo(c['sexo']?.toString())),
        _infoRow(context, Icons.phone_outlined, 'TELEFONE',
            _formatTelefone(c['telefone']?.toString())),
        _infoRow(
          context,
          Icons.email_outlined,
          'E-MAIL',
          (c['email']?.toString().trim().isNotEmpty ?? false)
              ? c['email'].toString()
              : 'Não informado',
        ),
      ],
    );
  }

  Widget _colInfo2(BuildContext context, Map<String, dynamic> c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(context, Icons.place_outlined, 'ENDEREÇO', _formatEndereco(c)),
        _infoRow(
          context,
          Icons.notes_outlined,
          'OBSERVAÇÕES',
          (c['observacoes']?.toString().trim().isNotEmpty ?? false)
              ? c['observacoes'].toString()
              : 'Sem observações',
        ),
        _infoRow(context, Icons.calendar_today_outlined, 'CADASTRADO EM',
            _formatDate(c['created_at'])),
        _infoRow(context, Icons.update_outlined, 'ÚLTIMA ATUALIZAÇÃO',
            _formatDate(c['updated_at'])),
      ],
    );
  }

  Widget _infoRow(
      BuildContext context, IconData icon, String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: FlutterFlowTheme.of(context).primary),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: FlutterFlowTheme.of(context).labelMedium.override(
                      fontWeight: FontWeight.bold,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4),
            child: Text(
              valor,
              style: FlutterFlowTheme.of(context).bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
