import 'package:dio/dio.dart';
import '../../config/api_config.dart';

class DioClient {
  late final Dio dio;

  DioClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}/api/v1',
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options, // ✅ nuevo
    CancelToken? cancelToken, // opcional útil
    ProgressCallback? onReceiveProgress, // opcional
  }) {
    return dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options, // ✅ nuevo
    CancelToken? cancelToken, // opcional
    ProgressCallback? onSendProgress, // opcional
    ProgressCallback? onReceiveProgress, // opcional
  }) {
    return dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<void> download(
    String path,
    String savePath, {
    void Function(int received, int total)? onProgress,
    Options? options, // ✅ nuevo (para override por request)
    CancelToken? cancelToken, // opcional
  }) {
    return dio.download(
      path,
      savePath,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
      options:
          options ??
          Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
            receiveTimeout: const Duration(minutes: 5),
            sendTimeout: const Duration(minutes: 2),
          ),
    );
  }
}
