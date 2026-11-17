import 'dart:io';

import 'package:client/client.dart';
import 'package:http/io_client.dart';

import 'config.dart';

/// Cliente de la API para mobile y escritorio (`dart:io`).
ApiClient createApiClient() {
  final baseUrl = Uri.parse(AppConfig.apiUrl);
  final io = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    // El backend lo guarda en la lista de sesiones del usuario.
    ..userAgent = '${AppConfig.appName} (${Platform.operatingSystem})';

  if (AppConfig.allowBadCertificates) {
    io.badCertificateCallback = (_, host, _) => host == baseUrl.host;
  }

  return ApiClient(
    baseUrl: baseUrl,
    httpClient: IOClient(io),
    headers: const {'accept-language': 'es'},
  );
}
