import 'package:dio/dio.dart';

// Mixin for sources that support account-based authentication.
// When SourceCredentials exist in the DB for this source, the app calls
// restore() once at startup. On 401, AuthService emits a sessionExpired event
// and the UI prompts the user to re-login via /source-credentials/:sourceId.
mixin SourceAuth {
  bool get requiresLogin => false;

  // POST credentials to the source API.
  // Throws on failure (DioException or Exception) — caller handles.
  // Implementations should also store the resulting token/session internally
  // so it is available for subsequent requests via configureAuthInterceptors().
  Future<void> login(Dio client, String username, String password);

  // Returns true if the current session is still valid.
  // Called before login() to avoid unnecessary re-authentication.
  Future<bool> checkLogin(Dio client);

  // Called on app start with stored credentials from the DB.
  // Returns true if the session was successfully restored.
  // Override when tokens stored in extraJson need to be loaded before
  // checkLogin() can succeed (e.g., JWT stored in extraJson).
  Future<bool> restore(
    Dio client, {
    required String? username,
    required String? password,
    required String? extraJson,
  }) async {
    if (await checkLogin(client)) return true;
    if (username != null && password != null) {
      try {
        await login(client, username, password);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  // Returns source-specific auth state (e.g., JWT) serialized as JSON for DB
  // storage. Called after login() to persist the token alongside credentials.
  // Override when the source stores a token beyond cookies (e.g., MangaLivre).
  String? get tokenAsJson => null;

  // Hook: override to add source-specific interceptors to the Dio client.
  // Called from HttpMangaSource._buildClient() for every SourceAuth source.
  // Use to inject Authorization header, refresh-token logic, etc.
  void configureAuthInterceptors(Dio dio) {}
}
