import 'dart:async';
import 'package:flutter/services.dart';

abstract interface class WifiDirectTransport {
  Stream<Map<String, dynamic>> get events;
  Future<String> prepare(Map<String, dynamic> credentials);
  Future<void> startHost();
  Future<void> join(Map<String, dynamic> credentials);
  Future<void> send(
    String path,
    Map<String, dynamic> descriptor, {
    String? coverPath,
  });
  Future<void> confirm(int payloadId);
  Future<void> close();
}

class MethodChannelWifiDirectTransport implements WifiDirectTransport {
  static const _methods = MethodChannel('listenfy/wifi_direct');
  static const _events = EventChannel('listenfy/wifi_direct/events');
  @override
  Stream<Map<String, dynamic>> get events => _events
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));
  @override
  Future<String> prepare(Map<String, dynamic> credentials) async {
    final result = await _methods.invokeMapMethod<String, dynamic>(
      'prepare',
      credentials,
    );
    final fingerprint = result?['fingerprint'];
    if (fingerprint is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)) {
      throw const FormatException('Invalid certificate fingerprint');
    }
    return fingerprint;
  }

  @override
  Future<void> startHost() => _methods.invokeMethod<void>('startHost');
  @override
  Future<void> join(Map<String, dynamic> credentials) =>
      _methods.invokeMethod<void>('join', credentials);
  @override
  Future<void> send(
    String path,
    Map<String, dynamic> descriptor, {
    String? coverPath,
  }) => _methods.invokeMethod<void>('send', {
    'path': path,
    'descriptor': descriptor,
    'coverPath': coverPath,
  });
  @override
  Future<void> confirm(int payloadId) =>
      _methods.invokeMethod<void>('confirm', {'payloadId': payloadId});
  @override
  Future<void> close() => _methods.invokeMethod<void>('close');
}
