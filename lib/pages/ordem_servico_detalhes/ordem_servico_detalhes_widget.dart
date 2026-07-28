import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import 'ordem_servico_detalhes_model.dart';
export 'ordem_servico_detalhes_model.dart';

String _formatCurrency(num? v) {
  final n = (v ?? 0).toDouble();
  return NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(n);
}

String _formatDate(dynamic raw) {
  if (raw == null) return '';
  final s = raw.toString().trim();
  if (s.isEmpty) return '';
  if (s.contains('/')) {
    final parts = s.split(' ').first.split('/');
    if (parts.length == 3) {
      return s.split(' ').first;
    }
  }
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
    try {
      final d = DateTime.parse(s.substring(0, 10));
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {}
  }
  return s;
}

Map<String, dynamic> _saldoTarefa(Map<String, dynamic> t) {
  final prog = num.tryParse('${t['qtd_programada'] ?? 0}') ?? 0;
  final real = num.tryParse('${t['qtd_realizada'] ?? 0}') ?? 0;
  final saldo = prog - real;
  final pct = prog > 0 ? (real / prog * 100) : 0.0;
  Color cor;
  if (pct >= 100) {
    cor = Colors.green;
  } else if (pct >= 50) {
    cor = Colors.orange;
  } else {
    cor = Colors.red;
  }
  return {'saldo': saldo, 'percentual': pct, 'cor': cor};
}

String _statusTarefaText(Map<String, dynamic> t) {
  final m = _saldoTarefa(t);
  final pct = m['percentual'] as double;
  if (pct >= 100) return 'Concluída';
  if (pct > 0) return 'Em andamento';
  return 'Não iniciada';
}

Color _statusTarefaColor(Map<String, dynamic> t) {
  final m = _saldoTarefa(t);
  final pct = m['percentual'] as double;
  if (pct >= 100) return Colors.green;
  if (pct > 0) return Colors.orange;
  return Colors.red;
}

const Map<int, Map<String, dynamic>> _statusOs = {
  1: {'text': 'Preenchendo', 'color': Color(0xFF2196F3)},
  2: {'text': 'Aguardando Aprovação', 'color': Color(0xFF6200EE)},
  3: {'text': 'Aprovado', 'color': Color(0xFF4CAF50)},
  4: {'text': 'Reprovado', 'color': Color(0xFFE53935)},
};

Future<int?> _resolverIdServidor(String? raw) async {
  if (raw == null || raw.isEmpty) return null;
  final s = raw.trim();
  final direct = int.tryParse(s);
  if (direct != null) return direct;
  final db = SQLiteManager.instance.database;
  final rows = await db.query(
    'sync_id_mapping',
    columns: ['id_servidor'],
    where: 'tabela = ? AND uuid = ?',
    whereArgs: ['ordens_servico', s],
    limit: 1,
  );
  if (rows.isNotEmpty) return rows.first['id_servidor'] as int?;
  return null;
}

class OrdemServicoDetalhesWidget extends StatefulWidget {
  const OrdemServicoDetalhesWidget({
    super.key,
    required this.ordemUuid,
  });

  final String? ordemUuid;

  static String routeName = 'ordemServicoDetalhes';
  static String routePath = '/ordemServicoDetalhes';

  @override
  State<OrdemServicoDetalhesWidget> createState() =>
      _OrdemServicoDetalhesWidgetState();
}

class _OrdemServicoDetalhesWidgetState extends State<OrdemServicoDetalhesWidget>
    with SingleTickerProviderStateMixin {
  late OrdemServicoDetalhesModel _model;
  late AnimationController _animationController;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _model.onUpdate();
  }

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  String _filtroTarefa = 'todas';
  dynamic _fluxo;
  bool? _podeProcessarAssinatura;
  bool _fluxoLoading = false;
  bool _enviandoAprovacao = false;
  bool _processandoAssinatura = false;
  Map<String, dynamic>? _aprovadoresPayload;
  bool _aprovadoresLoading = false;
  bool _pdfLoading = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OrdemServicoDetalhesModel());
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_ordens_servico')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar ordens de serviço.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
      }
    });
    _carregar();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = await _resolverIdServidor(widget.ordemUuid);
      if (id == null) {
        setState(() {
          _error = 'Identificador da ordem inválido.';
          _loading = false;
        });
        return;
      }
      final token = FFAppState().UserToken;
      if (token.isEmpty) {
        setState(() {
          _error = 'Sessão expirada. Faça login novamente.';
          _loading = false;
        });
        return;
      }
      final uri = Uri.parse(
        'https://api.rdopro.com.br/api/obras/ordens/$id/show',
      );
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode == 404) {
        setState(() {
          _error = 'Ordem de serviço não encontrada.';
          _loading = false;
        });
        return;
      }
      if (res.statusCode != 200) {
        setState(() {
          _error = 'Erro ao carregar (HTTP ${res.statusCode}).';
          _loading = false;
        });
        return;
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _data = map;
        _loading = false;
      });
      await _loadFluxoEAprovadores(id);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int? _ordemIdServidor(Map<String, dynamic>? d) {
    if (d == null) return null;
    final rid = d['id'];
    if (rid is int) return rid;
    if (rid is num) return rid.toInt();
    return int.tryParse('$rid');
  }

  String _strOs(dynamic v) {
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

  String _formatDataHoraMiniOs(dynamic raw) {
    final s = _strOs(raw);
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
    final c = _strOs(a['cargo']);
    if (c.isNotEmpty) {
      final low = c.toLowerCase().replaceAll('.', '');
      const inv = {'nd', 'n/d', 'na', 'n/a', 'n-a'};
      if (!inv.contains(low)) return c;
    }
    return _cargoPorPosicao(a['posicao']);
  }

  Future<void> _loadFluxoEAprovadores(int ordemId) async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty || !mounted) return;
    final d = _data;
    if (d == null) return;
    final sid = int.tryParse('${d['status_id'] ?? 1}') ?? 1;

    if (sid == 2) {
      setState(() {
        _fluxoLoading = true;
        _fluxo = null;
        _podeProcessarAssinatura = null;
      });
      dynamic fluxo;
      final fx = await OrdemServicoFluxoAssinaturasCall.call(
        token: token,
        ordemId: ordemId,
      );
      if (fx.succeeded && fx.jsonBody is Map) {
        final m = Map<String, dynamic>.from(fx.jsonBody as Map);
        fluxo = m['fluxo'] ??
            (m['data'] is Map ? (m['data'] as Map)['fluxo'] : null);
      }
      if (fluxo == null) {
        final st = await AssinaturaOrdemServicoStatusCall.call(
          token: token,
          ordemId: ordemId,
        );
        if (st.succeeded && st.jsonBody is Map) {
          final m = Map<String, dynamic>.from(st.jsonBody as Map);
          final inner = m['data'];
          fluxo = inner is Map ? inner : m;
        }
      }
      bool? pode;
      final pp = await AssinaturaOrdemServicoPodeProcessarCall.call(
        token: token,
        ordemId: ordemId,
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
        _fluxo = fluxo;
        _podeProcessarAssinatura = pode;
        _fluxoLoading = false;
      });
    } else if (sid == 3) {
      setState(() {
        _aprovadoresLoading = true;
        _aprovadoresPayload = null;
      });
      Map<String, dynamic>? payload;
      final ap = await OrdemServicoAprovadoresCall.call(
        token: token,
        ordemId: ordemId,
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
        final fx = await OrdemServicoFluxoAssinaturasCall.call(
          token: token,
          ordemId: ordemId,
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
            for (final ap in aprovadores) {
              final dt = parseDt(ap['data_assinatura']);
              if (dt != null && (best == null || dt.isAfter(best))) {
                best = dt;
                ultima = ap['data_assinatura']?.toString();
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
        _fluxoLoading = false;
        _aprovadoresPayload = null;
        _aprovadoresLoading = false;
      });
    }
  }

  Future<void> _onImprimirPdf() async {
    final token = FFAppState().UserToken.trim();
    final d = _data;
    final id = _ordemIdServidor(d);
    if (token.isEmpty || id == null) return;
    setState(() => _pdfLoading = true);
    final nome = 'ordem-servico-${d?['codigo'] ?? d?['id'] ?? id}';
    final path = await OrdemServicoExportarPdf.downloadToTemp(
      token: token,
      ordemId: id,
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
    if (!MembershipAccess.canPermission('edit_ordens_servico')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar ordens de serviço.',
      );
      return;
    }
    final id = _ordemIdServidor(_data);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar para aprovação'),
        content: const Text(
          'A ordem passará para o status "Aguardando aprovação" e os aprovadores serão notificados. Deseja continuar?',
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
    final r = await OrdemServicoEnviarAprovacaoCall.call(
      token: token,
      ordemId: id,
    );
    if (!mounted) return;
    setState(() => _enviandoAprovacao = false);
    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordem enviada para aprovação.')),
      );
      await _carregar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  Future<void> _onAprovarAssinatura() async {
    if (!MembershipAccess.canPermission('approve_ordens_servico')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para aprovar ordens de serviço.',
      );
      return;
    }
    final id = _ordemIdServidor(_data);
    if (id == null) return;
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprovar ordem'),
        content: const Text(
          'Confirma a aprovação desta etapa? A ordem seguirá para o próximo aprovador ou será concluída na última assinatura.',
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
    final r = await AssinaturaOrdemServicoAprovarCall.call(
      token: token,
      ordemId: id,
    );
    if (!mounted) return;
    setState(() => _processandoAssinatura = false);
    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aprovação registrada.')),
      );
      await _carregar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  Future<void> _onReprovarAssinatura() async {
    if (!MembershipAccess.canPermission('approve_ordens_servico')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para aprovar ordens de serviço.',
      );
      return;
    }
    final id = _ordemIdServidor(_data);
    if (id == null) return;
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Reprovar ordem'),
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
    final r = await AssinaturaOrdemServicoReprovarCall.call(
      token: token,
      ordemId: id,
      motivo: motivo,
    );
    if (!mounted) return;
    setState(() => _processandoAssinatura = false);
    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ordem reprovada.')),
      );
      await _carregar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  Future<void> _onSolicitarRevogacao() async {
    final id = _ordemIdServidor(_data);
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
    final r = await OrdemServicoSolicitarRevogacaoCall.call(
      token: token,
      ordemId: id,
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
      await _carregar();
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
        ? await OsRevogacaoAprovarCall.call(
            token: token,
            revogacaoUuid: revogacaoUuid,
            motivo: motivo,
          )
        : await OsRevogacaoRejeitarCall.call(
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
      await _carregar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  Map<String, dynamic>? _obra() {
    final o = _data?['obra'];
    if (o is Map<String, dynamic>) return o;
    return null;
  }

  String _enderecoObra() {
    final o = _obra();
    if (o == null) return '---';
    final rua = o['rua']?.toString() ?? '';
    final num = o['numero']?.toString() ?? '';
    final comp = o['complemento']?.toString() ?? '';
    final bairro = o['bairro']?.toString() ?? '';
    final c1 = '$rua $num'.trim();
    final c2 = comp.isNotEmpty ? '$c1, $comp' : c1;
    return '$c2 - $bairro'.trim();
  }

  String _cidadeEstadoObra() {
    final o = _obra();
    if (o == null) return '---';
    final c = o['cidade']?.toString() ?? '';
    final e = o['estado']?.toString() ?? '';
    if (c.isEmpty && e.isEmpty) return '---';
    return '$c/$e';
  }

  List<Map<String, dynamic>> _tarefas() {
    final t = _data?['tarefas'];
    if (t is! List) return [];
    return t.whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _tarefasFiltradas() {
    final all = _tarefas();
    if (_filtroTarefa == 'pendentes') {
      return all.where((t) => (_saldoTarefa(t)['saldo'] as num) > 0).toList();
    }
    if (_filtroTarefa == 'concluidas') {
      return all
          .where((t) => (_saldoTarefa(t)['percentual'] as double) >= 100)
          .toList();
    }
    return all;
  }

  Map<String, num> _totais() {
    final custos = _data?['custos'];
    num custoTotal = 0;
    if (custos is List) {
      for (final c in custos) {
        if (c is Map<String, dynamic>) {
          custoTotal += num.tryParse('${c['valor_total'] ?? 0}') ?? 0;
        }
      }
    }
    final ts = _tarefas();
    num prog = 0, real = 0;
    for (final t in ts) {
      prog += num.tryParse('${t['qtd_programada'] ?? 0}') ?? 0;
      real += num.tryParse('${t['qtd_realizada'] ?? 0}') ?? 0;
    }
    final bdiPct = num.tryParse('${_data?['percentual_bdi'] ?? 0}') ?? 0;
    final impPct = num.tryParse('${_data?['percentual_impostos'] ?? 0}') ?? 0;
    final valorBdi = num.tryParse('${_data?['valor_bdi'] ?? 0}') ??
        (custoTotal * bdiPct / 100);
    final valorImp = num.tryParse('${_data?['valor_impostos'] ?? 0}') ??
        (custoTotal * impPct / 100);
    final valorTotal = num.tryParse('${_data?['valor_total'] ?? 0}') ??
        (custoTotal + valorBdi + valorImp);
    return {
      'custoTotal': custoTotal,
      'programadaTotal': prog,
      'realizadaTotal': real,
      'saldoTotal': prog - real,
      'valorBdi': valorBdi,
      'valorImpostos': valorImp,
      'valorTotal': valorTotal,
    };
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        appBar: _buildAppBar(theme),
        body: FadeTransition(
          opacity: _animationController,
                child: _buildBody(theme, context),
        ),
      ),
    );
  }

  /// Chip de status da OS na barra superior (~30% maior que o do card).
  Widget? _buildAppBarStatusChip(FlutterFlowTheme theme) {
    final d = _data;
    if (d == null) return null;
    final statusId = int.tryParse('${d['status_id'] ?? 1}') ?? 1;
    final st =
        _statusOs[statusId] ?? {'text': 'Desconhecido', 'color': theme.primary};
    final Color chipColor =
        st['color'] is Color ? st['color'] as Color : theme.primary;
    const scale = 1.3;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: (12 * scale).roundToDouble(),
          vertical: (6 * scale).roundToDouble(),
        ),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(20 * scale),
          boxShadow: [
            BoxShadow(
              color: chipColor.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          st['text'] as String,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: (12 * scale).roundToDouble(),
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
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
          onPressed: () => context.pop(),
        ),
      ),
      title: statusChip != null
          ? Center(child: statusChip)
          : Text(
              'Ordem de Serviço',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
                letterSpacing: -0.3,
              ),
            ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            tooltip: 'Atualizar',
            icon: Icon(Icons.refresh_rounded, color: theme.primary, size: 22),
            onPressed: _loading ? null : _carregar,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(FlutterFlowTheme theme, BuildContext context) {
    if (_loading) return _buildLoadingState(theme);
    if (_error != null) return _buildErrorState(theme);
    if (_data == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _carregar,
      color: theme.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeaderCard(theme),
                const SizedBox(height: 12),
                if (_data!['revogacao_ativa'] != null) ...[
                  _buildRevogacaoBanner(theme),
                  const SizedBox(height: 12),
                ],
                _buildResumeCards(theme),
                const SizedBox(height: 12),
                _buildInfoTwoColumns(theme),
                const SizedBox(height: 12),
                _buildTarefasCard(theme, context),
                if ((_data!['custos'] as List?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  _buildCustosCard(theme, context),
                ],
                if (_shouldShowAssinaturasCard()) ...[
                  const SizedBox(height: 12),
                  _buildAssinaturasCard(theme, context),
                ],
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
            'Carregando ordem',
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
                onPressed: _carregar,
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

  Widget _buildHeaderCard(FlutterFlowTheme theme) {
    final d = _data!;
    final statusId = int.tryParse('${d['status_id'] ?? 1}') ?? 1;
    final podeRevogar = d['pode_solicitar_revogacao'] == true;
    final canEdit =
        MembershipAccess.canPermission('edit_ordens_servico');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primary,
            theme.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${d['codigo'] ?? d['id'] ?? '-'} • ${d['nome'] ?? '-'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13 * 1.1,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF',
                    onPressed: !_pdfLoading ? _onImprimirPdf : null,
                    loading: _pdfLoading,
                    backgroundColor: Colors.white,
                    foregroundColor: theme.primary,
                  ),
                ),
                if (statusId == 1 && canEdit) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.send_rounded,
                      label: _enviandoAprovacao ? 'Enviando...' : 'Enviar',
                      onPressed:
                          _enviandoAprovacao ? null : _onEnviarParaAprovacao,
                      loading: _enviandoAprovacao,
                      backgroundColor: Colors.white,
                      foregroundColor: theme.primary,
                    ),
                  ),
                ],
                if (podeRevogar) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.settings_backup_restore_rounded,
                      label: 'Revogar',
                      onPressed: _onSolicitarRevogacao,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foregroundColor,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
    );
  }

  Widget _buildRevogacaoBanner(FlutterFlowTheme theme) {
    final rev = _data!['revogacao_ativa'];
    if (rev is! Map) return const SizedBox.shrink();
    final rm = Map<String, dynamic>.from(rev);
    final solicitante = '${rm['solicitante'] ?? '-'}';
    final uuid = '${rm['uuid'] ?? ''}'.trim();
    final podeDecidir = _data!['usuario_pode_decidir_revogacao'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.orange.shade900),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Revogação em andamento • Solicitado por $solicitante',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          if (podeDecidir && uuid.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _onDecidirRevogacao(
                      aprovar: true,
                      revogacaoUuid: uuid,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Aprovar revogação'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _onDecidirRevogacao(
                      aprovar: false,
                      revogacaoUuid: uuid,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Rejeitar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static const double _resumeMetricCardHeight = 104 * 0.7;

  Widget _buildResumeCards(FlutterFlowTheme theme) {
    final d = _data!;
    final tot = _totais();
    final nAssin = (d['assinaturas'] as List?)?.length ?? 0;
    final di = _formatDate(d['data_inicio']);
    final df = _formatDate(d['data_fim']);
    const h = _resumeMetricCardHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInfoCard(
                theme,
                '${_tarefas().length}',
                'Tarefas',
                Icons.task_alt,
                height: h,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                theme,
                _formatCurrency(tot['valorTotal']),
                'Valor Total',
                Icons.currency_bitcoin,
                height: h,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildPeriodResumeCard(theme, di, df, height: h),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                theme,
                '$nAssin',
                'Assinaturas',
                Icons.draw,
                height: h,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodResumeCard(
    FlutterFlowTheme theme,
    String di,
    String df, {
    double? height,
  }) {
    const dateFontSize = 10.5;
    final d1 = di.isEmpty ? '---' : di;
    final d2 = df.isEmpty ? '---' : df;
    final dateStyle = GoogleFonts.inter(
      fontSize: dateFontSize,
      fontWeight: FontWeight.w600,
      height: 1.15,
      color: theme.primaryText,
    );

    final inner = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            height != null ? MainAxisAlignment.center : MainAxisAlignment.start,
        mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: theme.primary),
              const SizedBox(width: 6),
              Text(
                'Período',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  d1,
                  style: dateStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: theme.secondaryText,
                ),
              ),
              Expanded(
                child: Text(
                  d2,
                  style: dateStyle,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (height != null) {
      return SizedBox(height: height, child: inner);
    }
    return inner;
  }

  Widget _buildInfoCard(
    FlutterFlowTheme theme,
    String value,
    String label,
    IconData icon, {
    String? subtitle,
    double? height,
  }) {
    final inner = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            height != null ? MainAxisAlignment.center : MainAxisAlignment.start,
        mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.primaryText,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: theme.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
    if (height != null) {
      return SizedBox(height: height, child: inner);
    }
    return inner;
  }

  Widget _buildInfoTwoColumns(FlutterFlowTheme theme) {
    final obra = _obra();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoSection(
          theme,
          'Informações da Ordem',
          [
            _buildInfoRow(theme, 'Código:', '${_data!['codigo'] ?? '---'}'),
            _buildInfoRow(
                theme, 'Emissão:', _formatDate(_data!['data_emissao'])),
            _buildInfoRow(
              theme,
              'Observações:',
              (_data!['observacoes']?.toString().isNotEmpty ?? false)
                  ? _data!['observacoes'].toString()
                  : 'Nenhuma',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInfoSection(
          theme,
          'Informações da Obra',
          [
            _buildInfoRow(theme, 'Nome:', obra?['nome']?.toString() ?? '---'),
            _buildInfoRow(theme, 'Endereço:', _enderecoObra()),
            _buildInfoRow(theme, 'Cidade/UF:', _cidadeEstadoObra()),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSection(
    FlutterFlowTheme theme,
    String title,
    List<Widget> rows,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildInfoRow(FlutterFlowTheme theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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

  Widget _buildTarefasCard(FlutterFlowTheme theme, BuildContext context) {
    final lista = _tarefasFiltradas();
    final n = _tarefas().length;
    final tot = _totais();

    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tarefas',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(theme, 'todas', 'Todas ($n)'),
                    _buildFilterChip(theme, 'pendentes', 'Pendentes'),
                    _buildFilterChip(theme, 'concluidas', 'Concluídas'),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.primary.withValues(alpha: 0.04),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Text(
                  'Programado: ${tot['programadaTotal']}',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                Text(
                  'Realizado: ${tot['realizadaTotal']}',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                Text(
                  'Saldo: ${tot['saldoTotal']}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ((tot['saldoTotal'] ?? 0) > 0)
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          if (lista.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nenhuma tarefa neste filtro',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: theme.secondaryText),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lista.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Theme.of(context).dividerColor,
              ),
              itemBuilder: (ctx, index) =>
                  _buildTarefaItem(theme, lista[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(FlutterFlowTheme theme, String key, String label) {
    final sel = _filtroTarefa == key;
    return GestureDetector(
      onTap: () => setState(() => _filtroTarefa = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? theme.primary.withValues(alpha: 0.1) : theme.alternate,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? theme.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? theme.primary : theme.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildTarefaItem(FlutterFlowTheme theme, Map<String, dynamic> t) {
    final tar = t['tarefa'];
    Map<String, dynamic>? td;
    if (tar is Map<String, dynamic>) td = tar;
    final desc = td?['descricao']?.toString() ?? 'N/A';
    final local = td?['local']?.toString() ?? '';
    final m = _saldoTarefa(t);
    final pct = m['percentual'] as double;
    final cor = m['cor'] as Color;
    final status = _statusTarefaText(t);
    final statusColor = _statusTarefaColor(t);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (local.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              local,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Prog. ${t['qtd_programada'] ?? 0}',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              Text(
                'Real. ${t['qtd_realizada'] ?? 0}',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Saldo ${m['saldo']}',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600, color: cor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progresso',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: theme.secondaryText),
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pct >= 100 ? Colors.green : theme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct.clamp(0, 100) / 100,
                  minHeight: 6,
                  backgroundColor: theme.alternate,
                  color: pct >= 100 ? Colors.green : theme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustosCard(FlutterFlowTheme theme, BuildContext context) {
    final custos = _data!['custos'] as List? ?? [];
    final tot = _totais();

    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Custos e Tributos',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.primaryText,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: custos.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
            itemBuilder: (ctx, index) =>
                _buildCustoItem(theme, custos[index] as Map<String, dynamic>),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.primary.withValues(alpha: 0.04),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Custos: ${_formatCurrency(tot['custoTotal'])}',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                if ((num.tryParse('${_data!['percentual_bdi'] ?? 0}') ?? 0) > 0)
                  Text(
                    'BDI (${_data!['percentual_bdi']}%): +${_formatCurrency(tot['valorBdi'])}',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                if ((num.tryParse('${_data!['percentual_impostos'] ?? 0}') ??
                        0) >
                    0)
                  Text(
                    'Impostos (${_data!['percentual_impostos']}%): +${_formatCurrency(tot['valorImpostos'])}',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                Text(
                  'TOTAL: ${_formatCurrency(tot['valorTotal'])}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustoItem(FlutterFlowTheme theme, Map<String, dynamic> c) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${c['descricao'] ?? ''}',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(
                'Un: ${c['unidade'] ?? '-'}',
                style:
                    GoogleFonts.inter(fontSize: 12, color: theme.secondaryText),
              ),
              Text(
                'Qtd: ${c['qtd_prevista'] ?? '-'}',
                style:
                    GoogleFonts.inter(fontSize: 12, color: theme.secondaryText),
              ),
              Text(
                'Unitário: ${_formatCurrency(num.tryParse('${c['valor_unitario'] ?? 0}'))}',
                style:
                    GoogleFonts.inter(fontSize: 12, color: theme.secondaryText),
              ),
              Text(
                'Total: ${_formatCurrency(num.tryParse('${c['valor_total'] ?? 0}'))}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _shouldShowAssinaturasCard() {
    final d = _data!;
    final statusId = int.tryParse('${d['status_id'] ?? 1}') ?? 1;
    final assinaturas = d['assinaturas'];
    final nAssin = assinaturas is List ? assinaturas.length : 0;
    return nAssin > 0 || statusId == 2 || statusId == 3;
  }

  Widget _buildAssinaturasCard(FlutterFlowTheme theme, BuildContext context) {
    final d = _data!;
    final statusId = int.tryParse('${d['status_id'] ?? 1}') ?? 1;

    Widget body;
    if (statusId == 2) {
      body = _buildFluxoAssinaturasBody(theme);
    } else if (statusId == 3) {
      body = _buildCarimboAprovacaoBody(theme, d, context);
    } else {
      final list = d['assinaturas'] as List? ?? [];
      body = _buildListaAssinaturasSimples(theme, list);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assinaturas',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }

  Widget _buildListaAssinaturasSimples(FlutterFlowTheme theme, List list) {
    return Column(
      children: list.map((raw) {
        if (raw is! Map<String, dynamic>) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 20, color: theme.secondaryText),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  raw['assinante'] is Map
                      ? '${(raw['assinante'] as Map)['nome'] ?? '-'}'
                      : '${raw['nome_assinante'] ?? raw['assinante_id'] ?? '-'}',
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.alternate,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${raw['situacao'] ?? raw['status'] ?? ''}',
                  style: GoogleFonts.inter(fontSize: 11),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFluxoAssinaturasBody(FlutterFlowTheme theme) {
    if (_fluxoLoading) {
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
    final proxNome = prox is Map ? _strOs(prox['nome']) : '';

    return Column(
      children: [
        if (lista.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Text(
                'Não foi possível carregar a fila de aprovadores.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: theme.secondaryText,
                ),
              ),
            ),
          )
        else ...[
          for (final raw in lista)
            if (raw is Map) ...[
              _buildLinhaFluxoAssinatura(theme, Map<String, dynamic>.from(raw)),
              const SizedBox(height: 8),
            ],
        ],
        if (proxNome.isNotEmpty && _podeProcessarAssinatura != true) ...[
          const SizedBox(height: 8),
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
          const Divider(height: 24),
          if (MembershipAccess.canPermission('approve_ordens_servico')) ...[
            Text(
              'Sua decisão',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF',
                    onPressed: !_pdfLoading ? _onImprimirPdf : null,
                    loading: _pdfLoading,
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.check,
                    label: 'Aprovar',
                    onPressed:
                        _processandoAssinatura ? null : _onAprovarAssinatura,
                    loading: _processandoAssinatura,
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _processandoAssinatura ? null : _onReprovarAssinatura,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Reprovar'),
                  ),
                ),
              ],
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Sem permissão para aprovar ordens de serviço.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: theme.primaryText,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildLinhaFluxoAssinatura(
      FlutterFlowTheme theme, Map<String, dynamic> a) {
    final situacao = _strOs(a['situacao']);
    final numSit = a['situacao_numero'];
    Color chipColor = theme.secondaryText;
    if (numSit == 1) chipColor = Colors.orange;
    if (numSit == 2) chipColor = Colors.green.shade700;
    if (numSit == 3) chipColor = theme.error;
    final proximo = a['e_proximo'] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: proximo
            ? theme.primary.withValues(alpha: 0.08)
            : theme.alternate.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            proximo ? Icons.arrow_circle_right : Icons.person_outline,
            color: proximo ? theme.primary : theme.secondaryText,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_strOs(a['posicao'])}º ${_strOs(a['nome'])}',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (proximo)
                  Text(
                    'Aguardando esta assinatura',
                    style:
                        GoogleFonts.inter(fontSize: 11, color: theme.primary),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              situacao,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarimboAprovacaoBody(FlutterFlowTheme theme,
      Map<String, dynamic> d, BuildContext context) {
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: theme.secondaryText.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Nenhuma aprovação registrada',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.verified_rounded,
                color: Colors.green.shade700, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ORDEM APROVADA',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
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
                  _formatDataHoraMiniOs(ultima).split(' ').first,
                  style: GoogleFonts.inter(fontSize: 11),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < aprovadores.length; i++)
          if (aprovadores[i] is Map) ...[
            _buildCarimboAprovador(
                theme,
                context,
                Map<String, dynamic>.from(aprovadores[i] as Map),
                destaque: i == 0),
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

  Widget _buildCarimboAprovador(
    FlutterFlowTheme theme,
    BuildContext context,
    Map<String, dynamic> a, {
    required bool destaque,
  }) {
    final nome = _strOs(a['nome']);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: destaque
              ? Colors.green.shade300
              : Theme.of(context).dividerColor,
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
                        '${_strOs(a['posicao'])}º na hierarquia',
                        style: GoogleFonts.inter(fontSize: 10),
                      ),
                    ),
                    if (_strOs(a['data_assinatura']).isNotEmpty)
                      Text(
                        _formatDataHoraMiniOs(a['data_assinatura']),
                        style: GoogleFonts.inter(
                            fontSize: 11, color: theme.secondaryText),
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

  String _hashCarimbo(dynamic ordemId, dynamic ultima) {
    final s =
        'OS-${ordemId ?? '0'}-${ultima ?? DateTime.now().toIso8601String()}';
    final b = base64Encode(utf8.encode(s));
    return b.length >= 8 ? b.substring(0, 8) : b;
  }
}
