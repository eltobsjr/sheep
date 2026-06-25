import 'package:dio/dio.dart';

// Mixin for sources that support account-based authentication.
// When SourceCredentials exist in the DB for this source, the app calls
// login() once and stores the resulting session cookies in the source's
// cookie jar. checkLogin() is called to validate the session is still active.
mixin SourceAuth {
  bool get requiresLogin => false;

  Future<void> login(Dio client, String username, String password);

  Future<bool> checkLogin(Dio client);
}
