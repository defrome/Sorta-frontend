import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../models/auth_user.dart';
import '../../services/auth_service.dart';
import '../../services/auth_session.dart';
import '../../services/api_service.dart';

enum _AuthStep { emailInput, codeInput }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onAuthenticated});

  final VoidCallback? onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  static final Uri _apiBaseUrl = ApiService.defaultBaseUrl();

  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _termsOpacity;
  late final TextEditingController _emailController;
  late final TextEditingController _codeController;
  final http.Client _client = http.Client();

  _AuthStep _step = _AuthStep.emailInput;
  bool _isLoading = false;
  String? _loginId;
  String? _devCode;
  int? _codeExpiresIn;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _codeController = TextEditingController();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.77, curve: Curves.easeOutCubic),
    );
    _termsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.54, 1, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _client.close();
    _emailController.dispose();
    _codeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startEmailLogin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Введите email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      final response = await _client.post(
        _apiBaseUrl.replace(path: '/api/v1/auth/email/start'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthFlowException(_backendError(response));
      }

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        throw const AuthFlowException('Некорректный ответ авторизации.');
      }

      final loginId = _stringValue(json['login_id']);
      if (loginId == null) {
        throw const AuthFlowException('Backend не вернул login_id.');
      }

      final devCode = _stringValue(json['dev_code']);
      setState(() {
        _loginId = loginId;
        _devCode = devCode;
        _codeExpiresIn = _intValue(json['expires_in']);
        _step = _AuthStep.codeInput;
        _statusMessage = 'Введите код из письма.';
        if (devCode != null) {
          _codeController.text = devCode;
        }
      });
    } on AuthFlowException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Не удалось отправить код.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyEmailCode() async {
    final loginId = _loginId;
    final code = _codeController.text.trim();
    if (loginId == null) {
      setState(() => _errorMessage = 'Сессия входа не найдена.');
      return;
    }
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Введите код.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _client.post(
        _apiBaseUrl.replace(path: '/api/v1/auth/email/verify'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'login_id': loginId, 'code': code}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthFlowException(_backendError(response));
      }

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        throw const AuthFlowException('Некорректный ответ авторизации.');
      }

      final token = _stringValue(json['access_token']);
      if (token == null) {
        throw const AuthFlowException('Backend не вернул access_token.');
      }
      final userJson = _mapValue(json['user']);
      if (userJson.isEmpty) {
        throw const AuthFlowException('Backend не вернул user.');
      }

      await AuthSessionStore.saveSession(
        accessToken: token,
        tokenType: _stringValue(json['token_type']) ?? 'bearer',
        user: AuthUser.fromJson(userJson),
      );

      if (mounted) widget.onAuthenticated?.call();
    } on AuthFlowException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException {
      if (mounted) {
        setState(() => _errorMessage = 'Некорректный профиль пользователя.');
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Не удалось проверить код.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _backToEmail() {
    setState(() {
      _step = _AuthStep.emailInput;
      _loginId = null;
      _devCode = null;
      _codeExpiresIn = null;
      _codeController.clear();
      _errorMessage = null;
      _statusMessage = null;
    });
  }

  String _backendError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
      return 'Ошибка авторизации (${response.statusCode}).';
    }

    return 'Ошибка авторизации (${response.statusCode}).';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoOpacity,
                  child: const _AuthHeader(),
                ),
                const SizedBox(height: 34),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _AuthForm(
                    key: ValueKey(_step),
                    step: _step,
                    emailController: _emailController,
                    codeController: _codeController,
                    isLoading: _isLoading,
                    devCode: _devCode,
                    expiresIn: _codeExpiresIn,
                    statusMessage: _statusMessage,
                    errorMessage: _errorMessage,
                    onContinue: _startEmailLogin,
                    onVerify: _verifyEmailCode,
                    onBack: _backToEmail,
                  ),
                ),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: _termsOpacity,
                  child: Text(
                    'Продолжая, вы соглашаетесь с условиями использования',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SortaAuthGate extends StatefulWidget {
  const SortaAuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<SortaAuthGate> createState() => _SortaAuthGateState();
}

class _SortaAuthGateState extends State<SortaAuthGate> {
  late final AuthService _authService;
  var _state = _AuthGateState.checking;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _restoreSession();
  }

  @override
  void dispose() {
    _authService.close();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final authHeader = await AuthSessionStore.authorizationHeader(
      validateExpiry: false,
    );
    if (authHeader == null) {
      if (!mounted) return;
      setState(() => _state = _AuthGateState.unauthenticated);
      return;
    }

    var isAuthenticated = false;
    try {
      await _authService.fetchMe(validateExpiry: false);
      isAuthenticated = true;
    } on AuthUnauthorizedException {
      await AuthSessionStore.clear();
      isAuthenticated = false;
    } catch (_) {
      final session = await AuthSessionStore.readActiveSession();
      isAuthenticated = session != null;
    }
    if (!mounted) return;

    setState(() {
      _state = isAuthenticated
          ? _AuthGateState.authenticated
          : _AuthGateState.unauthenticated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: switch (_state) {
        _AuthGateState.checking => const _AuthBootScreen(
          key: ValueKey('auth-checking'),
        ),
        _AuthGateState.authenticated => widget.child,
        _AuthGateState.unauthenticated => AuthScreen(
          key: const ValueKey('auth'),
          onAuthenticated: () {
            setState(() => _state = _AuthGateState.authenticated);
          },
        ),
      },
    );
  }
}

enum _AuthGateState { checking, authenticated, unauthenticated }

class _AuthBootScreen extends StatelessWidget {
  const _AuthBootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/sorta-logo.png',
          width: 106,
          height: 106,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
        const Text(
          'Sorta AI',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Умная очистка галереи',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    super.key,
    required this.step,
    required this.emailController,
    required this.codeController,
    required this.isLoading,
    required this.devCode,
    required this.expiresIn,
    required this.statusMessage,
    required this.errorMessage,
    required this.onContinue,
    required this.onVerify,
    required this.onBack,
  });

  final _AuthStep step;
  final TextEditingController emailController;
  final TextEditingController codeController;
  final bool isLoading;
  final String? devCode;
  final int? expiresIn;
  final String? statusMessage;
  final String? errorMessage;
  final VoidCallback onContinue;
  final VoidCallback onVerify;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (step == _AuthStep.emailInput)
          _GlassTextField(
            controller: emailController,
            hintText: 'Email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onContinue(),
          )
        else ...[
          _GlassTextField(
            controller: codeController,
            hintText: 'Код из письма',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onVerify(),
          ),
          if (devCode != null) ...[
            const SizedBox(height: 12),
            _DevCodePill(code: devCode!, expiresIn: expiresIn),
          ],
        ],
        const SizedBox(height: 14),
        _LiquidAuthButton(
          label: step == _AuthStep.emailInput ? 'Продолжить' : 'Подтвердить',
          isLoading: isLoading,
          onTap: step == _AuthStep.emailInput ? onContinue : onVerify,
        ),
        if (step == _AuthStep.codeInput) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: isLoading ? null : onBack,
            child: const Text('Изменить email'),
          ),
        ],
        if (statusMessage != null || errorMessage != null) ...[
          const SizedBox(height: 14),
          Text(
            errorMessage ?? statusMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: errorMessage == null
                  ? Colors.white.withValues(alpha: 0.55)
                  : const Color(0xFFFF7A7A),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.hintText,
    required this.keyboardType,
    required this.textInputAction,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 56,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          contentPadding: const EdgeInsets.symmetric(horizontal: 22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
          ),
        ),
      ),
    );
  }
}

class _DevCodePill extends StatelessWidget {
  const _DevCodePill({required this.code, required this.expiresIn});

  final String code;
  final int? expiresIn;

  @override
  Widget build(BuildContext context) {
    final expiresText = expiresIn == null ? '' : ' · ${expiresIn! ~/ 60} мин';
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        'Dev code: $code$expiresText',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LiquidAuthButton extends StatefulWidget {
  const _LiquidAuthButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  State<_LiquidAuthButton> createState() => _LiquidAuthButtonState();
}

class _LiquidAuthButtonState extends State<_LiquidAuthButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.isLoading ? null : (_) => _setPressed(true),
      onTapCancel: widget.isLoading ? null : () => _setPressed(false),
      onTapUp: widget.isLoading ? null : (_) => _setPressed(false),
      onTap: widget.isLoading ? null : widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: 280,
          height: 56,
          child: LiquidGlassLayer(
            settings: const LiquidGlassSettings(
              thickness: 16,
              blur: 12,
              glassColor: Color(0x22FFFFFF),
            ),
            child: LiquidGlass(
              shape: const LiquidRoundedSuperellipse(borderRadius: 50),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 110),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        color: Colors.white.withValues(
                          alpha: _isPressed ? 0.08 : 0.0,
                        ),
                      ),
                    ),
                  ),
                  if (widget.isLoading)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Text(
                      widget.label,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;
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

String? _stringValue(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
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
