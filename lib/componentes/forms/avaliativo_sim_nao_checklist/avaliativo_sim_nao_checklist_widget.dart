import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AvaliativoSimNaoChecklistWidget extends StatefulWidget {
  const AvaliativoSimNaoChecklistWidget({
    super.key,
    required this.areaId,
    required this.itemId,
    this.valorAtual,
  });

  final dynamic areaId;
  final dynamic itemId;
  final bool? valorAtual;

  @override
  State<AvaliativoSimNaoChecklistWidget> createState() =>
      _AvaliativoSimNaoChecklistWidgetState();
}

class _AvaliativoSimNaoChecklistWidgetState
    extends State<AvaliativoSimNaoChecklistWidget> {
  bool? _valor;

  @override
  void initState() {
    super.initState();
    _valor = widget.valorAtual;
  }

  Future<void> _salvar(bool valor) async {
    setState(() => _valor = valor);
    await actions.salvarRespostaBoolean(
      FFAppState().checklistAtualJson,
      widget.areaId.toString(),
      widget.itemId.toString(),
      valor,
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _salvar(true),
            style: OutlinedButton.styleFrom(
              backgroundColor: _valor == true
                  ? theme.success.withValues(alpha: 0.15)
                  : theme.secondaryBackground,
              side: BorderSide(
                color: _valor == true ? theme.success : theme.alternate,
              ),
            ),
            child: Text(
              'Sim',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: _valor == true ? theme.success : theme.primaryText,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _salvar(false),
            style: OutlinedButton.styleFrom(
              backgroundColor: _valor == false
                  ? theme.error.withValues(alpha: 0.12)
                  : theme.secondaryBackground,
              side: BorderSide(
                color: _valor == false ? theme.error : theme.alternate,
              ),
            ),
            child: Text(
              'Não',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: _valor == false ? theme.error : theme.primaryText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
