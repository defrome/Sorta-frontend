import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../shared/sorta_colors.dart';
import '../shared/sorta_components.dart';
import '../shared/sorta_spacing.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.initialUser});

  final AuthUser? initialUser;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final AuthService _authService;
  AuthUser? _user;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _user = widget.initialUser;
    _loadProfile();
  }

  @override
  void dispose() {
    _authService.close();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.fetchMe(validateExpiry: false);
      if (!mounted) return;
      setState(() => _user = user);
    } on AuthUnauthorizedException {
      if (!mounted) return;
      setState(() => _errorMessage = 'Сессия истекла. Войдите заново.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_user == null) {
          _errorMessage = 'Не удалось загрузить профиль.';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      backgroundColor: SortaColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SortaSpacing.lg,
                SortaSpacing.sm,
                SortaSpacing.lg,
                SortaSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHeader(isLoading: _isLoading),
                  const SizedBox(height: SortaSpacing.xl),
                  if (user == null)
                    Expanded(
                      child: Center(
                        child: _ProfileErrorState(
                          message: _errorMessage ?? 'Профиль недоступен.',
                          onRetry: _loadProfile,
                        ),
                      ),
                    )
                  else ...[
                    _ProfileHero(user: user),
                    const SizedBox(height: SortaSpacing.lg),
                    GlassCard(
                      child: Column(
                        children: [
                          _ProfileRow(label: 'Email', value: user.email),
                          const GlassDivider(),
                          _ProfileRow(
                            label: 'Подписка',
                            value: user.subscriptionLabel,
                          ),
                          const GlassDivider(),
                          _ProfileRow(
                            label: 'Сегодня доступно',
                            value: user.analysisAllowanceLabel,
                          ),
                          const GlassDivider(),
                          _ProfileRow(
                            label: 'Login method',
                            value: user.authProvider,
                          ),
                          const GlassDivider(),
                          _ProfileRow(
                            label: 'Member since',
                            value: _formatProfileDate(user.createdAt),
                          ),
                          const GlassDivider(),
                          _ProfileRow(
                            label: 'Last login',
                            value: _formatProfileDate(user.lastLoginAt),
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: SortaSpacing.md),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: SortaColors.secondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: SortaColors.primary,
            ),
          ),
          const SizedBox(width: SortaSpacing.sm),
          const Text(
            'Профиль',
            style: TextStyle(
              color: SortaColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (isLoading)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SortaColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          _ProfileAvatar(user: user),
          const SizedBox(width: SortaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SortaColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: SortaSpacing.xxs),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SortaColors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl;
    final initial = user.displayLabel.trim().isEmpty
        ? '?'
        : user.displayLabel.trim().characters.first.toUpperCase();

    return CircleAvatar(
      radius: 30,
      backgroundColor: Colors.white.withValues(alpha: 0.10),
      foregroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
      child: Text(
        initial,
        style: const TextStyle(
          color: SortaColors.primary,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: SortaColors.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: SortaColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: SortaColors.secondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SortaSpacing.md),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}

String _formatProfileDate(DateTime? value) {
  if (value == null) {
    return 'Нет данных';
  }

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
