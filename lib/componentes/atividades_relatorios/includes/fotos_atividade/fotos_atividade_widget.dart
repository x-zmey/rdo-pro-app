import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'fotos_atividade_model.dart';
export 'fotos_atividade_model.dart';

class FotosAtividadeWidget extends StatefulWidget {
  const FotosAtividadeWidget({
    super.key,
    required this.parameter1,
  });

  final int? parameter1;

  @override
  State<FotosAtividadeWidget> createState() => _FotosAtividadeWidgetState();
}

class _FotosAtividadeWidgetState extends State<FotosAtividadeWidget> {
  late FotosAtividadeModel _model;
  bool _isCarregandoFoto = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FotosAtividadeModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fotos',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.interTight(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleMedium.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).primary,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleMedium.fontStyle,
                  ),
            ),
            Container(
              width: double.infinity,
              height: 135.6,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).primaryBackground,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 2.0,
                ),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
                child: InkWell(
                  splashColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () async {
                    if (_isCarregandoFoto) return;
                    final aid = widget.parameter1;
                    if (aid == null) return;

                    final origem = await showModalBottomSheet<String>(
                      context: context,
                      showDragHandle: true,
                      builder: (ctx) {
                        final t = FlutterFlowTheme.of(ctx);
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                  child: Text(
                                    'Adicionar foto',
                                    style: t.titleSmall.override(
                                      font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                ListTile(
                                  leading: Icon(Icons.photo_library_outlined, color: t.primary),
                                  title: const Text('Galeria'),
                                  subtitle: const Text('Escolher uma ou várias imagens'),
                                  onTap: () => Navigator.pop(ctx, 'galeria'),
                                ),
                                ListTile(
                                  leading: Icon(Icons.photo_camera_outlined, color: t.primary),
                                  title: const Text('Câmera'),
                                  subtitle: const Text('Tirar uma foto agora'),
                                  onTap: () => Navigator.pop(ctx, 'camera'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );

                    if (!context.mounted || origem == null) return;
                    if (origem == 'camera') {
                      final confirmarCamera = await showDialog<bool>(
                        context: context,
                        builder: (ctx) {
                          final t = FlutterFlowTheme.of(ctx);
                          return AlertDialog(
                            title: Text(
                              'Antes de tirar a foto',
                              style: t.titleMedium.override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: t.titleMedium.fontStyle,
                                ),
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.asset(
                                    'assets/images/giro.gif',
                                    width: 220.0,
                                    height: 140.0,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 12.0),
                                Text(
                                  'O formato ideal da foto e na horizontal.',
                                  textAlign: TextAlign.center,
                                  style: t.bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: t.bodyMedium.fontWeight,
                                      fontStyle: t.bodyMedium.fontStyle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Entendido'),
                              ),
                            ],
                          );
                        },
                      );
                      if (!context.mounted || confirmarCamera != true) return;
                    }

                    try {
                      safeSetState(() {
                        _isCarregandoFoto = true;
                      });
                      await actions.addFotosAtividade(
                        aid,
                        FFAppState().creatorId,
                        useCamera: origem == 'camera',
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString(),
                            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
                          ),
                          backgroundColor: FlutterFlowTheme.of(context).error,
                        ),
                      );
                      return;
                    } finally {
                      if (mounted) {
                        safeSetState(() {
                          _isCarregandoFoto = false;
                        });
                      }
                    }

                    if (!context.mounted) return;
                    FFAppState().reloadFotosTrigger =
                        !FFAppState().reloadFotosTrigger;
                    FFAppState().update(() {});

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          origem == 'camera'
                              ? 'Foto da câmera salva!'
                              : 'Fotos cadastradas!',
                          style: TextStyle(
                            color: FlutterFlowTheme.of(context).alternate,
                          ),
                        ),
                        duration: const Duration(milliseconds: 4000),
                        backgroundColor: FlutterFlowTheme.of(context).secondary,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_isCarregandoFoto)
                        SizedBox(
                          width: 44.0,
                          height: 44.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.0,
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        )
                      else
                        Icon(
                          Icons.cloud_upload_outlined,
                          color: FlutterFlowTheme.of(context).secondaryText,
                          size: 48.0,
                        ),
                      Text(
                        _isCarregandoFoto
                            ? 'Carregando foto...'
                            : 'Toque para escolher galeria ou câmera',
                        textAlign: TextAlign.center,
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.inter(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .fontStyle,
                            ),
                      ),
                      Text(
                        _isCarregandoFoto
                            ? 'Aguarde alguns segundos'
                            : 'JPG, PNG (máx. 10MB)',
                        textAlign: TextAlign.center,
                        style: FlutterFlowTheme.of(context).labelSmall.override(
                              font: GoogleFonts.inter(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontStyle,
                            ),
                      ),
                    ].divide(SizedBox(height: 12.0)),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
              ),
              child: custom_widgets.FotosAtividadeGrid(
                width: MediaQuery.sizeOf(context).width * 1.0,
                height: 370.0,
                atividadeId: widget.parameter1!,
                reloadTrigger: FFAppState().reloadFotosTrigger,
              ),
            ),
          ].divide(SizedBox(height: 16.0)),
        ),
      ),
    );
  }
}
