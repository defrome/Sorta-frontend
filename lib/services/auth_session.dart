import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    this.user,
    this.userId,
    this.userEmail,
  });

  final String accessToken;
  final String tokenType;
  final DateTime expiresAt;
  final AuthUser? user;
  final String? userId;
  final String? userEmail;

  bool isActive({DateTime? now, Duration clockSkew = Duration.zero}) {
    final currentTime = (now ?? DateTime.now()).toUtc().add(clockSkew);
    return currentTime.isBefore(expiresAt);
  }

  String get authorizationHeader {
    return AuthSessionStore.authorizationHeaderValue(
      accessToken: accessToken,
      tokenType: tokenType,
    );
  }
}

class AuthSessionStore {
  const AuthSessionStore._();

  static const _storage = FlutterSecureStorage();

  static Future<void> saveSession({
    required String accessToken,
    required String tokenType,
    AuthUser? user,
  }) async {
    await _storage.write(key: AuthStorageKeys.accessToken, value: accessToken);
    await _storage.write(
      key: AuthStorageKeys.tokenType,
      value: tokenType.trim().isEmpty ? 'bearer' : tokenType,
    );

    if (user != null) {
      await saveUser(user);
    }
  }

  static Future<void> saveUser(AuthUser user) async {
    await _storage.write(
      key: AuthStorageKeys.userJson,
      value: jsonEncode(user.toJson()),
    );
    await _storage.write(key: AuthStorageKeys.userId, value: user.id);
    await _storage.write(key: AuthStorageKeys.userEmail, value: user.email);
  }

  static Future<bool> grantLocalFreeAnalysesForTesting({int scans = 3}) async {
    final user = await _readUser();
    if (user == null) {
      return false;
    }

    final normalizedScans = scans < 0 ? 0 : scans;
    await saveUser(
      user.copyWith(
        subscriptionStatus: 'none',
        hasActiveSubscription: false,
        dailyFreeAnalysesLimit: normalizedScans,
        dailyFreeAnalysesUsed: 0,
        dailyFreeAnalysesRemaining: normalizedScans,
      ),
    );
    return true;
  }

  static Future<AuthSession?> readSession() async {
    final accessToken = await _storage.read(key: AuthStorageKeys.accessToken);
    if (accessToken == null || accessToken.trim().isEmpty) {
      return null;
    }

    final expiresAt = _jwtExpiresAt(accessToken);
    if (expiresAt == null) {
      return null;
    }

    final user = await _readUser();

    return AuthSession(
      accessToken: accessToken,
      tokenType:
          await _storage.read(key: AuthStorageKeys.tokenType) ?? 'Bearer',
      expiresAt: expiresAt,
      user: user,
      userId: user?.id ?? await _storage.read(key: AuthStorageKeys.userId),
      userEmail:
          user?.email ?? await _storage.read(key: AuthStorageKeys.userEmail),
    );
  }

  static Future<AuthSession?> readActiveSession({
    Duration clockSkew = const Duration(seconds: 15),
  }) async {
    final session = await readSession();
    if (session == null) {
      await clear();
      return null;
    }

    if (!session.isActive(clockSkew: clockSkew)) {
      await clear();
      return null;
    }

    return session;
  }

  static Future<String?> authorizationHeader({
    bool validateExpiry = true,
  }) async {
    if (!validateExpiry) {
      final accessToken = await _storage.read(key: AuthStorageKeys.accessToken);
      if (accessToken == null || accessToken.trim().isEmpty) {
        return null;
      }
      final tokenType =
          await _storage.read(key: AuthStorageKeys.tokenType) ?? 'Bearer';
      return authorizationHeaderValue(
        accessToken: accessToken,
        tokenType: tokenType,
      );
    }

    final session = await readActiveSession();
    return session?.authorizationHeader;
  }

  static String authorizationHeaderValue({
    required String accessToken,
    required String tokenType,
  }) {
    final trimmedType = tokenType.trim();
    final normalizedType = trimmedType.isEmpty
        ? 'Bearer'
        : trimmedType.toLowerCase() == 'bearer'
        ? 'Bearer'
        : trimmedType;
    return '$normalizedType $accessToken';
  }

  static Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: AuthStorageKeys.accessToken),
      _storage.delete(key: AuthStorageKeys.tokenType),
      _storage.delete(key: AuthStorageKeys.userJson),
      _storage.delete(key: AuthStorageKeys.userId),
      _storage.delete(key: AuthStorageKeys.userEmail),
    ]);
  }

  static Future<AuthUser?> _readUser() async {
    final rawUser = await _storage.read(key: AuthStorageKeys.userJson);
    if (rawUser == null || rawUser.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        return AuthUser.fromJson(decoded);
      }
      if (decoded is Map) {
        return AuthUser.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      await _storage.delete(key: AuthStorageKeys.userJson);
    }

    return null;
  }

  static DateTime? _jwtExpiresAt(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final payloadBytes = base64Url.decode(base64Url.normalize(parts[1]));
      final payload = jsonDecode(utf8.decode(payloadBytes));
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final exp = _intValue(payload['exp']);
      if (exp == null) {
        return null;
      }

      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }
}

class AuthStorageKeys {
  const AuthStorageKeys._();

  static const accessToken = 'auth.access_token';
  static const tokenType = 'auth.token_type';
  static const userJson = 'auth.user_json';
  static const userId = 'auth.user.id';
  static const userEmail = 'auth.user.email';
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
