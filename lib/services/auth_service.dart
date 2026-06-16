import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/auth_user.dart';
import 'api_service.dart';
import 'auth_session.dart';

class AuthService {
  AuthService({http.Client? client, Uri? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiService.defaultBaseUrl(),
      _ownsClient = client == null;

  final http.Client _client;
  final Uri _baseUrl;
  final bool _ownsClient;

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<AuthUser> fetchMe({bool validateExpiry = false}) async {
    final authHeader = await AuthSessionStore.authorizationHeader(
      validateExpiry: validateExpiry,
    );
    if (authHeader == null) {
      throw const AuthUnauthorizedException();
    }

    final response = await _client.get(
      _baseUrl.replace(path: '/api/v1/auth/me'),
      headers: {HttpHeaders.authorizationHeader: authHeader},
    );

    if (response.statusCode == HttpStatus.unauthorized) {
      await AuthSessionStore.clear();
      throw const AuthUnauthorizedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(_backendError(response));
    }

    final decoded = jsonDecode(response.body);
    final user = AuthUser.fromJson(_mapValue(decoded));
    await AuthSessionStore.saveUser(user);
    return user;
  }

  Future<AuthUser> grantDevFreeAnalyses() async {
    final authHeader = await AuthSessionStore.authorizationHeader(
      validateExpiry: false,
    );
    if (authHeader == null) {
      throw const AuthUnauthorizedException();
    }

    final response = await _client.post(
      _baseUrl.replace(path: '/api/v1/auth/dev/grant-free-analyses'),
      headers: {HttpHeaders.authorizationHeader: authHeader},
    );

    if (response.statusCode == HttpStatus.unauthorized) {
      await AuthSessionStore.clear();
      throw const AuthUnauthorizedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(_backendError(response));
    }

    final decoded = jsonDecode(response.body);
    final user = AuthUser.fromJson(_mapValue(decoded));
    await AuthSessionStore.saveUser(user);
    return user;
  }

  String _backendError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
      return 'Auth request failed (${response.statusCode}).';
    }

    return 'Auth request failed (${response.statusCode}).';
  }
}

class AuthUnauthorizedException implements Exception {
  const AuthUnauthorizedException();
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return const {};
}
