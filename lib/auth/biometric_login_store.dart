import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resultado do prompt do sistema (impressão digital, rosto ou PIN do aparelho).
enum BiometricPromptResult {
  success,
  cancelled,
  notAvailable,
  notEnrolled,
  credentialsMissing,
  error,
}

/// Credenciais após desbloqueio biométrico / PIN do aparelho.
class BiometricCredentialsResult {
  const BiometricCredentialsResult({
    required this.status,
    this.email,
    this.password,
  });

  final BiometricPromptResult status;
  final String? email;
  final String? password;

  bool get isSuccess =>
      status == BiometricPromptResult.success &&
      email != null &&
      email!.isNotEmpty &&
      password != null;
}

/// Credenciais criptografadas no cofre do SO + desbloqueio com biometria/PIN.
class BiometricLoginStore {
  BiometricLoginStore._();

  static const _prefsKeyEnabled = 'ff_biometric_login_enabled';
  static const _kEmail = 'bio_login_email';
  static const _kPassword = 'bio_login_password';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Mensagens do diálogo nativo do Android/iOS (padrão do sistema).
  static const List<AuthMessages> _authMessages = <AuthMessages>[
    AndroidAuthMessages(
      signInTitle: 'Entrar no RDO Pro',
      cancelButton: 'Cancelar',
      biometricHint: 'Toque no sensor',
      deviceCredentialsRequiredTitle: 'Desbloqueie o aparelho',
      goToSettingsButton: 'Configurações',
      goToSettingsDescription:
          'Cadastre impressão digital ou reconhecimento facial nas configurações do aparelho.',
    ),
    IOSAuthMessages(
      cancelButton: 'Cancelar',
      goToSettingsButton: 'Ajustes',
      goToSettingsDescription:
          'Configure Face ID ou Touch ID em Ajustes do iPhone.',
      lockOut: 'Biometria bloqueada. Use o código do aparelho.',
    ),
  ];

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_prefsKeyEnabled) ?? false;
  }

  /// Há credenciais salvas no cofre (além da flag de “ativado”).
  static Future<bool> hasStoredCredentials() async {
    if (!await isEnabled()) return false;
    final email = await _storage.read(key: _kEmail);
    return email != null && email.trim().isNotEmpty;
  }

  /// Dispositivo suporta biometria ou PIN/padrão do aparelho.
  static Future<bool> hardwareAvailable() async {
    if (kIsWeb) return false;
    final auth = LocalAuthentication();
    return auth.isDeviceSupported();
  }

  /// Salva e-mail e senha (criptografados) e marca login por biometria ativo.
  static Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _kEmail, value: email.trim());
    await _storage.write(key: _kPassword, value: password);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefsKeyEnabled, true);
  }

  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefsKeyEnabled);
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kPassword);
  }

  /// Exibe o prompt nativo do sistema (igual a outros apps: biometria + PIN).
  static Future<BiometricPromptResult> _authenticate({
    required String localizedReason,
  }) async {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) {
      return BiometricPromptResult.notAvailable;
    }

    try {
      final ok = await auth.authenticate(
        localizedReason: localizedReason,
        authMessages: _authMessages,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: false,
          useErrorDialogs: true,
        ),
      );
      return ok
          ? BiometricPromptResult.success
          : BiometricPromptResult.cancelled;
    } on PlatformException catch (e) {
      return _mapPlatformException(e);
    }
  }

  static BiometricPromptResult _mapPlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
      case 'notAvailable':
      case 'not_fragment_activity':
        return BiometricPromptResult.notAvailable;
      case 'NotEnrolled':
      case 'notEnrolled':
        return BiometricPromptResult.notEnrolled;
      case 'UserCanceled':
      case 'Canceled':
      case 'auth_in_progress':
        return BiometricPromptResult.cancelled;
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return BiometricPromptResult.error;
      default:
        return BiometricPromptResult.error;
    }
  }

  /// Após o usuário passar no prompt do sistema, devolve credenciais guardadas.
  static Future<BiometricCredentialsResult> readWithBiometric({
    required String localizedReason,
  }) async {
    if (!await isEnabled()) {
      return const BiometricCredentialsResult(
        status: BiometricPromptResult.credentialsMissing,
      );
    }

    final authStatus = await _authenticate(localizedReason: localizedReason);
    if (authStatus != BiometricPromptResult.success) {
      return BiometricCredentialsResult(status: authStatus);
    }

    final email = await _storage.read(key: _kEmail);
    final password = await _storage.read(key: _kPassword);
    if (email == null ||
        email.trim().isEmpty ||
        password == null ||
        password.isEmpty) {
      await clearAll();
      return const BiometricCredentialsResult(
        status: BiometricPromptResult.credentialsMissing,
      );
    }

    return BiometricCredentialsResult(
      status: BiometricPromptResult.success,
      email: email.trim(),
      password: password,
    );
  }

  /// Indica se o botão “Entrar com biometria” deve aparecer na tela de login.
  static Future<bool> shouldShowLoginButton() async {
    if (!await hardwareAvailable()) return false;
    if (!await isEnabled()) return false;
    return hasStoredCredentials();
  }
}
