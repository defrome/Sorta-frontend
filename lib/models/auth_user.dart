class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.authProvider,
    required this.subscriptionStatus,
    required this.hasActiveSubscription,
    required this.dailyFreeAnalysesLimit,
    required this.dailyFreeAnalysesUsed,
    required this.dailyFreeAnalysesRemaining,
    this.displayName,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = _stringValue(json['id']);
    final email = _stringValue(json['email']);
    if (id == null || email == null) {
      throw const FormatException('Invalid auth user payload.');
    }

    return AuthUser(
      id: id,
      email: email,
      authProvider: _stringValue(json['auth_provider']) ?? 'email',
      subscriptionStatus: _stringValue(json['subscription_status']) ?? 'none',
      hasActiveSubscription: _boolValue(json['has_active_subscription']),
      dailyFreeAnalysesLimit: _intValue(
        json['daily_free_analyses_limit'],
        fallback: 3,
      ),
      dailyFreeAnalysesUsed: _intValue(json['daily_free_analyses_used']),
      dailyFreeAnalysesRemaining: _intValue(
        json['daily_free_analyses_remaining'],
        fallback: 3,
      ),
      displayName: _nullableStringValue(json['display_name']),
      avatarUrl: _nullableStringValue(json['avatar_url']),
      createdAt: _dateTimeValue(json['created_at']),
      updatedAt: _dateTimeValue(json['updated_at']),
      lastLoginAt: _dateTimeValue(json['last_login_at']),
    );
  }

  final String id;
  final String email;
  final String authProvider;
  final String subscriptionStatus;
  final bool hasActiveSubscription;
  final int dailyFreeAnalysesLimit;
  final int dailyFreeAnalysesUsed;
  final int dailyFreeAnalysesRemaining;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  AuthUser copyWith({
    String? id,
    String? email,
    String? authProvider,
    String? subscriptionStatus,
    bool? hasActiveSubscription,
    int? dailyFreeAnalysesLimit,
    int? dailyFreeAnalysesUsed,
    int? dailyFreeAnalysesRemaining,
    String? displayName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      authProvider: authProvider ?? this.authProvider,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      hasActiveSubscription:
          hasActiveSubscription ?? this.hasActiveSubscription,
      dailyFreeAnalysesLimit:
          dailyFreeAnalysesLimit ?? this.dailyFreeAnalysesLimit,
      dailyFreeAnalysesUsed:
          dailyFreeAnalysesUsed ?? this.dailyFreeAnalysesUsed,
      dailyFreeAnalysesRemaining:
          dailyFreeAnalysesRemaining ?? this.dailyFreeAnalysesRemaining,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  String get displayLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return email;
  }

  String get subscriptionLabel {
    return switch (subscriptionStatus) {
      'month' => 'Month',
      'three-month' => 'Three-month',
      'year' => 'Year',
      _ => 'Free',
    };
  }

  String get analysisAllowanceLabel {
    if (hasActiveSubscription) {
      return 'Проверки без дневного лимита';
    }
    return '$dailyFreeAnalysesRemaining из $dailyFreeAnalysesLimit проверок';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'auth_provider': authProvider,
      'subscription_status': subscriptionStatus,
      'has_active_subscription': hasActiveSubscription,
      'daily_free_analyses_limit': dailyFreeAnalysesLimit,
      'daily_free_analyses_used': dailyFreeAnalysesUsed,
      'daily_free_analyses_remaining': dailyFreeAnalysesRemaining,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'last_login_at': lastLoginAt?.toUtc().toIso8601String(),
    };
  }
}

String? _stringValue(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

String? _nullableStringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}

bool _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
