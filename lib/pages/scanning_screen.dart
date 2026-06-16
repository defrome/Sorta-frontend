import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/analyze_models.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../shared/sorta_colors.dart';
import '../shared/sorta_spacing.dart';
import '../sorta_shell.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen>
    with TickerProviderStateMixin {
  static const int _testPhotoLimit = 100;
  static const MethodChannel _androidMediaScannerChannel = MethodChannel(
    'sorta_frontend/media_scanner',
  );

  late final AnimationController _idleController;
  late final AnimationController _finishController;
  late final AnimationController _fadeController;
  late final ApiService _apiService;
  late final AuthService _authService;

  int _processed = 0;
  int _total = 0;
  String? _errorMessage;
  DailyFreeAnalysisLimitException? _limitError;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _authService = AuthService();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    _finishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnalysis());
  }

  @override
  void dispose() {
    _apiService.close();
    _authService.close();
    _idleController.dispose();
    _finishController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    try {
      final assets = await _loadImageAssets();
      if (!mounted) {
        return;
      }

      setState(() => _total = assets.length);
      final result = await _apiService.analyzeLibrary(
        assets,
        onProgress: (processed, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            _processed = processed;
            _total = total;
          });
        },
      );

      await _refreshProfile();
      await _finishSuccess(result);
    } on DailyFreeAnalysisLimitException catch (error) {
      await _refreshProfile();
      await _finishLimitReached(error);
    } on ApiException catch (error) {
      await _finishError(error.message);
    } catch (_) {
      await _finishError('Could not analyze media library.');
    }
  }

  Future<List<AssetEntity>> _loadImageAssets() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      throw const ApiException('Photo library access was denied.');
    }

    await _indexAndroidDraggedImages();

    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );
    if (paths.isEmpty) {
      throw const ApiException('No image albums found.');
    }

    final assets = <AssetEntity>[];
    var page = 0;
    while (true) {
      final remaining = _testPhotoLimit - assets.length;
      if (remaining <= 0) {
        break;
      }

      final chunk = await paths.first.getAssetListPaged(
        page: page,
        size: remaining.clamp(1, _testPhotoLimit),
      );
      assets.addAll(chunk);
      if (!mounted) {
        return assets;
      }
      setState(() => _total = assets.length);
      if (chunk.length < remaining || assets.length >= _testPhotoLimit) {
        break;
      }
      page += 1;
    }

    return assets;
  }

  Future<void> _refreshProfile() async {
    try {
      await _authService.fetchMe(validateExpiry: false);
    } catch (_) {
      return;
    }
  }

  Future<void> _indexAndroidDraggedImages() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _androidMediaScannerChannel.invokeMethod<void>(
        'scanExternalImageFolders',
      );
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> _finishSuccess(AnalyzeResponse result) async {
    if (!mounted) {
      return;
    }

    _idleController.stop();
    await _finishController.forward();
    await _fadeController.forward();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return SortaShell(analysis: result, initialIndex: 1);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _finishError(String message) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isError = true;
      _errorMessage = message;
    });
    _idleController.stop();
    await _finishController.forward();
  }

  Future<void> _finishLimitReached(
    DailyFreeAnalysisLimitException error,
  ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isError = true;
      _limitError = error;
      _errorMessage = null;
    });
    _idleController.stop();
    await _finishController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: FadeTransition(
        opacity: ReverseAnimation(_fadeController),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _idleController,
                    _finishController,
                  ]),
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(320, 320),
                      painter: ScanParticlesPainter(
                        rotation: _idleController.value,
                        completion: _finishController.value,
                        isError: _isError,
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: SortaSpacing.lg,
                right: SortaSpacing.lg,
                bottom: 76,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _progressText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: SortaColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: SortaSpacing.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: _total == 0 ? null : _processed / _total,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
              if (_limitError != null)
                Positioned(
                  left: SortaSpacing.lg,
                  right: SortaSpacing.lg,
                  bottom: 126,
                  child: _ScanLimitPaywall(
                    error: _limitError!,
                    onClose: _backToHome,
                    onSubscribe: _grantTestScans,
                  ),
                )
              else if (_errorMessage != null)
                Positioned(
                  left: SortaSpacing.lg,
                  right: SortaSpacing.lg,
                  bottom: 150,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(SortaSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: SortaColors.primary,
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: SortaSpacing.md),
                          TextButton(
                            onPressed: _backToHome,
                            child: const Text('Back'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _backToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const SortaShell()),
    );
  }

  Future<void> _grantTestScans() async {
    var didGrant = false;
    try {
      await _authService.grantDevFreeAnalyses();
      didGrant = true;
    } catch (_) {
      if (kDebugMode) {
        didGrant = await AuthSessionStore.grantLocalFreeAnalysesForTesting(
          scans: 3,
        );
      }
    }
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          didGrant
              ? 'Тестово добавлено 3 проверки'
              : 'Не удалось обновить тестовый лимит',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    if (didGrant) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) {
        _backToHome();
      }
    }
  }

  String get _progressText {
    if (_isError) {
      if (_limitError != null) {
        return 'Бесплатные проверки закончились';
      }
      return 'Не получилось проверить фото';
    }
    if (_total == 0) {
      return 'Проверяем похожие кадры';
    }
    if (_processed < _total * 0.45) {
      return 'Выбираем лучший вариант';
    }
    if (_processed < _total) {
      return 'Готовим объяснения';
    }
    return 'Проверили $_processed фото';
  }
}

class _ScanLimitPaywall extends StatelessWidget {
  const _ScanLimitPaywall({
    required this.error,
    required this.onClose,
    required this.onSubscribe,
  });

  final DailyFreeAnalysisLimitException error;
  final VoidCallback onClose;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(SortaSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: SortaColors.primary,
              size: 34,
            ),
            const SizedBox(height: SortaSpacing.md),
            const Text(
              'Бесплатные проверки на сегодня закончились',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SortaColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.18,
              ),
            ),
            const SizedBox(height: SortaSpacing.sm),
            Text(
              'Оформите подписку, чтобы продолжить без лимита',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: SortaSpacing.md),
            Text(
              '${error.dailyFreeAnalysesUsed} из ${error.dailyFreeAnalysesLimit} проверок использовано',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SortaColors.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SortaSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClose,
                    child: const Text('Назад'),
                  ),
                ),
                const SizedBox(width: SortaSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: onSubscribe,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Оформить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ScanParticlesPainter extends CustomPainter {
  const ScanParticlesPainter({
    required this.rotation,
    required this.completion,
    required this.isError,
  });

  final double rotation;
  final double completion;
  final bool isError;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.36;
    final easedCompletion = Curves.easeInOutCubic.transform(completion);
    final sphereScale = isError ? 1.0 : 1 - easedCompletion;
    final scanProgress = rotation; // 0 → 1 ровно до конца
    final laserY = center.dy - radius + scanProgress * (radius * 2);
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, radius, glowPaint);
    canvas.save();
    canvas.clipPath(clipPath);

    for (var i = 0; i < 260; i++) {
      final seed = i * 12.9898;
      final theta = (seed * 0.73) % (math.pi * 2);
      final phi = math.acos(1 - 2 * ((i * 0.61803398875) % 1));
      final spin = rotation * math.pi * 2;
      final pulse = 1 + math.sin(rotation * math.pi * 2 + i * 0.17) * 0.04;

      final x3 = math.sin(phi) * math.cos(theta + spin * 0.34);
      final y3 = math.cos(phi);
      final z3 = math.sin(phi) * math.sin(theta + spin * 0.34);
      final projection = 0.72 + z3 * 0.28;
      final scatter = isError ? easedCompletion * radius * 0.62 : 0.0;
      final collapse = isError ? 1.0 : 1 - easedCompletion;

      final direction = Offset(x3, y3);
      final rawOffset =
          Offset(
            x3 * radius * projection * pulse * collapse * sphereScale,
            y3 * radius * pulse * collapse * sphereScale,
          ) +
          direction * scatter;
      final maxDistance = radius - 4;
      final distance = rawOffset.distance;
      final safeOffset = distance > maxDistance && distance > 0
          ? rawOffset / distance * maxDistance
          : rawOffset;
      final point = center + safeOffset;
      final distanceToLaser = (point.dy - laserY).abs();
      final laserBoost = math.max(0.0, 1 - distanceToLaser / 20);
      final alpha = (0.24 + projection * 0.42 + laserBoost * 0.35)
          .clamp(0.0, 1.0)
          .toDouble();
      final dotRadius =
          (1.15 + projection * 1.3 + laserBoost * 1.6) *
          (isError ? 1 - easedCompletion * 0.4 : 1);

      final paint = Paint()
        ..color = Colors.white.withValues(
          alpha: alpha * (isError ? 1 - easedCompletion * 0.35 : 1),
        );
      canvas.drawCircle(point, dotRadius, paint);
    }

    if (!isError) {
      final chordHalfWidth = math
          .sqrt(math.max(0, radius * radius - math.pow(laserY - center.dy, 2)))
          .toDouble();

      // начинаем исчезать ближе к концу
      const fadeStart = 0.85;
      final fadeProgress = ((scanProgress - fadeStart) / (1 - fadeStart)).clamp(
        0.0,
        1.0,
      );

      final fade = 1 - Curves.easeOut.transform(fadeProgress);

      // сжатие линии
      final effectiveWidth = chordHalfWidth * (1 - fadeProgress);

      // рисуем
      final laserPaint = Paint()
        ..shader =
            LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.92 * fade),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset(center.dx, laserY),
                width: effectiveWidth * 2,
                height: 4,
              ),
            )
        ..strokeWidth = 2.2 * fade
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(center.dx - effectiveWidth, laserY),
        Offset(center.dx + effectiveWidth, laserY),
        laserPaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ScanParticlesPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.completion != completion ||
        oldDelegate.isError != isError;
  }
}
