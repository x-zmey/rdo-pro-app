import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '/app_version.dart';
import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';

/// Prefixo para lembrar que o usuário dispensou o aviso opcional desta versão.
const _kDismissedPrefPrefix = 'ff_app_update_dismissed_';

enum AppUpdateKind { none, optional, required }

class AppUpdateDecision {
  const AppUpdateDecision({
    required this.kind,
    required this.localVersion,
    required this.latestVersion,
    required this.minRequiredVersion,
    this.storeUrl,
    this.message,
  });

  final AppUpdateKind kind;
  final String localVersion;
  final String latestVersion;
  final String minRequiredVersion;
  final String? storeUrl;
  final String? message;
}

/// Compara semver simples `X.Y.Z` (ignora sufixo após `-` ou `+`).
int compareSemver(String a, String b) {
  List<int> parse(String v) {
    final core = v.trim().split('+').first.split('-').first;
    final parts = core.split('.');
    return [
      for (var i = 0; i < 3; i++)
        i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
    ];
  }

  final pa = parse(a);
  final pb = parse(b);
  for (var i = 0; i < 3; i++) {
    final c = pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return 0;
}

String? currentStorePlatformKey() {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    default:
      return null;
  }
}

AppUpdateDecision evaluateAppUpdate({
  required String localVersion,
  required Map<String, dynamic> platformPayload,
}) {
  final latest = '${platformPayload['latest_version'] ?? ''}'.trim();
  final minReq = '${platformPayload['min_required_version'] ?? ''}'.trim();
  final storeUrl = '${platformPayload['store_url'] ?? ''}'.trim();
  final message = '${platformPayload['update_message'] ?? ''}'.trim();
  final forceUpdate = platformPayload['force_update'] == true;

  final effectiveLatest = latest.isNotEmpty ? latest : localVersion;
  final effectiveMin = minReq.isNotEmpty ? minReq : localVersion;

  final belowMin = compareSemver(localVersion, effectiveMin) < 0;
  final belowLatest = compareSemver(localVersion, effectiveLatest) < 0;

  AppUpdateKind kind = AppUpdateKind.none;
  if (belowMin || (forceUpdate && belowLatest)) {
    kind = AppUpdateKind.required;
  } else if (belowLatest) {
    kind = AppUpdateKind.optional;
  }

  return AppUpdateDecision(
    kind: kind,
    localVersion: localVersion,
    latestVersion: effectiveLatest,
    minRequiredVersion: effectiveMin,
    storeUrl: storeUrl.isEmpty ? null : storeUrl,
    message: message.isEmpty ? null : message,
  );
}

Future<String> _localAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final v = info.version.trim();
    if (v.isNotEmpty) return v;
  } catch (_) {}
  return kAppVersionName;
}

Future<bool> _wasOptionalDismissed({
  required String platform,
  required String latestVersion,
}) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('$_kDismissedPrefPrefix${platform}_$latestVersion') ??
      false;
}

Future<void> _markOptionalDismissed({
  required String platform,
  required String latestVersion,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(
    '$_kDismissedPrefPrefix${platform}_$latestVersion',
    true,
  );
}

Future<void> _openStoreUrl(String? url) async {
  final raw = (url ?? '').trim();
  if (raw.isEmpty) return;
  final uri = Uri.tryParse(raw);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Consulta `GET /api/app/version` e exibe diálogo se necessário.
/// Falhas de rede são ignoradas (não bloqueiam o app).
Future<void> checkAndPromptAppUpdate(BuildContext context) async {
  final platform = currentStorePlatformKey();
  if (platform == null) return;

  try {
    final response = await AppVersionPublicCall.call();
    if (response.statusCode < 200 || response.statusCode >= 300) return;

    final body = response.jsonBody;
    if (body is! Map) return;
    final data = body['data'];
    if (data is! Map) return;

    final platformRaw = data[platform];
    if (platformRaw is! Map) return;
    final platformPayload = Map<String, dynamic>.from(platformRaw);

    final localVersion = await _localAppVersion();
    final decision = evaluateAppUpdate(
      localVersion: localVersion,
      platformPayload: platformPayload,
    );

    if (decision.kind == AppUpdateKind.none) return;
    if (!context.mounted) return;

    if (decision.kind == AppUpdateKind.optional) {
      final dismissed = await _wasOptionalDismissed(
        platform: platform,
        latestVersion: decision.latestVersion,
      );
      if (dismissed || !context.mounted) return;
    }

    await showAppUpdateDialog(context, decision, platform: platform);
  } catch (e, s) {
    debugPrint('checkAndPromptAppUpdate: $e\n$s');
  }
}

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateDecision decision, {
  required String platform,
}) async {
  final theme = FlutterFlowTheme.of(context);
  final isRequired = decision.kind == AppUpdateKind.required;
  final defaultMsg = isRequired
      ? 'Esta versão do aplicativo não é mais suportada. Atualize para continuar.'
      : 'Há uma nova versão disponível. Recomendamos atualizar para ter as últimas melhorias.';
  final message = (decision.message ?? '').trim().isNotEmpty
      ? decision.message!
      : defaultMsg;

  await showDialog<void>(
    context: context,
    barrierDismissible: !isRequired,
    builder: (dialogContext) {
      return PopScope(
        canPop: !isRequired,
        child: AlertDialog(
          title: Text(
            isRequired ? 'Atualização obrigatória' : 'Atualização disponível',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              Text(
                'Versão instalada: ${decision.localVersion}\n'
                'Nova versão: ${decision.latestVersion}',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
          actions: [
            if (!isRequired)
              TextButton(
                onPressed: () async {
                  await _markOptionalDismissed(
                    platform: platform,
                    latestVersion: decision.latestVersion,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Agora não'),
              ),
            FilledButton(
              onPressed: () async {
                await _openStoreUrl(decision.storeUrl);
                if (!isRequired && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Atualizar'),
            ),
          ],
        ),
      );
    },
  );
}

/// Aguarda o splash e o navigator ficarem prontos, depois checa a versão.
Future<void> scheduleAppUpdateCheck({
  required bool Function() isSplashVisible,
  required BuildContext? Function() navigatorContext,
}) async {
  for (var i = 0; i < 60; i++) {
    if (!isSplashVisible() && navigatorContext() != null) break;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  final ctx = navigatorContext();
  if (ctx == null || !ctx.mounted) return;
  await checkAndPromptAppUpdate(ctx);
}
