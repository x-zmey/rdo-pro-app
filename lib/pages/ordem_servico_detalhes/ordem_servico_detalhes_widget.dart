import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/ui/rdo_estilo.dart';
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
  2: {'text': 'Aguardando Aprovação', 'color': Color(0xFF7B1FA2)},
  3: {'text': 'Aprovado', 'color': Color(0xFF2E7D32)},
  4: {'text': 'Reprovado', 'color': Color(0xFFC62828)},
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
          child: _buildBody(theme),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(FlutterFlowTheme theme) {
    final d = _data;
    final codigo = d == null ? '' : '${d['codigo'] ?? d['id'] ?? ''}'.trim();
    final nome = d == null ? '' : '${d['nome'] ?? ''}'.trim();
    final obraNome = '${_obra()?['nome'] ?? ''}'.trim();
    final subtitulo = [
      if (codigo.isNotEmpty) codigo,
      if (nome.isNotEmpty) nome,
      if (obraNome.isNotEmpty) obraNome,
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
              'Ordem de Serviço',
              style: GoogleFonts.interTight(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              subtitulo.isEmpty ? 'Detalhes da ordem' : subtitulo,
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
          onPressed: _loading ? null : _carregar,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody(FlutterFlowTheme theme) {
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_data!['revogacao_ativa'] != null) ...[
                  _buildRevogacaoBanner(theme),
                  const SizedBox(height: 10),
                ],
                _buildResumoCard(theme),
                const SizedBox(height: 10),
                _buildBarraAcoes(theme),
                _buildInfoOrdemCard(theme),
                const SizedBox(height: 10),
                _buildInfoObraCard(theme),
                const SizedBox(height: 10),
                _buildTarefasCard(theme),
                if ((_data!['custos'] as List?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  _buildCustosCard(theme),
                ],
                if (_shouldShowAssinaturasCard()) ...[
                  const SizedBox(height: 10),
                  _buildAssinaturasCard(theme),
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
            'Carregando ordem…',
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
              onPressed: _carregar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _statusChip(FlutterFlowTheme theme, int statusId) {
    final st = _statusOs[statusId] ??
        {'text': 'Desconhecido', 'color': theme.secondaryText};
    final Color cor =
        st['color'] is Color ? st['color'] as Color : theme.secondaryText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.28)),
      ),
      child: Text(
        st['text'] as String,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: cor,
        ),
      ),
    );
  }

  Widget _buildResumoCard(FlutterFlowTheme theme) {
    final d = _data!;
    final tot = _totais();
    final statusId = int.tryParse('${d['status_id'] ?? 1}') ?? 1;
    final codigo = '${d['codigo'] ?? d['id'] ?? '—'}';
    final nome = '${d['nome'] ?? ''}'.trim();
    final di = _formatDate(d['data_inicio']);
    final df = _formatDate(d['data_fim']);
    final periodo = [
      if (di.isNotEmpty) di,
      if (df.isNotEmpty) df,
    ].join(' → ');
    final nAssin = (d['assinaturas'] as List?)?.length ?? 0;

    return RdoSectionCard(
      title: codigo,
      subtitle: nome.isEmpty ? 'Ordem de serviço' : nome,
      icon: Icons.assignment_outlined,
      margin: EdgeInsets.zero,
      trailing: _statusChip(theme, statusId),
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          RdoKpiStrip(
            itens: [
              RdoKpiData(
                label: 'Tarefas',
                value: '${_tarefas().length}',
              ),
              RdoKpiData(
                label: 'Valor total',
                value: _formatCurrency(tot['valorTotal']),
                flex: 2,
                destaque: true,
              ),
              RdoKpiData(
                label: 'Assinaturas',
                value: '$nAssin',
              ),
            ],
          ),
          Divider(height: 1, color: theme.alternate),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 14, color: theme.secondaryText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    periodo.isEmpty ? 'Período não informado' : periodo,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.secondaryText,
                    ),
                  ),
                ),
                Text(
                  'Emissão ${_formatDate(d['data_emissao']).isEmpty ? '—' : _formatDate(d['data_emissao'])}',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    bool outlined = false,
  }) {
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foregroundColor,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: foregroundColor.withValues(alpha: 0.45)),
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 10),
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 10),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: child,
    );
  }

  Widget _buildBarraAcoes(FlutterFlowTheme theme) {
    final d = _data!;
    final statusId = int.tryParse('${d['status_id'] ?? 1}') ?? 1;
    final podeRevogar = d['pode_solicitar_revogacao'] == true;
    final canEdit = MembershipAccess.canPermission('edit_ordens_servico');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdoSectionCard(
          title: 'Documento',
          icon: Icons.picture_as_pdf_outlined,
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gere o PDF da ordem de serviço para impressão ou compartilhamento.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                icon: Icons.picture_as_pdf_rounded,
                label: _pdfLoading ? 'Gerando…' : 'Imprimir PDF',
                onPressed: !_pdfLoading ? _onImprimirPdf : null,
                loading: _pdfLoading,
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ),
        if (statusId == 1 && canEdit)
          RdoSectionCard(
            title: 'Enviar para Aprovação',
            icon: Icons.send_rounded,
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Quando a ordem estiver pronta, envie para o fluxo de assinaturas.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                _buildActionButton(
                  icon: Icons.send_rounded,
                  label: _enviandoAprovacao
                      ? 'Enviando…'
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
                  'Solicite a revogação desta ordem aprovada para reabrir o fluxo.',
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

  Widget _buildRevogacaoBanner(FlutterFlowTheme theme) {
    final rev = _data!['revogacao_ativa'];
    if (rev is! Map) return const SizedBox.shrink();
    final rm = Map<String, dynamic>.from(rev);
    final solicitante = '${rm['solicitante'] ?? '-'}';
    final uuid = '${rm['uuid'] ?? ''}'.trim();
    final podeDecidir = _data!['usuario_pode_decidir_revogacao'] == true;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: rdoCardDecoration(context).copyWith(
        border: Border.all(color: theme.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: theme.warning.withValues(alpha: 0.08),
              border: Border(
                bottom: BorderSide(
                  color: theme.warning.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: theme.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Revogação em andamento · Solicitado por $solicitante',
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
          if (podeDecidir && uuid.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _onDecidirRevogacao(
                        aprovar: true,
                        revogacaoUuid: uuid,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.success,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Aprovar revogação'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _onDecidirRevogacao(
                        aprovar: false,
                        revogacaoUuid: uuid,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.error,
                        side: BorderSide(
                          color: theme.error.withValues(alpha: 0.45),
                        ),
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Rejeitar'),
                    ),
                  ),
                ],
              ),
            ),
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
            width: 96,
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

  Widget _buildInfoOrdemCard(FlutterFlowTheme theme) {
    final obs = _data!['observacoes']?.toString().trim() ?? '';
    return RdoSectionCard(
      title: 'Informações da Ordem',
      icon: Icons.info_outline_rounded,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _buildInfoRow(theme, 'Código', '${_data!['codigo'] ?? '—'}'),
          _buildInfoRow(
            theme,
            'Emissão',
            _formatDate(_data!['data_emissao']).isEmpty
                ? '—'
                : _formatDate(_data!['data_emissao']),
          ),
          _buildInfoRow(
            theme,
            'Observações',
            obs.isEmpty ? 'Nenhuma' : obs,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoObraCard(FlutterFlowTheme theme) {
    final obra = _obra();
    return RdoSectionCard(
      title: 'Informações da Obra',
      icon: Icons.apartment_outlined,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _buildInfoRow(theme, 'Nome', obra?['nome']?.toString() ?? '—'),
          _buildInfoRow(theme, 'Endereço', _enderecoObra()),
          _buildInfoRow(theme, 'Cidade/UF', _cidadeEstadoObra()),
        ],
      ),
    );
  }

  Widget _buildTarefasCard(FlutterFlowTheme theme) {
    final lista = _tarefasFiltradas();
    final n = _tarefas().length;
    final tot = _totais();
    final saldo = tot['saldoTotal'] ?? 0;

    return RdoSectionCard(
      title: 'Tarefas',
      icon: Icons.task_alt_outlined,
      margin: EdgeInsets.zero,
      trailing: n == 0 ? null : RdoContadorChip('$n'),
      contentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildFilterChip(theme, 'todas', 'Todas ($n)'),
                _buildFilterChip(theme, 'pendentes', 'Pendentes'),
                _buildFilterChip(theme, 'concluidas', 'Concluídas'),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.primaryBackground.withValues(alpha: 0.55),
              border: Border(
                top: BorderSide(color: theme.alternate),
                bottom: BorderSide(color: theme.alternate),
              ),
            ),
            child: RdoKpiStrip(
              itens: [
                RdoKpiData(
                  label: 'Programado',
                  value: '${tot['programadaTotal']}',
                ),
                RdoKpiData(
                  label: 'Realizado',
                  value: '${tot['realizadaTotal']}',
                ),
                RdoKpiData(
                  label: 'Saldo',
                  value: '$saldo',
                  destaque: true,
                ),
              ],
            ),
          ),
          if (lista.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 36,
                    color: theme.secondaryText.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nenhuma tarefa neste filtro',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.secondaryText,
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < lista.length; i++) ...[
              if (i > 0)
                Divider(height: 1, thickness: 1, color: theme.alternate),
              _buildTarefaItem(theme, lista[i]),
            ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(FlutterFlowTheme theme, String key, String label) {
    final sel = _filtroTarefa == key;
    return FilterChip(
      selected: sel,
      showCheckmark: false,
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: sel ? Colors.white : theme.primaryText,
        ),
      ),
      selectedColor: theme.primary,
      backgroundColor: theme.secondaryBackground,
      side: BorderSide(color: sel ? theme.primary : theme.alternate),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (_) => setState(() => _filtroTarefa = key),
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

    return Material(
      color: theme.secondaryBackground,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: statusColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            desc,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Prog. ${t['qtd_programada'] ?? 0}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: theme.secondaryText,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Real. ${t['qtd_realizada'] ?? 0}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Saldo ${m['saldo']}',
                            textAlign: TextAlign.end,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (pct.clamp(0, 100) / 100).toDouble(),
                              minHeight: 5,
                              backgroundColor: theme.alternate,
                              color:
                                  pct >= 100 ? theme.success : theme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: pct >= 100 ? theme.success : theme.primary,
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
      ),
    );
  }

  Widget _buildCustosCard(FlutterFlowTheme theme) {
    final custos = _data!['custos'] as List? ?? [];
    final tot = _totais();
    final bdiPct = num.tryParse('${_data!['percentual_bdi'] ?? 0}') ?? 0;
    final impPct = num.tryParse('${_data!['percentual_impostos'] ?? 0}') ?? 0;

    return RdoSectionCard(
      title: 'Custos e Tributos',
      icon: Icons.payments_outlined,
      margin: EdgeInsets.zero,
      trailing: RdoContadorChip('${custos.length}'),
      contentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < custos.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: theme.alternate),
            if (custos[i] is Map)
              _buildCustoItem(
                theme,
                Map<String, dynamic>.from(custos[i] as Map),
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
                RdoKpiStrip(
                  itens: [
                    RdoKpiData(
                      label: 'Custos',
                      value: _formatCurrency(tot['custoTotal']),
                    ),
                    if (bdiPct > 0)
                      RdoKpiData(
                        label: 'BDI ($bdiPct%)',
                        value: _formatCurrency(tot['valorBdi']),
                      ),
                    if (impPct > 0)
                      RdoKpiData(
                        label: 'Impostos ($impPct%)',
                        value: _formatCurrency(tot['valorImpostos']),
                      ),
                    RdoKpiData(
                      label: 'Total',
                      value: _formatCurrency(tot['valorTotal']),
                      destaque: true,
                      flex: 2,
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

  Widget _buildCustoItem(FlutterFlowTheme theme, Map<String, dynamic> c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${c['descricao'] ?? ''}',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Un ${c['unidade'] ?? '—'} · Qtd ${c['qtd_prevista'] ?? '—'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.secondaryText,
                  ),
                ),
              ),
              Text(
                _formatCurrency(num.tryParse('${c['valor_total'] ?? 0}')),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Unitário ${_formatCurrency(num.tryParse('${c['valor_unitario'] ?? 0}'))}',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: theme.secondaryText,
            ),
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

  Widget _buildAssinaturasCard(FlutterFlowTheme theme) {
    final d = _data!;
    final statusId = int.tryParse('${d['status_id'] ?? 1}') ?? 1;
    final assinaturasRaw = d['assinaturas'];
    final listaAssin = assinaturasRaw is List ? assinaturasRaw : const [];
    final nAssin = listaAssin.length;

    String? subtitle;
    if (statusId == 2) {
      subtitle = 'Aguardando aprovação na fila';
    } else if (statusId == 3) {
      subtitle = 'Ordem aprovada';
    }

    Widget inner;
    if (statusId == 2) {
      inner = _buildFluxoAssinaturasBody(theme);
    } else if (statusId == 3) {
      inner = _buildCarimboAprovacaoBody(theme, d);
    } else {
      inner = _buildListaAssinaturasSimples(theme, listaAssin);
    }

    final contagem = statusId == 2
        ? (_fluxo is Map && (_fluxo!['assinaturas'] is List)
            ? (_fluxo!['assinaturas'] as List).length
            : null)
        : (statusId == 3
            ? (_aprovadoresPayload?['aprovadores'] is List
                ? (_aprovadoresPayload!['aprovadores'] as List).length
                : null)
            : nAssin);

    return RdoSectionCard(
      title: 'Assinaturas',
      subtitle: subtitle,
      icon: Icons.draw_outlined,
      margin: EdgeInsets.zero,
      trailing: contagem != null && contagem > 0
          ? RdoContadorChip('$contagem')
          : null,
      contentPadding: EdgeInsets.zero,
      child: inner,
    );
  }

  Widget _buildListaAssinaturasSimples(FlutterFlowTheme theme, List list) {
    if (list.isEmpty) {
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
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0)
            Divider(height: 1, thickness: 1, color: theme.alternate),
          if (list[i] is Map)
            _buildLinhaAssinaturaCompacta(
              theme,
              Map<String, dynamic>.from(list[i] as Map),
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
        : (a['nome_assinante'] ?? a['assinante'] ?? a['assinante_id'])
            ?.toString();
    final pos = a['posicao'];
    final sit = '${a['situacao'] ?? a['status'] ?? a['status_texto'] ?? '—'}';
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
                if (data != null && _strOs(data).isNotEmpty)
                  Text(
                    _formatDataHoraMiniOs(data),
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

  Widget _buildFluxoAssinaturasBody(FlutterFlowTheme theme) {
    if (_fluxoLoading) {
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
    final proxNome = prox is Map ? _strOs(prox['nome']) : '';
    final canApprove =
        MembershipAccess.canPermission('approve_ordens_servico');

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
                    _buildLinhaFluxoAssinatura(
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
            child: canApprove
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('SUA DECISÃO', style: rdoColumnLabelStyle(context)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.success,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                minimumSize: const Size(0, 38),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                minimumSize: const Size(0, 38),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
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
                  )
                : Text(
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
    FlutterFlowTheme theme,
    Map<String, dynamic> a, {
    bool isLast = false,
  }) {
    final situacao = _strOs(a['situacao']);
    final numSit = a['situacao_numero'];
    final proximo = a['e_proximo'] == true;
    final nome = _strOs(a['nome']);
    final pos = _strOs(a['posicao']);

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
                            'Aguardando esta assinatura',
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
                      border: Border.all(
                        color: chipColor.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: chipColor),
                        const SizedBox(width: 4),
                        Text(
                          situacao.isEmpty
                              ? (proximo ? 'Na fila' : '—')
                              : situacao,
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

  Widget _buildCarimboAprovacaoBody(
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
                  'Ordem aprovada',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: theme.success,
                  ),
                ),
              ),
              if (ultima != null)
                Text(
                  _formatDataHoraMiniOs(ultima).split(' ').first,
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
            _buildCarimboAprovador(
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
              Icon(Icons.shield_outlined, size: 14, color: theme.secondaryText),
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

  Widget _buildCarimboAprovador(
    FlutterFlowTheme theme,
    Map<String, dynamic> a, {
    required bool destaque,
  }) {
    final nome = _strOs(a['nome']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: destaque ? theme.success : theme.primary,
            radius: 18,
            child: Text(
              _iniciaisNome(nome.isEmpty ? null : nome),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
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
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _cargoExibicao(a),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
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

  String _hashCarimbo(dynamic ordemId, dynamic ultima) {
    final s =
        'OS-${ordemId ?? '0'}-${ultima ?? DateTime.now().toIso8601String()}';
    final b = base64Encode(utf8.encode(s));
    return b.length >= 8 ? b.substring(0, 8) : b;
  }
}
