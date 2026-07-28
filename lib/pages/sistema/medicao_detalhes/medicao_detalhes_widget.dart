import '/backend/api_requests/api_calls.dart';
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

  Widget? _buildAppBarStatusChip(FlutterFlowTheme theme) {
    if (_medicao == null) return null;
    final chipColor = _statusMedicaoChipColor(theme);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: chipColor.withValues(alpha: 0.35)),
        ),
        child: Text(
          _labelStatusMedicao(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: chipColor,
          ),
        ),
      ),
    );
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
    final statusChip = _buildAppBarStatusChip(theme);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: statusChip != null,
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: theme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.primary),
          onPressed: () => context.safePop(),
        ),
      ),
      title: statusChip != null
          ? Center(child: statusChip)
          : Text(
              'Medição',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
                letterSpacing: -0.3,
              ),
            ),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          icon: Icon(Icons.refresh_rounded, color: theme.primary, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          visualDensity: VisualDensity.compact,
          onPressed: _load,
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
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ..._buildRevogacaoWidgets(theme),
                ..._buildHistoricoRevogacoes(theme),
                _buildResumoCard(theme),
                const SizedBox(height: 8),
                _buildBarraAcoesMedicao(theme),
                const SizedBox(height: 10),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            'Carregando medição',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aguarde um momento...',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(FlutterFlowTheme theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 40, color: theme.error),
            ),
            const SizedBox(height: 24),
            Text(
              'Erro ao carregar',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 200,
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Tentar novamente'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
        decoration: BoxDecoration(
          color: theme.warning.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.warning.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revogação em andamento',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.warning,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Solicitante', '${r['solicitante'] ?? '—'}'),
              _buildInfoRow('Data', _formatData(r['data_solicitacao'])),
              _buildInfoRow('Motivo', '${r['motivo'] ?? '—'}'),
              if (list.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Assinaturas',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
                            style: GoogleFonts.inter(fontSize: 13),
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
      ),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
  }) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
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
      ),
    );
  }

  List<Widget> _buildHistoricoRevogacoes(FlutterFlowTheme theme) {
    final m = _medicao;
    if (m == null) return [];
    final hist = m['historico_revogacoes'];
    if (hist is! List || hist.isEmpty) return [];

    return [
      _buildSectionTitle('Histórico de revogações', Icons.history),
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.alternate),
        ),
        child: Column(
          children: hist.map((raw) {
            if (raw is! Map) return const SizedBox.shrink();
            final h = Map<String, dynamic>.from(raw);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${h['solicitante'] ?? ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
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
      const SizedBox(height: 8),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medição #${m['numero'] ?? '—'}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.primaryText,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _obraNome(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusCor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusCor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _labelStatusMedicao(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusCor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildInfoChip(
                    theme,
                    'Mês ref.',
                    _formatMesRef(m['mes_referencia']),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildInfoChip(
                    theme,
                    'Período',
                    '${_formatData(m['data_inicio_periodo'])} — ${_formatData(m['data_termino_periodo'])}',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildInfoChip(
                    theme,
                    '% físico',
                    '${_toDouble(m['percentual_fisico_acumulado']).toStringAsFixed(1)}%',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildInfoChip(
                    theme,
                    'R\$ acumulado',
                    'R\$ ${_money.format(_toDouble(m['valor_acumulado']))}',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildInfoChip(
                    theme,
                    'R\$ mês',
                    'R\$ ${_money.format(_toDouble(m['valor_realizado']))}',
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 72,
                  child: _buildPdfResumoButton(theme),
                ),
              ],
            ),
          ),
          if ((m['observacoes'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: theme.alternate),
            const SizedBox(height: 8),
            Text(
              'Observações',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              m['observacoes'].toString(),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.primaryText,
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

  Widget _buildInfoChip(FlutterFlowTheme theme, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
              height: 1.15,
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (sid == 1)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _enviandoAprovacao ? null : _onEnviarParaAprovacao,
            icon: _enviandoAprovacao
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _enviandoAprovacao ? 'Enviando…' : 'Enviar para aprovação',
              style: GoogleFonts.inter(fontSize: 12),
            ),
          ),
        if (podeRevogar)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              side: BorderSide(color: Colors.orange.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _onSolicitarRevogacao,
            icon: Icon(Icons.settings_backup_restore_rounded, size: 18),
            label: const Text('Revogar aprovação'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Itens da medição', Icons.account_tree_outlined),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.alternate),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildMiniStatChip(theme, 'Total: ${all.length}'),
              _buildMiniStatChip(theme, 'Etapas: ${cnt('etapa')}'),
              _buildMiniStatChip(theme, 'Tarefas: ${cnt('tarefa')}'),
              TextButton(
                onPressed: _expandirTudo,
                style: TextButton.styleFrom(
                  foregroundColor: theme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Expandir', style: GoogleFonts.inter(fontSize: 11)),
              ),
              TextButton(
                onPressed: _colapsarTudo,
                style: TextButton.styleFrom(
                  foregroundColor: theme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Recolher', style: GoogleFonts.inter(fontSize: 11)),
              ),
            ],
          ),
        ),
        if (visiveis.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.alternate),
            ),
            child: Center(
              child: Text(
                'Nenhum item nesta medição.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.secondaryText,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 32,
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 34,
                    columnSpacing: 8,
                    headingRowColor: WidgetStateProperty.all(
                      theme.primary.withValues(alpha: 0.05),
                    ),
                    headingTextStyle: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                    dataTextStyle: GoogleFonts.inter(fontSize: 11),
                    columns: const [
                      DataColumn(
                        label: Text('EDT'),
                        tooltip: 'Código e hierarquia (nível 1 com fundo)',
                      ),
                      DataColumn(label: Text('Descrição')),
                      DataColumn(label: Text('Un')),
                      DataColumn(label: Text('Q.orç'), numeric: true),
                      DataColumn(label: Text('Q.acum'), numeric: true),
                      DataColumn(label: Text('Q.mês'), numeric: true),
                      DataColumn(label: Text('R\$ atual'), numeric: true),
                      DataColumn(label: Text('R\$ acumulada'), numeric: true),
                      DataColumn(label: Text('Saldo R\$'), numeric: true),
                    ],
                    rows: visiveis.map((it) {
                      final id = _toInt(it['id']);
                      final edt = '${it['codigo_edt'] ?? ''}';
                      final depth = _depthEdt(edt);
                      final edtCellPad = 4.0 + (depth * 10.0);
                      final isRoot = _idPaiDeItem(it, all, edtToId) == null;
                      final desc = '${it['descricao'] ?? ''}';
                      final tem = id != null && _temFilhos(it, all, edtToId);
                      final edtBg = isRoot
                          ? theme.primary.withValues(alpha: 0.08)
                          : theme.alternate.withValues(alpha: 0.35);

                      return DataRow(
                        color: isRoot
                            ? WidgetStatePropertyAll(
                                theme.primaryBackground,
                              )
                            : null,
                        cells: [
                          DataCell(
                            Container(
                              color: edtBg,
                              padding: EdgeInsets.only(
                                left: edtCellPad,
                                right: 8,
                                top: 4,
                                bottom: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (tem)
                                    InkWell(
                                      onTap: () {
                                        final h = _toInt(it['id']);
                                        if (h == null) return;
                                        setState(() {
                                          if (_expandedIds.contains(h)) {
                                            _expandedIds.remove(h);
                                          } else {
                                            _expandedIds.add(h);
                                          }
                                        });
                                      },
                                      child: Icon(
                                        _expandedIds.contains(id)
                                            ? Icons.expand_more
                                            : Icons.chevron_right,
                                        size: 18,
                                        color: theme.primary,
                                      ),
                                    )
                                  else
                                    const SizedBox(width: 4),
                                  Text(
                                    edt,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isRoot
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              desc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DataCell(Text('${it['unidade'] ?? '—'}')),
                          DataCell(Text(
                              _qty.format(_toDouble(it['quantidade_orcada'])))),
                          DataCell(Text(_qty.format(
                              _toDouble(it['quantidade_acumulada_atual'])))),
                          DataCell(Text(
                            it['quantidade_realizada_mes'] == '-'
                                ? '—'
                                : _qty.format(
                                    _toDouble(it['quantidade_realizada_mes'])),
                          )),
                          DataCell(Text(
                              'R\$ ${_money.format(_toDouble(it['valor_realizado_mes']))}')),
                          DataCell(Text(
                              'R\$ ${_money.format(_toDouble(it['valor_acumulado']))}')),
                          DataCell(Text(
                              'R\$ ${_money.format(_toDouble(it['saldo_valor']))}')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Text(
                    'Totais (sem etapas) · Q.orç ${_qty.format(tot['qOrc']!)} · Q.acum ${_qty.format(tot['qAcum']!)} · Q.mês ${_qty.format(tot['qReal']!)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.secondaryText,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Text(
                    'R\$ atual ${_money.format(tot['vAtual']!)} · acum. ${_money.format(tot['vAcum']!)} · saldo ${_money.format(tot['vSaldo']!)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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

    Widget inner;
    if (sid == 2) {
      inner = _buildFluxoMedicaoBody(theme);
    } else if (sid == 3) {
      inner = _buildCarimboMedicaoBody(theme, m);
    } else {
      inner = _buildListaAssinaturasSimplesMedicao(theme, listaAssin);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Assinaturas', Icons.draw_outlined),
        Container(
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.alternate),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: inner,
          ),
        ),
      ],
    );
  }

  Widget _buildListaAssinaturasSimplesMedicao(
    FlutterFlowTheme theme,
    List lista,
  ) {
    if (lista.isEmpty) {
      return Text(
        'Nenhuma assinatura registrada.',
        style: GoogleFonts.inter(fontSize: 13, color: theme.secondaryText),
      );
    }
    return Column(
      children: lista.map((raw) {
        if (raw is! Map) return const SizedBox.shrink();
        final a = Map<String, dynamic>.from(raw);
        final nome = a['assinante'] is Map
            ? (a['assinante'] as Map)['nome']?.toString()
            : a['assinante']?.toString();
        final pos = a['posicao'];
        final sit = a['situacao'] ?? a['status_texto'];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${pos ?? ''}º ${nome ?? '—'} · ${sit ?? '—'}',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ),
              if (a['data_assinatura'] != null)
                Text(
                  _formatDataHoraMini(a['data_assinatura']).split(' ').first,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: theme.secondaryText),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFluxoMedicaoBody(FlutterFlowTheme theme) {
    if (_fluxoCarregando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(),
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
        Text(
          'Fluxo de assinaturas',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              'Não foi possível carregar a fila de aprovadores. Atualize a tela.',
              style:
                  GoogleFonts.inter(fontSize: 13, color: theme.secondaryText),
            ),
          )
        else ...[
          const SizedBox(height: 8),
          for (final raw in lista)
            if (raw is Map) ...[
              _buildLinhaFluxoMedicao(theme, Map<String, dynamic>.from(raw)),
              const SizedBox(height: 4),
            ],
        ],
        if (proxNome.isNotEmpty && _podeProcessarAssinatura != true) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.info.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.hourglass_bottom_outlined, color: theme.info),
                const SizedBox(width: 8),
                Text(
                  'Próximo na fila: $proxNome',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
        if (_podeProcessarAssinatura == true) ...[
          const Divider(height: 16),
          Text(
            'Sua decisão',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed:
                      _processandoAssinatura ? null : _onAprovarAssinatura,
                  icon: _processandoAssinatura
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Aprovar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed:
                      _processandoAssinatura ? null : _onReprovarAssinatura,
                  icon: _processandoAssinatura
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close, size: 18),
                  label: const Text('Reprovar'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLinhaFluxoMedicao(
      FlutterFlowTheme theme, Map<String, dynamic> a) {
    final situacao = _str(a['situacao']);
    final numSit = a['situacao_numero'];
    Color chipColor = theme.secondaryText;
    if (numSit == 1) chipColor = Colors.orange;
    if (numSit == 2) chipColor = Colors.green.shade700;
    if (numSit == 3) chipColor = theme.error;
    final proximo = a['e_proximo'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: proximo
            ? theme.primary.withValues(alpha: 0.06)
            : theme.primaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: proximo
              ? theme.primary.withValues(alpha: 0.2)
              : theme.alternate,
        ),
      ),
      child: Row(
        children: [
          Icon(
            proximo ? Icons.arrow_circle_right : Icons.person_outline,
            color: proximo ? theme.primary : theme.secondaryText,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              proximo
                  ? '${_str(a['posicao'])}º ${_str(a['nome'])} · aguardando'
                  : '${_str(a['posicao'])}º ${_str(a['nome'])}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              situacao,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: chipColor,
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final pay = _aprovadoresPayload;
    final aprovadores = pay != null && pay['aprovadores'] is List
        ? (pay['aprovadores'] as List)
        : const [];
    final ultima = pay != null ? pay['ultima_aprovacao'] : null;

    if (aprovadores.isEmpty) {
      return Column(
        children: [
          Icon(Icons.info_outline,
              size: 48, color: theme.secondaryText.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'Nenhuma aprovação registrada',
            style: GoogleFonts.inter(fontSize: 14, color: theme.secondaryText),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.verified_rounded,
                color: Colors.green.shade700, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'MEDIÇÃO APROVADA',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (ultima != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.alternate,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatDataHoraMini(ultima).split(' ').first,
                  style: GoogleFonts.inter(fontSize: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < aprovadores.length; i++)
          if (aprovadores[i] is Map) ...[
            _buildCarimboAprovadorMedicao(
              theme,
              Map<String, dynamic>.from(aprovadores[i] as Map),
              destaque: i == 0,
            ),
            const SizedBox(height: 12),
          ],
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.shield_outlined, size: 14, color: theme.secondaryText),
            const SizedBox(width: 6),
            Text(
              '#${_hashCarimbo(d['id'], ultima)}',
              style:
                  GoogleFonts.inter(fontSize: 11, color: theme.secondaryText),
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              destaque ? Colors.green.shade300 : Theme.of(context).dividerColor,
          width: destaque ? 2 : 1,
        ),
        color: destaque ? Colors.green.shade50 : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: destaque ? Colors.green.shade600 : theme.primary,
            radius: 24,
            child: Text(
              _iniciaisNome(nome.isEmpty ? null : nome),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome.isEmpty ? 'N/A' : nome,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _cargoExibicao(a),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.alternate,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_str(a['posicao'])}º na hierarquia',
                        style: GoogleFonts.inter(fontSize: 10),
                      ),
                    ),
                    if (_str(a['data_assinatura']).isNotEmpty)
                      Text(
                        _formatDataHoraMini(a['data_assinatura']),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: theme.secondaryText,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatChip(FlutterFlowTheme theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.alternate),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: theme.secondaryText,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: theme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
              letterSpacing: -0.2,
            ),
          ),
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
