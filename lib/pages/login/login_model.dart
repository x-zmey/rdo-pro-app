import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'login_widget.dart' show LoginWidget;
import 'package:flutter/material.dart';

class LoginModel extends FlutterFlowModel<LoginWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - checkInternetConnection] action in Login widget.
  bool? result;
  // State field(s) for emailAddress widget.
  FocusNode? emailAddressFocusNode;
  TextEditingController? emailAddressTextController;
  String? Function(BuildContext, String?)? emailAddressTextControllerValidator;
  // State field(s) for password widget.
  FocusNode? passwordFocusNode;
  TextEditingController? passwordTextController;
  late bool passwordVisibility;
  String? Function(BuildContext, String?)? passwordTextControllerValidator;
  // Stores action output result for [Backend Call - API (login)] action in Button widget.
  ApiCallResponse? apiResultrtk;

  @override
  void initState(BuildContext context) {
    passwordVisibility = false;
    emailAddressTextControllerValidator = _emailValidator;
    passwordTextControllerValidator = _passwordValidator;
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? _emailValidator(BuildContext context, String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) {
      return 'Informe o e-mail';
    }
    if (!_emailPattern.hasMatch(t)) {
      return 'E-mail inválido';
    }
    return null;
  }

  static String? _passwordValidator(BuildContext context, String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe a senha';
    }
    return null;
  }

  @override
  void dispose() {
    emailAddressFocusNode?.dispose();
    emailAddressTextController?.dispose();

    passwordFocusNode?.dispose();
    passwordTextController?.dispose();
  }
}
