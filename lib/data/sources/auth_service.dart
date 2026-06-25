import 'dart:async';

import 'package:dio/dio.dart';

// Thrown when a source returns 401 — session expired.
class AuthExpiredException implements Exception {
  const AuthExpiredException({
    required this.sourceId,
    required this.sourceName,
  });

  final String sourceId;
  final String sourceName;
}

// Singleton bus between the network layer and the UI.
// Flow:
//   1. AuthInterceptor sees 401 → emits AuthExpiredException
//   2. SheepApp listens, shows "session expired" dialog
//   3. User taps → GoRouter pushes /source-credentials/:sourceId
//   4. User re-enters credentials → source.login() called → new token stored
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _controller = StreamController<AuthExpiredException>.broadcast();
  Stream<AuthExpiredException> get sessionExpired => _controller.stream;

  void notifyExpired(String sourceId, String sourceName) =>
      _controller.add(AuthExpiredException(
        sourceId: sourceId,
        sourceName: sourceName,
      ));
}

// Added to every HttpMangaSource that mixes in SourceAuth.
// Detects 401 and routes to AuthService.
class AuthInterceptor extends Interceptor {
  const AuthInterceptor({
    required this.sourceId,
    required this.sourceName,
  });

  final String sourceId;
  final String sourceName;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      AuthService.instance.notifyExpired(sourceId, sourceName);
    }
    handler.next(err);
  }
}
