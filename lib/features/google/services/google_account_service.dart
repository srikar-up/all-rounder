import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleAccountService {
  static const driveScopes = <String>[
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  GoogleSignInAccount? _user;
  bool _initialized = false;

  GoogleSignInAccount? get user => _user;
  bool get isConnected => _user != null;
  String? get email => _user?.email;
  String? get displayName => _user?.displayName;

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      await GoogleSignIn.instance.initialize();
      _initialized = true;
      final pending = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (pending != null) {
        _user = await pending;
      }
    } catch (_) {
      // Graceful fallback on non-Android or devices without Google Play Services
      _initialized = true;
    }
  }

  /// Call from a button tap handler
  Future<bool> connect() async {
    await init();
    try {
      final user = await GoogleSignIn.instance.authenticate(scopeHint: driveScopes);
      _user = user;
      final auth = user.authorizationClient;
      final existing = await auth.authorizationForScopes(driveScopes);
      if (existing == null) {
        await auth.authorizeScopes(driveScopes);
      }
      return true;
    } on GoogleSignInException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fresh authorization headers for each batch of requests
  Future<Map<String, String>?> headers() async {
    final u = _user;
    if (u == null) return null;
    try {
      return await u.authorizationClient.authorizationHeaders(driveScopes);
    } catch (_) {
      return null;
    }
  }

  Future<void> disconnect({bool revoke = false}) async {
    try {
      if (revoke) {
        await GoogleSignIn.instance.disconnect();
      } else {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    _user = null;
  }
}

class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
