import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_clientes')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar clientes.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
        return;
      }
      _carregar();
    });
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
    if (!MembershipAccess.canPermission('edit_clientes')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar clientes.',
      );
      return;
    }
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
    final theme = FlutterFlowTheme.of(context);
    final nome = '${_cliente?['nome'] ?? ''}'.trim();
    final canEdit = MembershipAccess.canPermission('edit_clientes');

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.primary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleSpacing: 0,
          toolbarHeight: 58,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.safePop(),
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalhes do cliente',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  nome.isEmpty ? 'Cadastro geral do sistema' : nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 21),
              onPressed: _carregando ? null : _carregar,
            ),
            if (canEdit && _cliente != null)
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 21),
                onPressed: _abrirEditar,
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _corpo(theme, canEdit)),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }

  Widget _corpo(FlutterFlowTheme theme, bool canEdit) {
    if (_carregando) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Carregando dados do cliente…',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.secondaryText,
              ),
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
              Icon(Icons.error_outline_rounded, size: 48, color: theme.error),
              const SizedBox(height: 12),
              Text(
                _erro!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _carregar,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Tentar novamente',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(180, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
    final obrasFiltradas = _obrasFiltradas;

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          kBarraNavegacaoPrincipalReservaScroll,
        ),
        children: [
          _buildResumoCard(theme, c, juridica, ativo),
          const SizedBox(height: 10),
          if (canEdit)
            RdoSectionCard(
              title: 'Ações',
              icon: Icons.tune_rounded,
              margin: const EdgeInsets.only(bottom: 10),
              child: FilledButton.icon(
                onPressed: _abrirEditar,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  'Editar cliente',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          RdoSectionCard(
            title: 'Dados pessoais',
            icon: Icons.badge_outlined,
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                _infoRow(
                  theme,
                  juridica == 1 ? 'CNPJ' : 'CPF',
                  _formatDocumento(c['documento']?.toString(), juridica),
                ),
                if (juridica != 1)
                  _infoRow(theme, 'Sexo', _formatSexo(c['sexo']?.toString())),
                _infoRow(
                  theme,
                  'Telefone',
                  _formatTelefone(c['telefone']?.toString()),
                ),
                _infoRow(
                  theme,
                  'E-mail',
                  (c['email']?.toString().trim().isNotEmpty ?? false)
                      ? c['email'].toString()
                      : 'Não informado',
                ),
              ],
            ),
          ),
          RdoSectionCard(
            title: 'Endereço e observações',
            icon: Icons.place_outlined,
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                _infoRow(theme, 'Endereço', _formatEndereco(c)),
                _infoRow(
                  theme,
                  'Observações',
                  (c['observacoes']?.toString().trim().isNotEmpty ?? false)
                      ? c['observacoes'].toString()
                      : 'Sem observações',
                ),
                _infoRow(
                  theme,
                  'Cadastrado em',
                  _formatDate(c['created_at']),
                ),
                _infoRow(
                  theme,
                  'Atualizado em',
                  _formatDate(c['updated_at']),
                ),
              ],
            ),
          ),
          RdoSectionCard(
            title: 'Obras do cliente',
            icon: Icons.apartment_outlined,
            subtitle: _buscaObra.text.trim().isEmpty
                ? (_obras.isEmpty
                    ? 'Nenhuma obra vinculada'
                    : 'Toque para abrir a obra')
                : '${obrasFiltradas.length} de ${_obras.length}',
            margin: EdgeInsets.zero,
            trailing: _obras.isEmpty ? null : RdoContadorChip('${_obras.length}'),
            contentPadding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    controller: _buscaObra,
                    style: rdoFormFieldTextStyle(context),
                    decoration: rdoFormFieldDecoration(
                      context,
                      label: 'Buscar obra',
                      hint: 'Nome, cidade, engenheiro ou contrato',
                      suffixIcon: _buscaObra.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar',
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: theme.secondaryText,
                              ),
                              onPressed: () {
                                _buscaObra.clear();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (obrasFiltradas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                    child: Column(
                      children: [
                        Icon(
                          Icons.business_center_outlined,
                          size: 40,
                          color: theme.secondaryText.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma obra encontrada',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _buscaObra.text.trim().isEmpty
                              ? 'Este cliente ainda não possui obras cadastradas.'
                              : 'Nenhuma obra corresponde à busca.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < obrasFiltradas.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.alternate,
                          ),
                        _buildObraItem(theme, obrasFiltradas[i]),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoCard(
    FlutterFlowTheme theme,
    Map<String, dynamic> c,
    int juridica,
    bool ativo,
  ) {
    final nome = '${c['nome'] ?? ''}'.trim();
    return RdoSectionCard(
      title: nome.isEmpty ? 'Cliente' : nome,
      subtitle: juridica == 1 ? 'Pessoa jurídica' : 'Pessoa física',
      icon: juridica == 1 ? Icons.domain_outlined : Icons.person_outline,
      margin: EdgeInsets.zero,
      trailing: _statusChip(theme, ativo, juridica),
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          RdoKpiStrip(
            itens: [
              RdoKpiData(label: 'Obras', value: '${_obras.length}'),
              RdoKpiData(
                label: 'Ativas',
                value: '${_countObras(1)}',
                destaque: true,
              ),
              RdoKpiData(label: 'Andamento', value: '${_countObras(2)}'),
              RdoKpiData(label: 'Concluídas', value: '${_countObras(3)}'),
            ],
          ),
          Divider(height: 1, color: theme.alternate),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.primary.withValues(alpha: 0.12),
                  child: Text(
                    _iniciais(nome),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: theme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDocumento(c['documento']?.toString(), juridica),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTelefone(c['telefone']?.toString()),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(FlutterFlowTheme theme, bool ativo, int juridica) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (ativo ? Colors.green.shade700 : Colors.red.shade700)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ativo ? 'Ativo' : 'Inativo',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ativo ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              juridica == 1 ? 'PJ' : 'PF',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObraItem(FlutterFlowTheme theme, Map<String, dynamic> obra) {
    final sid = _int(obra['situacao_id']);
    final foto = obra['foto_url']?.toString();
    final nome = '${obra['nome'] ?? ''}'.trim();
    final cidade = '${obra['cidade'] ?? ''}'.trim();
    final estado = '${obra['estado'] ?? ''}'.trim();
    final local = [
      if (cidade.isNotEmpty) cidade,
      if (estado.isNotEmpty) estado,
    ].join('/');
    final engenheiro = obra['engenheiro']?.toString().trim() ?? '';
    final contrato = obra['contrato']?.toString().trim() ?? '';

    return Material(
      color: theme.secondaryBackground,
      child: InkWell(
        onTap: () => _abrirObra(obra),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: _corSituacaoObra(sid)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: foto != null && foto.isNotEmpty
                              ? Image.network(
                                  foto,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholderObra(theme),
                                )
                              : _placeholderObra(theme),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    nome.isEmpty ? 'Obra sem nome' : nome,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: theme.primaryText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _corSituacaoObra(sid)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _labelSituacaoObra(sid),
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: _corSituacaoObra(sid),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              local.isEmpty ? 'Local não informado' : local,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: theme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (engenheiro.isNotEmpty) engenheiro,
                                if (contrato.isNotEmpty) 'Contrato $contrato',
                                'Início ${obra['data_inicio'] ?? '—'}',
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.secondaryText,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderObra(FlutterFlowTheme theme) {
    return Container(
      color: theme.primaryBackground,
      child: Icon(
        Icons.apartment_outlined,
        size: 24,
        color: theme.secondaryText.withValues(alpha: 0.45),
      ),
    );
  }

  Widget _infoRow(FlutterFlowTheme theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
