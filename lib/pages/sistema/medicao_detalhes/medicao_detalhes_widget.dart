import '/backend/api_requests/api_calls.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import 'medicao_detalhes_model.dart';

export 'medicao_detalhes_model.dart';

class MedicaoDetalhesWidget extends StatefulWidget {
  const MedicaoDetalhesWidget({
    super.key,
    this.medicaoId,
  });

  final int? medicaoId;

  static String routeName = 'medicaoDetalhes';
  static String routePath = '/medicaoDetalhes';

  @override
  State<MedicaoDetalhesWidget> createState() => _MedicaoDetalhesWidgetState();
}

class _MedicaoDetalhesWidgetState extends State<MedicaoDetalhesWidget>
    with SingleTickerProviderStateMixin {
  late MedicaoDetalhesModel _model;
  late AnimationController _animationController;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _medicao;
  Map<String, dynamic>? _fluxo;
  bool? _podeProcessarAssinatura;
  bool _fluxoCarregando = false;
  Map<String, dynamic>? _aprovadoresPayload;
  bool _aprovadoresLoading = false;
  bool _enviandoAprovacao = false;
  bool _processandoAssinatura = false;
  bool _pdfLoading = false;

  final Set<int> _expandedIds = {};

  static final _money = NumberFormat('#,##0.00', 'pt_BR');
  static final _qty = NumberFormat('#,##0.###', 'pt_BR');

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MedicaoDetalhesModel());
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _load();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.medicaoId;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Medição inválida.';
      });
      return;
    }

    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Faça login novamente.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final r = await MedicaoShowCall.call(token: token, medicaoId: id);
    if (!mounted) return;

    if (!r.succeeded || r.jsonBody is! Map) {
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar a medição (${r.statusCode}).';
      });
      return;
    }

    final body = r.jsonBody as Map<String, dynamic>;
    if (body['success'] != true || body['medicao'] is! Map) {
      setState(() {
        _loading = false;
        _error = (body['message'] ?? 'Medição não encontrada.').toString();
      });
      return;
    }

    final med = Map<String, dynamic>.from(body['medicao'] as Map);
    if (med['itens'] is! List) {
      med['itens'] = <dynamic>[];
    }

    if (!mounted) return;
    setState(() {
      _medicao = med;
      _fluxo = null;
      _podeProcessarAssinatura = null;
      _aprovadoresPayload = null;
      _loading = false;
      _error = null;
    });
    _preencherExpandidoInicial();
    await _carregarFluxoAprovacaoMedicao(id);
  }

  Future<void> _carregarFluxoAprovacaoMedicao(int medicaoId) async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty || !mounted) return;
    final d = _medicao;
    if (d == null) return;
    final sid = _toInt(d['status_id']) ?? 1;

    if (sid == 2) {
      setState(() {
        _fluxoCarregando = true;
        _fluxo = null;
        _podeProcessarAssinatura = null;
      });
      dynamic fluxo;
      final fx = await MedicaoFluxoAssinaturasCall.call(
        token: token,
        medicaoId: medicaoId,
      );
      if (fx.succeeded && fx.jsonBody is Map) {
        final m = Map<String, dynamic>.from(fx.jsonBody as Map);
        fluxo = m['fluxo'] ??
            (m['data'] is Map ? (m['data'] as Map)['fluxo'] : null);
      }
      if (fluxo == null) {
        final st = await AssinaturaMedicaoStatusCall.call(
          token: token,
          medicaoId: medicaoId,
        );
        if (st.succeeded && st.jsonBody is Map) {
          final m = Map<String, dynamic>.from(st.jsonBody as Map);
          final inner = m['data'];
          fluxo = inner is Map ? inner : m;
        }
      }
      bool? pode;
      final pp = await AssinaturaMedicaoPodeProcessarCall.call(
        token: token,
        medicaoId: medicaoId,
      );
      if (pp.succeeded && pp.jsonBody is Map) {
        pode =
            Map<String, dynamic>.from(pp.jsonBody as Map)['pode_processar'] ==
                true;
      } else {
        pode = false;
      }
      if (!mounted) return;
      setState(() {
        if (fluxo is Map) {
          _fluxo = Map<String, dynamic>.from(fluxo);
        } else {
          _fluxo = null;
        }
        _podeProcessarAssinatura = pode;
        _fluxoCarregando = false;
      });
    } else if (sid == 3) {
      setState(() {
        _aprovadoresLoading = true;
        _aprovadoresPayload = null;
      });
      Map<String, dynamic>? payload;
      final ap = await MedicaoAprovadoresCall.call(
        token: token,
        medicaoId: medicaoId,
      );
      if (ap.succeeded && ap.jsonBody is Map) {
        final m = Map<String, dynamic>.from(ap.jsonBody as Map);
        if (m['success'] == true || m['aprovadores'] != null) {
          payload = m;
        }
      }
      final listOk = payload != null &&
          payload['aprovadores'] is List &&
          (payload['aprovadores'] as List).isNotEmpty;
      if (!listOk) {
        final fx = await MedicaoFluxoAssinaturasCall.call(
          token: token,
          medicaoId: medicaoId,
        );
        if (fx.succeeded && fx.jsonBody is Map) {
          final m = Map<String, dynamic>.from(fx.jsonBody as Map);
          dynamic rawFluxo = m['fluxo'] ?? m['data'];
          Map<String, dynamic>? fluxoMap;
          if (rawFluxo is Map) {
            fluxoMap = Map<String, dynamic>.from(rawFluxo);
          } else if (m['assinaturas'] is List) {
            fluxoMap = m;
          }
          if (fluxoMap != null) {
            final assin = fluxoMap['assinaturas'];
            final aprovadores = <Map<String, dynamic>>[];
            if (assin is List) {
              for (final a in assin) {
                if (a is! Map) continue;
                final am = Map<String, dynamic>.from(a);
                final sn = am['situacao_numero'];
                final situacao = '${am['situacao']}'.toLowerCase();
                final aprovado = sn == 2 || situacao.contains('aprov');
                if (!aprovado) continue;
                final assinante = am['assinante'];
                var nome = 'N/A';
                if (assinante is Map) {
                  nome = '${assinante['nome'] ?? assinante['name'] ?? 'N/A'}';
                }
                aprovadores.add({
                  'nome': nome,
                  'cargo': am['cargo'],
                  'posicao': am['posicao'],
                  'data_assinatura': am['data_assinatura'] ?? am['created_at'],
                });
              }
            }
            aprovadores.sort(
              (a, b) => ((a['posicao'] as num?)?.toInt() ?? 999).compareTo(
                (b['posicao'] as num?)?.toInt() ?? 999,
              ),
            );
            DateTime? parseDt(dynamic v) {
              if (v == null) return null;
              return DateTime.tryParse(v.toString());
            }

            String? ultima;
            DateTime? best;
            for (final ap0 in aprovadores) {
              final dt = parseDt(ap0['data_assinatura']);
              if (dt != null && (best == null || dt.isAfter(best))) {
                best = dt;
                ultima = ap0['data_assinatura']?.toString();
              }
            }
            payload = {
              'aprovadores': aprovadores,
              'ultima_aprovacao': ultima,
            };
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _aprovadoresPayload = payload;
        _aprovadoresLoading = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _fluxo = null;
        _podeProcessarAssinatura = null;
        _fluxoCarregando = false;
        _aprovadoresPayload = null;
        _aprovadoresLoading = false;
      });
    }
  }

  String _str(dynamic v) {
    if (v == null) return '';
    return v.toString().trim();
  }

  String _apiErroMensagem(ApiCallResponse r) {
    final b = r.jsonBody;
    if (b is Map) {
      final m = b['message'] ?? b['error'];
      if (m != null && '$m'.trim().isNotEmpty) return '$m';
    }
    return 'Falha na requisição (HTTP ${r.statusCode}).';
  }

  String _formatDataHoraMini(dynamic raw) {
    final s = _str(raw);
    if (s.isEmpty) return '';
    var dt = DateTime.tryParse(s);
    if (dt == null && s.contains(' ') && !s.contains('T')) {
      dt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    }
    if (dt == null) return s;
    return dateTimeFormat('dd/MM/yyyy HH:mm', dt.toLocal(), locale: 'pt_BR');
  }

  String _iniciaisNome(String? nome) {
    final n = nome?.trim();
    if (n == null || n.isEmpty || n == 'N/A') return '??';
    final partes = n.split(RegExp(r'\s+'));
    if (partes.length == 1) {
      return partes[0].length >= 2
          ? partes[0].substring(0, 2).toUpperCase()
          : '${partes[0]}?'.toUpperCase();
    }
    final a = partes.first.isNotEmpty ? partes.first[0] : '';
    final b = partes.last.isNotEmpty ? partes.last[0] : '';
    return ('$a$b').toUpperCase();
  }

  String _cargoPorPosicao(dynamic pos) {
    final p = pos is num ? pos.toInt() : int.tryParse('$pos') ?? 0;
    const cargos = {
      1: 'Engenheiro Responsável',
      2: 'Coordenador de Obra',
      3: 'Gestor de Contrato',
      4: 'Diretor de Obras',
      5: 'Cliente',
      6: 'Fiscal',
    };
    return cargos[p] ?? 'Aprovador Nº $p';
  }

  String _cargoExibicao(Map<String, dynamic> a) {
    final c = _str(a['cargo']);
    if (c.isNotEmpty) {
      final low = c.toLowerCase().replaceAll('.', '');
      const inv = {'nd', 'n/d', 'na', 'n/a', 'n-a'};
      if (!inv.contains(low)) return c;
    }
    return _cargoPorPosicao(a['posicao']);
  }

  String _hashCarimbo(dynamic medicaoId, dynamic ultima) {
    final s =
        'MED-${medicaoId ?? '0'}-${ultima ?? DateTime.now().toIso8601String()}';
    final b = base64Encode(utf8.encode(s));
    return b.length >= 8 ? b.substring(0, 8) : b;
  }

  Future<void> _onImprimirPdf() async {
    final id = widget.medicaoId;
    final m = _medicao;
    if (id == null || m == null) return;
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    setState(() => _pdfLoading = true);
    final nome = 'medicao-${m['numero'] ?? id}';
    final path = await MedicaoExportarPdf.downloadToTemp(
      token: token,
      medicaoId: id,
      baseFileName: nome,
    );
    if (!mounted) return;
    setState(() => _pdfLoading = false);
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
                : 'Não foi possível abrir o PDF. Arquivo em: $path',
          ),
        ),
      );
    }
  }

  Future<void> _onEnviarParaAprovacao() async {
    final id = widget.medicaoId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar para aprovação'),
        content: const Text(
          'A medição passará para o status "Em aprovação" e os aprovadores serão notificados. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _enviandoAprovacao = true);
    final token = FFAppState().UserToken.trim();
    final r =
        await MedicaoEnviarAprovacaoCall.call(token: token, medicaoId: id);
    if (!mounted) return;
    setState(() => _enviandoAprovacao = false);
    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medição enviada para aprovação.')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  Future<void> _onSolicitarRevogacao() async {
    final id = widget.medicaoId;
    if (id == null) return;
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Solicitar revogação'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'Mínimo 10 caracteres',
            ),
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Solicitar'),
            ),
          ],
        );
      },
    );
    if (motivo == null || motivo.length < 10) {
      if (motivo != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informe um motivo (mín. 10 caracteres).'),
          ),
        );
      }
      return;
    }
    final token = FFAppState().UserToken.trim();
    final r = await MedicaoSolicitarRevogacaoCall.call(
      token: token,
      medicaoId: id,
      motivoRevogacao: motivo,
    );
    if (!mounted) return;
    if (r.succeeded) {
      var msg = 'Solicitação enviada.';
      if (r.jsonBody is Map && (r.jsonBody as Map)['message'] != null) {
        msg = '${(r.jsonBody as Map)['message']}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  Future<void> _onDecidirRevogacao({
    required bool aprovar,
    required String revogacaoUuid,
  }) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text(aprovar ? 'Aprovar revogação' : 'Rejeitar revogação'),
          content: TextField(
            controller: c,
            decoration: InputDecoration(
              labelText: aprovar ? 'Motivo (opcional)' : 'Motivo *',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: Text(aprovar ? 'Aprovar' : 'Rejeitar'),
            ),
          ],
        );
      },
    );
    if (motivo == null) return;
    if (!aprovar && motivo.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informe um motivo (mín. 3 caracteres).'),
          ),
        );
      }
      return;
    }
    final token = FFAppState().UserToken.trim();
    final r = aprovar
        ? await MedRevogacaoAprovarCall.call(
            token: token,
            revogacaoUuid: revogacaoUuid,
            motivo: motivo,
          )
        : await MedRevogacaoRejeitarCall.call(
            token: token,
            revogacaoUuid: revogacaoUuid,
            motivo: motivo,
          );
    if (!mounted) return;
    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r.jsonBody is Map && (r.jsonBody as Map)['message'] != null
                ? '${(r.jsonBody as Map)['message']}'
                : (aprovar ? 'Revogação aprovada.' : 'Revogação rejeitada.'),
          ),
        ),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  Future<void> _onAprovarAssinatura() async {
    final id = widget.medicaoId;
    if (id == null) return;
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprovar medição'),
        content: const Text(
          'Confirma a aprovação desta etapa? A medição seguirá para o próximo aprovador ou será concluída na última assinatura.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );
    if (conf != true || !mounted) return;
    setState(() => _processandoAssinatura = true);
    final token = FFAppState().UserToken.trim();
    final r = await AssinaturaMedicaoAprovarCall.call(
      token: token,
      medicaoId: id,
    );
    if (!mounted) return;
    setState(() => _processandoAssinatura = false);
    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aprovação registrada.')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  Future<void> _onReprovarAssinatura() async {
    final id = widget.medicaoId;
    if (id == null) return;
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Reprovar medição'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'Descreva o motivo da reprovação',
            ),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    if (motivo == null || motivo.length < 3) {
      if (motivo != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informe um motivo (mín. 3 caracteres).'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _processandoAssinatura = true);
    final token = FFAppState().UserToken.trim();
    final r = await AssinaturaMedicaoReprovarCall.call(
      token: token,
      medicaoId: id,
      motivo: motivo,
    );
    if (!mounted) return;
    setState(() => _processandoAssinatura = false);
    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medição reprovada.')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  double _toDouble(dynamic v) {
    if (v == null || v == '-') return 0;
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  String _obraNome() {
    final m = _medicao;
    if (m == null) return '';
    final on = m['obra_nome']?.toString().trim();
    if (on != null && on.isNotEmpty) return on;
    final o = m['obra'];
    if (o is Map) {
      final n = o['nome']?.toString().trim();
      if (n != null && n.isNotEmpty) return n;
    }
    return 'Obra';
  }

  String _formatData(dynamic raw) {
    if (raw == null) return '—';
    final s = raw.toString().trim();
    if (s.isEmpty) return '—';
    var dt = DateTime.tryParse(s);
    if (dt == null && s.contains(' ') && !s.contains('T')) {
      dt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    }
    if (dt == null) {
      if (s.length >= 10) {
        return s.substring(0, 10).split('-').reversed.join('/');
      }
      return s;
    }
    return dateTimeFormat('dd/MM/yyyy', dt.toLocal(), locale: 'pt_BR');
  }

  String _formatMesRef(dynamic raw) {
    if (raw == null) return '—';
    final s = raw.toString().trim();
    if (s.length >= 7) {
      final p = s.substring(0, 7).split('-');
      if (p.length == 2) return '${p[1]}/${p[0]}';
    }
    return s;
  }

  String _labelStatusMedicao() {
    final m = _medicao;
    if (m == null) return '—';
    final sid = _toInt(m['status_id']);
    if (sid != null) {
      switch (sid) {
        case 1:
          return 'Preenchendo';
        case 2:
          return 'Em aprovação';
        case 3:
          return 'Aprovada';
        case 4:
          return 'Reprovado';
      }
    }
    final st = m['status']?.toString() ?? '';
    return st.isEmpty ? '—' : st.replaceAll('_', ' ');
  }

  Color _statusMedicaoChipColor(FlutterFlowTheme theme) {
    final m = _medicao;
    if (m == null) return theme.primary;
    final sid = _toInt(m['status_id']);
    switch (sid) {
      case 1:
        return const Color(0xFF2196F3);
      case 2:
        return const Color(0xFF6200EE);
      case 3:
        return const Color(0xFF4CAF50);
      case 4:
        return const Color(0xFFE53935);
      default:
        return theme.primary;
    }
  }

  List<Map<String, dynamic>> _allItens() {
    final m = _medicao;
    if (m == null) return [];
    final raw = m['itens'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _sortedItens() {
    final list = _allItens();
    int cmpEdt(String a, String b) {
      final ap = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final bp = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      for (var i = 0;
          i < (ap.length > bp.length ? ap.length : bp.length);
          i++) {
        final av = i < ap.length ? ap[i] : 0;
        final bv = i < bp.length ? bp[i] : 0;
        if (av != bv) return av.compareTo(bv);
      }
      return 0;
    }

    list.sort((a, b) => cmpEdt(
          '${a['codigo_edt'] ?? ''}',
          '${b['codigo_edt'] ?? ''}',
        ));
    return list;
  }

  /// Código do item pai a partir do EDT (ex. `1.2.3` -> `1.2`). A API não envia `parent_id` na tabela.
  String? _parentCodigoEdt(String codigo) {
    final t = codigo.trim();
    if (t.isEmpty) return null;
    final i = t.lastIndexOf('.');
    if (i <= 0) return null;
    return t.substring(0, i);
  }

  /// Para resolver pai por EDT em O(1).
  Map<String, int> _mapaEdtParaIdItem(List<Map<String, dynamic>> all) {
    final m = <String, int>{};
    for (final it in all) {
      final edt = '${it['codigo_edt'] ?? ''}'.trim();
      final id = _toInt(it['id']);
      if (edt.isEmpty || id == null) continue;
      m.putIfAbsent(edt, () => id);
    }
    return m;
  }

  /// Pai: `parentId` da API, prefixo de EDT, ou tarefa ligada à etapa pelo mesmo `obra_etapa_id`.
  int? _idPaiDeItem(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> all,
    Map<String, int> edtToId,
  ) {
    final ex = _toInt(item['parentId']) ?? _toInt(item['parent_id']);
    if (ex != null && all.any((e) => _toInt(e['id']) == ex)) {
      return ex;
    }
    final pEdt = _parentCodigoEdt('${item['codigo_edt'] ?? ''}');
    if (pEdt != null) {
      final fromEdt = edtToId[pEdt];
      if (fromEdt != null) return fromEdt;
    }
    if ((item['tipo'] ?? '').toString() == 'tarefa') {
      final oei = _toInt(item['obra_etapa_id']);
      if (oei != null) {
        for (final e in all) {
          if ((e['tipo'] ?? '').toString() == 'etapa' &&
              _toInt(e['obra_etapa_id']) == oei) {
            return _toInt(e['id']);
          }
        }
      }
    }
    return pEdt != null ? edtToId[pEdt] : null;
  }

  int _depthEdt(String codigo) {
    final t = codigo.trim();
    if (t.isEmpty) return 0;
    return t.split('.').where((e) => e.isNotEmpty).length - 1;
  }

  bool _temFilhos(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> all,
    Map<String, int> edtToId,
  ) {
    final id = _toInt(item['id']);
    if (id == null) return false;
    for (final i in all) {
      if (_idPaiDeItem(i, all, edtToId) == id) return true;
    }
    return false;
  }

  bool _isItemVisivel(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> all,
    Map<String, int> edtToId,
  ) {
    var cur = item;
    for (var g = 0; g < 48; g++) {
      final pid = _idPaiDeItem(cur, all, edtToId);
      if (pid == null) return true;
      if (!_expandedIds.contains(pid)) return false;
      final idx = all.indexWhere((e) => _toInt(e['id']) == pid);
      if (idx < 0) return true;
      cur = all[idx];
    }
    return true;
  }

  Map<String, double> _totaisRodape(List<Map<String, dynamic>> all) {
    double qOrc = 0, qAcum = 0, qReal = 0, vAtual = 0, vAcum = 0, vSaldo = 0;
    for (final item in all) {
      if ((item['tipo'] ?? '').toString() == 'etapa') continue;
      qOrc += _toDouble(item['quantidade_orcada']);
      qAcum += _toDouble(item['quantidade_acumulada_atual']);
      final qr = item['quantidade_realizada_mes'];
      if (qr != null && qr != '-') qReal += _toDouble(qr);
      vAtual += _toDouble(item['valor_realizado_mes']);
      vAcum += _toDouble(item['valor_acumulado']);
      vSaldo += _toDouble(item['saldo_valor']);
    }
    return {
      'qOrc': qOrc,
      'qAcum': qAcum,
      'qReal': qReal,
      'vAtual': vAtual,
      'vAcum': vAcum,
      'vSaldo': vSaldo,
    };
  }

  void _expandirTudo() {
    final all = _sortedItens();
    final edtToId = _mapaEdtParaIdItem(all);
    setState(() {
      for (final it in all) {
        if (_temFilhos(it, all, edtToId)) {
          final id = _toInt(it['id']);
          if (id != null) _expandedIds.add(id);
        }
      }
    });
  }

  void _colapsarTudo() {
    setState(() => _expandedIds.clear());
  }

  /// Após o load, reabre todos os ramos (itens pais) para a lista não parecer vazia de primeiro nível.
  void _preencherExpandidoInicial() {
    if (!mounted) return;
    final all = _sortedItens();
    final m = _mapaEdtParaIdItem(all);
    setState(() {
      _expandedIds.clear();
      for (final it in all) {
        if (_temFilhos(it, all, m)) {
          final id = _toInt(it['id']);
          if (id != null) _expandedIds.add(id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        appBar: _buildAppBar(theme),
        body: FadeTransition(
          opacity: _animationController,
          child: _buildBody(theme),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(FlutterFlowTheme theme) {
    final m = _medicao;
    final numero = m != null ? '${m['numero'] ?? ''}'.trim() : '';
    final obraNome = _obraNome();
    final subtitulo = [
      if (numero.isNotEmpty) 'Medição #$numero',
      if (obraNome.isNotEmpty && obraNome != 'Obra') obraNome,
    ].join(' · ');

    return AppBar(
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
              'Detalhes da Medição',
              style: GoogleFonts.interTight(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              subtitulo.isEmpty ? 'Medição' : subtitulo,
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
          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 21),
          onPressed: _loading ? null : _load,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody(FlutterFlowTheme theme) {
    if (_loading) return _buildLoadingState(theme);
    if (_error != null) return _buildErrorState(theme);
    if (_medicao == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _load,
      color: theme.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ..._buildRevogacaoWidgets(theme),
                ..._buildHistoricoRevogacoes(theme),
                _buildResumoCard(theme),
                const SizedBox(height: 10),
                _buildBarraAcoesMedicao(theme),
                _buildItensSection(theme),
                const SizedBox(height: 10),
                _buildAssinaturasSection(theme),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(FlutterFlowTheme theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: theme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Carregando medição…',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(FlutterFlowTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: theme.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  List<Widget> _buildRevogacaoWidgets(FlutterFlowTheme theme) {
    final m = _medicao;
    if (m == null) return [];
    final rev = m['revogacao_ativa'];
    if (rev is! Map) return [];
    final r = Map<String, dynamic>.from(rev);
    final assinaturas = r['assinaturas'];
    final list = assinaturas is List ? assinaturas : const [];
    final uuid = '${r['uuid'] ?? ''}'.trim();
    final podeDecidir = m['usuario_pode_decidir_revogacao'] == true;

    return [
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        decoration: rdoCardDecoration(context).copyWith(
          border: Border.all(color: theme.warning.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: theme.warning.withValues(alpha: 0.08),
                border: Border(bottom: BorderSide(color: theme.warning.withValues(alpha: 0.25))),
              ),
              child: Row(
                children: [
                  Icon(Icons.gavel_rounded, size: 16, color: theme.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Revogação em andamento',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Solicitante', '${r['solicitante'] ?? '—'}'),
                  _buildInfoRow('Data', _formatData(r['data_solicitacao'])),
                  _buildInfoRow('Motivo', '${r['motivo'] ?? '—'}'),
                  if (list.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Assinaturas',
                      style: rdoColumnLabelStyle(context),
                    ),
                    const SizedBox(height: 4),
                    ...list.map((raw) {
                      if (raw is! Map) return const SizedBox.shrink();
                      final a = Map<String, dynamic>.from(raw);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              a['status'] == 'Decidido'
                                  ? (a['decisao'] == 'Aprovou'
                                      ? Icons.check_circle_outline
                                      : Icons.cancel_outlined)
                                  : Icons.schedule,
                              size: 18,
                              color: a['status'] == 'Decidido'
                                  ? (a['decisao'] == 'Aprovou'
                                      ? Colors.green
                                      : Colors.red)
                                  : theme.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${a['posicao'] ?? ''}º ${a['assinante'] ?? ''}',
                                style: GoogleFonts.inter(fontSize: 12.5),
                              ),
                            ),
                            if (a['decisao'] != null)
                              Text(
                                '${a['decisao']}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: a['decisao'] == 'Aprovou'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (podeDecidir && uuid.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.check_rounded,
                            label: 'Aprovar',
                            onPressed: () => _onDecidirRevogacao(
                              aprovar: true,
                              revogacaoUuid: uuid,
                            ),
                            backgroundColor: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.close_rounded,
                            label: 'Rejeitar',
                            onPressed: () => _onDecidirRevogacao(
                              aprovar: false,
                              revogacaoUuid: uuid,
                            ),
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
    required Color backgroundColor,
    Color foregroundColor = Colors.white,
    bool outlined = false,
  }) {
    final borderRadius = BorderRadius.circular(8);
    final child = loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foregroundColor,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(color: foregroundColor.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      child: child,
    );
  }

  List<Widget> _buildHistoricoRevogacoes(FlutterFlowTheme theme) {
    final m = _medicao;
    if (m == null) return [];
    final hist = m['historico_revogacoes'];
    if (hist is! List || hist.isEmpty) return [];

    return [
      RdoSectionCard(
        title: 'Histórico de revogações',
        icon: Icons.history_rounded,
        margin: const EdgeInsets.only(bottom: 10),
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(
          children: hist.map((raw) {
            if (raw is! Map) return const SizedBox.shrink();
            final h = Map<String, dynamic>.from(raw);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: 18, color: theme.secondaryText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${h['solicitante'] ?? ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${h['motivo'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          _getStatusColor(h['status']).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${h['status'] ?? ''}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(h['status']),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    ];
  }

  Color _getStatusColor(dynamic status) {
    final s = _str(status).toLowerCase();
    if (s.contains('aprov')) return Colors.green;
    if (s.contains('rejeit')) return Colors.red;
    return Colors.orange;
  }

  Widget _buildResumoCard(FlutterFlowTheme theme) {
    final m = _medicao!;
    final statusCor = _statusMedicaoChipColor(theme);
    final periodo =
        '${_formatData(m['data_inicio_periodo'])} — ${_formatData(m['data_termino_periodo'])}';

    return RdoSectionCard(
      title: 'Resumo',
      icon: Icons.receipt_long_outlined,
      margin: const EdgeInsets.only(bottom: 10),
      contentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            decoration: BoxDecoration(
              color: theme.primaryBackground.withValues(alpha: 0.5),
              border: Border(bottom: BorderSide(color: theme.alternate)),
            ),
            child: Row(
              children: [
                Icon(Icons.apartment_rounded,
                    size: 16, color: theme.secondaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _obraNome(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusCor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _labelStatusMedicao(),
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: statusCor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          RdoKpiStrip(
            itens: [
              RdoKpiData(
                label: 'Mês ref.',
                value: _formatMesRef(m['mes_referencia']),
              ),
              RdoKpiData(
                label: 'Período',
                value: periodo,
                flex: 3,
              ),
              RdoKpiData(
                label: '% físico',
                value:
                    '${_toDouble(m['percentual_fisico_acumulado']).toStringAsFixed(1)}%',
                destaque: true,
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.alternate)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: RdoKpiStrip(
                      itens: [
                        RdoKpiData(
                          label: 'R\$ acumulado',
                          value:
                              'R\$ ${_money.format(_toDouble(m['valor_acumulado']))}',
                          flex: 2,
                        ),
                        RdoKpiData(
                          label: 'R\$ mês',
                          value:
                              'R\$ ${_money.format(_toDouble(m['valor_realizado']))}',
                          flex: 2,
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, color: theme.alternate),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Center(child: _buildPdfResumoButton(theme)),
                  ),
                ],
              ),
            ),
          ),
          if ((m['observacoes'] ?? '').toString().trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.alternate)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OBSERVAÇÕES',
                    style: rdoColumnLabelStyle(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m['observacoes'].toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: theme.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPdfResumoButton(FlutterFlowTheme theme) {
    return OutlinedButton(
      onPressed: _pdfLoading ? null : _onImprimirPdf,
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: theme.primary.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _pdfLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.primary,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf_outlined,
                    size: 16, color: theme.primary),
                const SizedBox(height: 2),
                Text(
                  'PDF',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBarraAcoesMedicao(FlutterFlowTheme theme) {
    final m = _medicao!;
    final sid = _toInt(m['status_id']);
    final podeRevogar = m['pode_solicitar_revogacao'] == true;
    if (sid != 1 && !podeRevogar) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sid == 1)
          RdoSectionCard(
            title: 'Enviar para Aprovação',
            icon: Icons.send_rounded,
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Quando a medição estiver pronta, envie para o fluxo de assinaturas.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                _buildActionButton(
                  icon: Icons.send_rounded,
                  label: _enviandoAprovacao
                      ? 'Enviando...'
                      : 'Enviar para aprovação',
                  onPressed:
                      _enviandoAprovacao ? null : _onEnviarParaAprovacao,
                  loading: _enviandoAprovacao,
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                ),
              ],
            ),
          ),
        if (podeRevogar)
          RdoSectionCard(
            title: 'Revogar aprovação',
            icon: Icons.settings_backup_restore_rounded,
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Solicite a revogação desta medição (em aprovação ou aprovada) para reabrir o fluxo.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                _buildActionButton(
                  icon: Icons.settings_backup_restore_rounded,
                  label: 'Revogar aprovação',
                  onPressed: _onSolicitarRevogacao,
                  backgroundColor: Colors.orange.withValues(alpha: 0.08),
                  foregroundColor: Colors.orange.shade800,
                  outlined: true,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildItensSection(FlutterFlowTheme theme) {
    final all = _sortedItens();
    final edtToId = _mapaEdtParaIdItem(all);
    final visiveis =
        all.where((it) => _isItemVisivel(it, all, edtToId)).toList();
    final tot = _totaisRodape(all);

    int cnt(String tipo) => all.where((i) => (i['tipo'] ?? '') == tipo).length;
    final nEtapas = cnt('etapa');
    final nTarefas = cnt('tarefa');

    return RdoSectionCard(
      title: 'Itens da medição',
      icon: Icons.account_tree_outlined,
      margin: const EdgeInsets.only(bottom: 10),
      subtitle: nEtapas > 0 || nTarefas > 0
          ? '$nEtapas etapas · $nTarefas tarefas'
          : null,
      trailing: all.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RdoContadorChip('${all.length}'),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: 'Expandir tudo',
                  onPressed: _expandirTudo,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    Icons.unfold_more_rounded,
                    size: 18,
                    color: theme.primary,
                  ),
                ),
                IconButton(
                  tooltip: 'Recolher tudo',
                  onPressed: _colapsarTudo,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    Icons.unfold_less_rounded,
                    size: 18,
                    color: theme.primary,
                  ),
                ),
              ],
            ),
      contentPadding: EdgeInsets.zero,
      child: visiveis.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 36,
                    color: theme.secondaryText.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nenhum item nesta medição.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.secondaryText,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < visiveis.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, color: theme.alternate),
                  _buildItemMedicaoRow(
                    theme,
                    visiveis[i],
                    all: all,
                    edtToId: edtToId,
                  ),
                ],
                Container(
                  decoration: BoxDecoration(
                    color: theme.primaryBackground.withValues(alpha: 0.55),
                    border: Border(top: BorderSide(color: theme.alternate)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Text(
                          'TOTAIS (SEM ETAPAS)',
                          style: rdoColumnLabelStyle(context),
                        ),
                      ),
                      RdoKpiStrip(
                        itens: [
                          RdoKpiData(
                            label: 'Q.mês',
                            value: _qty.format(tot['qReal']!),
                          ),
                          RdoKpiData(
                            label: 'R\$ mês',
                            value: 'R\$ ${_money.format(tot['vAtual']!)}',
                            flex: 2,
                            destaque: true,
                          ),
                          RdoKpiData(
                            label: 'R\$ acum.',
                            value: 'R\$ ${_money.format(tot['vAcum']!)}',
                            flex: 2,
                          ),
                        ],
                      ),
                      Divider(height: 1, color: theme.alternate),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Q.orç ${_qty.format(tot['qOrc']!)} · Q.acum ${_qty.format(tot['qAcum']!)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.secondaryText,
                                ),
                              ),
                            ),
                            Text(
                              'Saldo R\$ ${_money.format(tot['vSaldo']!)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.primary,
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

  /// Cores por nível EDT: 1º (depth 0), 2º (1), 3º+ (2…).
  ({Color bg, Color accent, Color badgeBg, Color badgeFg}) _coresNivelHierarquia(
    FlutterFlowTheme theme,
    int depth,
  ) {
    switch (depth) {
      case 0:
        return (
          bg: theme.primary.withValues(alpha: 0.06),
          accent: theme.primary,
          badgeBg: theme.primary.withValues(alpha: 0.14),
          badgeFg: theme.primary,
        );
      case 1:
        return (
          bg: const Color(0xFF5C6BC0).withValues(alpha: 0.07),
          accent: const Color(0xFF5C6BC0),
          badgeBg: const Color(0xFF5C6BC0).withValues(alpha: 0.14),
          badgeFg: const Color(0xFF3949AB),
        );
      default:
        return (
          bg: const Color(0xFF00897B).withValues(alpha: 0.06),
          accent: const Color(0xFF00897B),
          badgeBg: const Color(0xFF00897B).withValues(alpha: 0.12),
          badgeFg: const Color(0xFF00695C),
        );
    }
  }

  Widget _buildItemMedicaoRow(
    FlutterFlowTheme theme,
    Map<String, dynamic> it, {
    required List<Map<String, dynamic>> all,
    required Map<String, int> edtToId,
  }) {
    final id = _toInt(it['id']);
    final edt = '${it['codigo_edt'] ?? ''}'.trim();
    final depth = _depthEdt(edt).clamp(0, 6);
    final isRoot = depth == 0 || _idPaiDeItem(it, all, edtToId) == null;
    final nivel = isRoot ? 0 : depth;
    final cores = _coresNivelHierarquia(theme, nivel);
    final isEtapa = (it['tipo'] ?? '').toString() == 'etapa';
    final desc = '${it['descricao'] ?? ''}'.trim();
    final un = '${it['unidade'] ?? ''}'.trim();
    final tem = id != null && _temFilhos(it, all, edtToId);
    final aberto = id != null && _expandedIds.contains(id);
    final indent = 10.0 + (nivel * 14.0);

    final qMesRaw = it['quantidade_realizada_mes'];
    final qMes = qMesRaw == '-' || qMesRaw == null
        ? '—'
        : _qty.format(_toDouble(qMesRaw));

    void toggle() {
      if (id == null || !tem) return;
      setState(() {
        if (_expandedIds.contains(id)) {
          _expandedIds.remove(id);
        } else {
          _expandedIds.add(id);
        }
      });
    }

    return Material(
      color: cores.bg,
      child: InkWell(
        onTap: tem ? toggle : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: cores.accent),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(indent, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: tem
                                ? Icon(
                                    aberto
                                        ? Icons.expand_more_rounded
                                        : Icons.chevron_right_rounded,
                                    size: 20,
                                    color: cores.accent,
                                  )
                                : Icon(
                                    isEtapa
                                        ? Icons.folder_outlined
                                        : Icons.circle,
                                    size: isEtapa ? 16 : 6,
                                    color: isEtapa
                                        ? cores.accent.withValues(alpha: 0.75)
                                        : theme.secondaryText
                                            .withValues(alpha: 0.45),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          if (edt.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cores.badgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                edt,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cores.badgeFg,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              desc.isEmpty ? '—' : desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isRoot
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: theme.primaryText,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isEtapa
                                  ? theme.primary.withValues(alpha: 0.1)
                                  : theme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isEtapa ? 'Etapa' : 'Tarefa',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color:
                                    isEtapa ? theme.primary : theme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isEtapa) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (un.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  un,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildItemMetricChip(
                                    theme,
                                    'Q.orç',
                                    _qty.format(
                                      _toDouble(it['quantidade_orcada']),
                                    ),
                                  ),
                                  _buildItemMetricChip(
                                    theme,
                                    'Q.acum',
                                    _qty.format(
                                      _toDouble(
                                        it['quantidade_acumulada_atual'],
                                      ),
                                    ),
                                  ),
                                  _buildItemMetricChip(
                                    theme,
                                    'Q.mês',
                                    qMes,
                                    destaque: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                          decoration: BoxDecoration(
                            color: theme.secondaryBackground
                                .withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.alternate),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildItemMoneyCell(
                                  theme,
                                  'R\$ mês',
                                  _money.format(
                                    _toDouble(it['valor_realizado_mes']),
                                  ),
                                  destaque: true,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: theme.alternate,
                              ),
                              Expanded(
                                child: _buildItemMoneyCell(
                                  theme,
                                  'R\$ acum.',
                                  _money.format(
                                    _toDouble(it['valor_acumulado']),
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: theme.alternate,
                              ),
                              Expanded(
                                child: _buildItemMoneyCell(
                                  theme,
                                  'Saldo',
                                  _money.format(
                                    _toDouble(it['saldo_valor']),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_toDouble(it['valor_acumulado']) != 0 ||
                          _toDouble(it['valor_realizado_mes']) != 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildItemMetricChip(
                                theme,
                                'R\$ mês',
                                'R\$ ${_money.format(_toDouble(it['valor_realizado_mes']))}',
                                destaque: true,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildItemMetricChip(
                                theme,
                                'R\$ acum.',
                                'R\$ ${_money.format(_toDouble(it['valor_acumulado']))}',
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildItemMetricChip(
    FlutterFlowTheme theme,
    String label,
    String value, {
    bool destaque = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: destaque
            ? theme.primary.withValues(alpha: 0.08)
            : theme.secondaryBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: destaque
              ? theme.primary.withValues(alpha: 0.22)
              : theme.alternate,
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.secondaryText,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: destaque ? theme.primary : theme.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemMoneyCell(
    FlutterFlowTheme theme,
    String label,
    String value, {
    bool destaque = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'R\$ $value',
              maxLines: 1,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: destaque ? theme.primary : theme.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssinaturasSection(FlutterFlowTheme theme) {
    final m = _medicao!;
    final sid = _toInt(m['status_id']);
    final assinaturasRaw = m['assinaturas'];
    final listaAssin = assinaturasRaw is List ? assinaturasRaw : const [];
    final nAssin = listaAssin.length;
    final showCard = nAssin > 0 || sid == 2 || sid == 3;
    if (!showCard) return const SizedBox.shrink();

    String? subtitle;
    if (sid == 2) {
      subtitle = 'Aguardando aprovação na fila';
    } else if (sid == 3) {
      subtitle = 'Medição aprovada';
    }

    Widget inner;
    if (sid == 2) {
      inner = _buildFluxoMedicaoBody(theme);
    } else if (sid == 3) {
      inner = _buildCarimboMedicaoBody(theme, m);
    } else {
      inner = _buildListaAssinaturasSimplesMedicao(theme, listaAssin);
    }

    final contagem = sid == 2
        ? (_fluxo is Map && (_fluxo!['assinaturas'] is List)
            ? (_fluxo!['assinaturas'] as List).length
            : null)
        : (sid == 3
            ? (_aprovadoresPayload?['aprovadores'] is List
                ? (_aprovadoresPayload!['aprovadores'] as List).length
                : null)
            : nAssin);

    return RdoSectionCard(
      title: 'Assinaturas',
      subtitle: subtitle,
      icon: Icons.draw_outlined,
      margin: const EdgeInsets.only(bottom: 10),
      trailing: contagem != null && contagem > 0
          ? RdoContadorChip('$contagem')
          : null,
      contentPadding: EdgeInsets.zero,
      child: inner,
    );
  }

  Widget _buildListaAssinaturasSimplesMedicao(
    FlutterFlowTheme theme,
    List lista,
  ) {
    if (lista.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Text(
          'Nenhuma assinatura registrada.',
          style: GoogleFonts.inter(fontSize: 13, color: theme.secondaryText),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < lista.length; i++) ...[
          if (i > 0)
            Divider(height: 1, thickness: 1, color: theme.alternate),
          _buildLinhaAssinaturaCompacta(
            theme,
            Map<String, dynamic>.from(lista[i] as Map),
          ),
        ],
      ],
    );
  }

  Widget _buildLinhaAssinaturaCompacta(
    FlutterFlowTheme theme,
    Map<String, dynamic> a,
  ) {
    final nome = a['assinante'] is Map
        ? (a['assinante'] as Map)['nome']?.toString()
        : a['assinante']?.toString();
    final pos = a['posicao'];
    final sit = '${a['situacao'] ?? a['status_texto'] ?? '—'}';
    final data = a['data_assinatura'];
    final sitLower = sit.toLowerCase();
    Color cor = theme.secondaryText;
    IconData icone = Icons.person_outline_rounded;
    if (sitLower.contains('aprov')) {
      cor = theme.success;
      icone = Icons.check_circle_rounded;
    } else if (sitLower.contains('reprov') || sitLower.contains('rejeit')) {
      cor = theme.error;
      icone = Icons.cancel_rounded;
    } else if (sitLower.contains('aguard') || sitLower.contains('pend')) {
      cor = theme.warning;
      icone = Icons.hourglass_top_rounded;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${pos ?? '—'}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (nome ?? '').trim().isEmpty ? '—' : nome!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                if (data != null)
                  Text(
                    _formatDataHoraMini(data),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cor.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 12, color: cor),
                const SizedBox(width: 4),
                Text(
                  sit,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: cor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluxoMedicaoBody(FlutterFlowTheme theme) {
    if (_fluxoCarregando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    final fluxoMap =
        _fluxo is Map ? Map<String, dynamic>.from(_fluxo as Map) : null;
    final assinaturas = fluxoMap == null ? null : fluxoMap['assinaturas'];
    final lista = assinaturas is List ? assinaturas : const [];
    final prox = fluxoMap == null ? null : fluxoMap['proximo'];
    final proxNome = prox is Map ? _str(prox['nome']) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            child: Text(
              'Não foi possível carregar a fila de aprovadores. Atualize a tela.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.secondaryText,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              children: [
                for (var i = 0; i < lista.length; i++)
                  if (lista[i] is Map)
                    _buildLinhaFluxoMedicao(
                      theme,
                      Map<String, dynamic>.from(lista[i] as Map),
                      isLast: i == lista.length - 1,
                    ),
              ],
            ),
          ),
        if (proxNome.isNotEmpty && _podeProcessarAssinatura != true)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: theme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Próximo na fila: $proxNome',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_podeProcessarAssinatura == true) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryBackground.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'SUA DECISÃO',
                  style: rdoColumnLabelStyle(context),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.success,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: const Size(0, 38),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _processandoAssinatura
                            ? null
                            : _onAprovarAssinatura,
                        icon: _processandoAssinatura
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 17),
                        label: const Text('Aprovar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.error,
                          side: BorderSide(
                            color: theme.error.withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: const Size(0, 38),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _processandoAssinatura
                            ? null
                            : _onReprovarAssinatura,
                        icon: _processandoAssinatura
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.error,
                                ),
                              )
                            : const Icon(Icons.close_rounded, size: 17),
                        label: const Text('Reprovar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLinhaFluxoMedicao(
    FlutterFlowTheme theme,
    Map<String, dynamic> a, {
    bool isLast = false,
  }) {
    final situacao = _str(a['situacao']);
    final numSit = a['situacao_numero'];
    final proximo = a['e_proximo'] == true;
    final nome = _str(a['nome']);
    final pos = _str(a['posicao']);

    Color chipColor = theme.secondaryText;
    IconData statusIcon = Icons.radio_button_unchecked;
    if (numSit == 1) {
      chipColor = theme.warning;
      statusIcon = Icons.hourglass_top_rounded;
    } else if (numSit == 2) {
      chipColor = theme.success;
      statusIcon = Icons.check_circle_rounded;
    } else if (numSit == 3) {
      chipColor = theme.error;
      statusIcon = Icons.cancel_rounded;
    }
    if (proximo) {
      chipColor = theme.primary;
      statusIcon = Icons.play_circle_outline_rounded;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: proximo
                        ? theme.primary
                        : chipColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: proximo
                          ? theme.primary
                          : chipColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    pos.isEmpty ? '—' : pos,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: proximo ? Colors.white : chipColor,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: theme.alternate,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: proximo
                    ? theme.primary.withValues(alpha: 0.06)
                    : theme.secondaryBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: proximo
                      ? theme.primary.withValues(alpha: 0.28)
                      : theme.alternate,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome.isEmpty ? '—' : nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryText,
                          ),
                        ),
                        if (proximo)
                          Text(
                            'Aguardando sua vez / decisão',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: theme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: chipColor.withValues(alpha: 0.28)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: chipColor),
                        const SizedBox(width: 4),
                        Text(
                          proximo
                              ? (situacao.isEmpty ? 'Na fila' : situacao)
                              : (situacao.isEmpty ? '—' : situacao),
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: chipColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarimboMedicaoBody(
    FlutterFlowTheme theme,
    Map<String, dynamic> d,
  ) {
    if (_aprovadoresLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    final pay = _aprovadoresPayload;
    final aprovadores = pay != null && pay['aprovadores'] is List
        ? (pay['aprovadores'] as List)
        : const [];
    final ultima = pay != null ? pay['ultima_aprovacao'] : null;

    if (aprovadores.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
        child: Column(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 36,
              color: theme.secondaryText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              'Nenhuma aprovação registrada',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: theme.success.withValues(alpha: 0.08),
            border: Border(bottom: BorderSide(color: theme.alternate)),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_rounded, color: theme.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Medição aprovada',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: theme.success,
                  ),
                ),
              ),
              if (ultima != null)
                Text(
                  _formatDataHoraMini(ultima).split(' ').first,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.secondaryText,
                  ),
                ),
            ],
          ),
        ),
        for (var i = 0; i < aprovadores.length; i++) ...[
          if (i > 0) Divider(height: 1, color: theme.alternate),
          if (aprovadores[i] is Map)
            _buildCarimboAprovadorMedicao(
              theme,
              Map<String, dynamic>.from(aprovadores[i] as Map),
              destaque: i == 0,
            ),
        ],
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.alternate)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 13, color: theme.secondaryText),
              const SizedBox(width: 6),
              Text(
                '#${_hashCarimbo(d['id'], ultima)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCarimboAprovadorMedicao(
    FlutterFlowTheme theme,
    Map<String, dynamic> a, {
    required bool destaque,
  }) {
    final nome = _str(a['nome']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: destaque
                ? theme.success.withValues(alpha: 0.15)
                : theme.primary.withValues(alpha: 0.12),
            child: Text(
              _iniciaisNome(nome.isEmpty ? null : nome),
              style: GoogleFonts.inter(
                color: destaque ? theme.success : theme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome.isEmpty ? 'N/A' : nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _cargoExibicao(a),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.alternate),
                      ),
                      child: Text(
                        '${_str(a['posicao'])}º na hierarquia',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.secondaryText,
                        ),
                      ),
                    ),
                    if (_str(a['data_assinatura']).isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.event_outlined,
                        size: 12,
                        color: theme.secondaryText,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          _formatDataHoraMini(a['data_assinatura']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (destaque)
            Icon(Icons.verified_rounded, size: 18, color: theme.success),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: GoogleFonts.inter(
                fontSize: 12,
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
