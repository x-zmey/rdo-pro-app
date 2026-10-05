import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/mao_obra_presenca_horas.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'hora_saida_funcionario_model.dart';
export 'hora_saida_funcionario_model.dart';

class HoraSaidaFuncionarioWidget extends StatefulWidget {
  const HoraSaidaFuncionarioWidget({
    super.key,
    required this.uuid,
    required this.hora,
  });

  final String? uuid;
  final String? hora;

  @override
  State<HoraSaidaFuncionarioWidget> createState() =>
      _HoraSaidaFuncionarioWidgetState();
}

class _HoraSaidaFuncionarioWidgetState
    extends State<HoraSaidaFuncionarioWidget> {
  late HoraSaidaFuncionarioModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HoraSaidaFuncionarioModel());

    _model.textController ??= TextEditingController(text: widget!.hora);
    _model.textFieldFocusNode ??= FocusNode();

    _model.textFieldMask = MaskTextInputFormatter(mask: '##:##');
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: TextFormField(
        controller: _model.textController,
        focusNode: _model.textFieldFocusNode,
        onChanged: (_) => EasyDebounce.debounce(
          '_model.textController',
          Duration(milliseconds: 2000),
          () async {
            _model.maoObraDetalhes =
                await SQLiteManager.instance.getMaoObraRelatorioDetalhes(
              uuid: widget!.uuid!,
            );
            await SQLiteManager.instance.updateMaoObraRelatorio(
              horaEntrada: _model.maoObraDetalhes?.firstOrNull?.horaEntrada,
              uuid: widget!.uuid!,
              status: _model.maoObraDetalhes?.firstOrNull?.statusPresenca,
              horaSaida: _model.textController.text,
              intervaloInicio:
                  _model.maoObraDetalhes?.firstOrNull?.intervaloInicio,
              intervaloFim: _model.maoObraDetalhes?.firstOrNull?.intervaloFim,
              horasTrabalhadas: horasTrabalhadasParaPersistir(
                _model.maoObraDetalhes?.firstOrNull?.statusPresenca),

              motivoAusencia:
                  _model.maoObraDetalhes?.firstOrNull?.motivoAusencia,
              motivoSaidaCedo: (_model.maoObraDetalhes?.firstOrNull
                          ?.motivoSaidaCedo ??
                      '')
                  .replaceAll("'", "''"),
              motivoAtraso: (_model.maoObraDetalhes?.firstOrNull?.motivoAtraso ??
                      '')
                  .replaceAll("'", "''"),
            );

            _model.updatePage(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Dados Salvos!',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).alternate,
                  ),
                ),
                duration: Duration(milliseconds: 4000),
                backgroundColor: FlutterFlowTheme.of(context).secondary,
              ),
            );

            safeSetState(() {});
          },
        ),
        autofocus: false,
        obscureText: false,
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Saída',
          labelStyle: FlutterFlowTheme.of(context).bodySmall.override(
                font: GoogleFonts.inter(
                  fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                ),
                fontSize: 16.0,
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
              ),
          hintText: '08:00',
          hintStyle: FlutterFlowTheme.of(context).bodyLarge.override(
                font: GoogleFonts.inter(
                  fontWeight: FlutterFlowTheme.of(context).bodyLarge.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                ),
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).bodyLarge.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
              ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: FlutterFlowTheme.of(context).alternate,
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(6.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color(0x00000000),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(6.0),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color(0x00000000),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(6.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color(0x00000000),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(6.0),
          ),
          filled: true,
          fillColor: FlutterFlowTheme.of(context).secondaryBackground,
        ),
        style: FlutterFlowTheme.of(context).bodySmall.override(
              font: GoogleFonts.inter(
                fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
              ),
              fontSize: 14.0,
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
              lineHeight: 0.7,
            ),
        maxLength: 5,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        buildCounter: (context,
                {required currentLength, required isFocused, maxLength}) =>
            null,
        keyboardType: TextInputType.number,
        validator: _model.textControllerValidator.asValidator(context),
        inputFormatters: [_model.textFieldMask],
      ),
    );
  }
}
