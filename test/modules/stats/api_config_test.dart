import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/config/api_config.dart';
import 'package:listenfy/app/data/network/dio_client.dart';

void main() {
  const override = String.fromEnvironment('API_BASE_URL');
  test('native debug uses the remote backend unless explicitly overridden', () {
    if (override.trim().isNotEmpty) {
      expect(ApiConfig.baseUrl, override.trim());
    } else {
      final uri = Uri.parse(ApiConfig.baseUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, isNot('localhost'));
      expect(uri.host, isNot('127.0.0.1'));
    }
  });
  test('download API requests use the configured backend', () {
    final client = DioClient();
    addTearDown(() => client.dio.close());
    expect(client.dio.options.baseUrl, '${ApiConfig.baseUrl}/api/v1');
  });
}
