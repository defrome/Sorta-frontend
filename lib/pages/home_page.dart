import 'package:flutter/material.dart';

import '../models/analyze_models.dart';
import '../models/auth_user.dart';
import '../shared/sorta_components.dart';
import '../shared/sorta_spacing.dart';
import 'profile_page.dart';
import 'scanning_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.analysis,
    this.authUser,
    required this.onContinueReview,
  });

  final AnalyzeResponse? analysis;
  final AuthUser? authUser;
  final VoidCallback onContinueReview;

  void _openScanner(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ScanningScreen()),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(initialUser: authUser),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _HomeAnalysisStats.fromAnalysis(analysis);
    final hasAnalysis = analysis != null;
    final eyebrow = hasAnalysis ? 'Scanned library' : 'Ready to scan';
    final reclaimableSize = stats.reclaimableSize;
    final allowanceText = _allowanceText(authUser);

    return LayoutBuilder(
      key: const ValueKey('home'),
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 560;
        final scanSize = isCompact ? 142.0 : 190.0;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SortaHeader(
                title: 'Sorta AI',
                leading: const SortaLogo(size: 50),
                trailingIcon: Icons.person_outline_rounded,
                trailingTooltip: 'Профиль',
                onTrailingTap: () => _openProfile(context),
              ),
              SizedBox(height: isCompact ? SortaSpacing.sm : SortaSpacing.lg),
              SizedBox.square(
                dimension: scanSize,
                child: FittedBox(
                  child: ScanCircle(onPressed: () => _openScanner(context)),
                ),
              ),
              SizedBox(height: isCompact ? SortaSpacing.md : SortaSpacing.xl),
              ValueBlock(
                eyebrow: eyebrow,
                value: allowanceText,
                caption: hasAnalysis
                    ? 'Можно освободить ${formatBytes(reclaimableSize)}'
                    : 'photo library thumbnails',
              ),
              SizedBox(
                height: isCompact
                    ? SortaSpacing.md
                    : SortaSpacing.xl - SortaSpacing.xxs,
              ),
              GlassCard(
                child: Column(
                  children: [
                    _HomeMetricRow(
                      title: 'Можно освободить',
                      value: formatBytes(reclaimableSize),
                    ),
                    const GlassDivider(),
                    _HomeMetricRow(
                      title: 'Найдено групп',
                      value: '${stats.reviewGroupsCount}',
                    ),
                    const GlassDivider(),
                    _HomeMetricRow(
                      title: 'Проверено фото',
                      value: '${stats.scannedCount}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SortaSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () => _openScanner(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Начать проверку'),
                ),
              ),
              const SizedBox(height: SortaSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: hasAnalysis && stats.reviewGroupsCount > 0
                      ? onContinueReview
                      : null,
                  child: const Text('Продолжить разбор'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _allowanceText(AuthUser? user) {
    if (user == null) {
      return 'Сегодня можно проверить';
    }
    if (user.hasActiveSubscription) {
      return 'Проверки без дневного лимита';
    }
    return 'Сегодня можно проверить: ${user.dailyFreeAnalysesRemaining} из ${user.dailyFreeAnalysesLimit}';
  }
}

class _HomeMetricRow extends StatelessWidget {
  const _HomeMetricRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFFA1A1AA),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAnalysisStats {
  const _HomeAnalysisStats({
    required this.scannedCount,
    required this.reclaimableSize,
    required this.reviewGroupsCount,
    required this.possibleDuplicatesCount,
    required this.similarPhotosCount,
    required this.selfiesCount,
    required this.documentsCount,
    required this.screenshotsCount,
    required this.blurryCount,
    required this.otherCount,
  });

  factory _HomeAnalysisStats.fromAnalysis(AnalyzeResponse? response) {
    if (response == null) {
      return const _HomeAnalysisStats(
        scannedCount: 0,
        reclaimableSize: 0,
        reviewGroupsCount: 0,
        possibleDuplicatesCount: 0,
        similarPhotosCount: 0,
        selfiesCount: 0,
        documentsCount: 0,
        screenshotsCount: 0,
        blurryCount: 0,
        otherCount: 0,
      );
    }

    final summary = response.summary;
    final fallback = response.reviewSections.isEmpty
        ? _HomeAnalysisStats._fromLegacy(response.clusters, response.noise)
        : _HomeAnalysisStats._fromReviewSections(response.reviewSections);
    final summaryReclaimable = summary.potentialReclaimableSize != 0
        ? summary.potentialReclaimableSize
        : summary.canBeCleaned;

    return _HomeAnalysisStats(
      scannedCount: _pickPositive(summary.scannedCount, response.totalFiles),
      reclaimableSize: _pickPositive(
        summaryReclaimable,
        response.reclaimableSize,
        fallback.reclaimableSize,
      ),
      reviewGroupsCount: _pickPositive(
        fallback.reviewGroupsCount,
        summary.reviewGroupsCount,
        response.clustersCount,
      ),
      possibleDuplicatesCount: _pickPositive(
        fallback.possibleDuplicatesCount,
        summary.possibleDuplicatesCount,
      ),
      similarPhotosCount: _pickPositive(
        fallback.similarPhotosCount,
        summary.similarPhotosCount,
      ),
      selfiesCount: _pickPositive(fallback.selfiesCount, summary.selfiesCount),
      documentsCount: _pickPositive(
        fallback.documentsCount,
        summary.documentsCount,
      ),
      screenshotsCount: _pickPositive(
        fallback.screenshotsCount,
        summary.screenshotsCount,
      ),
      blurryCount: _pickPositive(fallback.blurryCount, summary.blurryCount),
      otherCount: _pickPositive(fallback.otherCount, summary.otherCount),
    );
  }

  factory _HomeAnalysisStats._fromReviewSections(ReviewSections sections) {
    return _HomeAnalysisStats(
      scannedCount: 0,
      reclaimableSize: ReviewSectionKey.values.fold<int>(
        0,
        (total, section) => total + sections.reclaimableSize(section),
      ),
      reviewGroupsCount: sections.totalGroupCount,
      possibleDuplicatesCount: _sectionPhotoCount(
        sections,
        ReviewSectionKey.possibleDuplicates,
      ),
      similarPhotosCount: _sectionPhotoCount(
        sections,
        ReviewSectionKey.similarPhotos,
      ),
      selfiesCount: _sectionPhotoCount(sections, ReviewSectionKey.selfies),
      documentsCount: _sectionPhotoCount(sections, ReviewSectionKey.documents),
      screenshotsCount: _sectionPhotoCount(
        sections,
        ReviewSectionKey.screenshots,
      ),
      blurryCount: _sectionPhotoCount(sections, ReviewSectionKey.blurry),
      otherCount: _sectionPhotoCount(sections, ReviewSectionKey.other),
    );
  }

  factory _HomeAnalysisStats._fromLegacy(
    List<ClusterGroup> clusters,
    List<MediaItem> noise,
  ) {
    var reviewGroupsCount = 0;
    var reclaimableSize = 0;
    var possibleDuplicatesCount = 0;
    var similarPhotosCount = 0;
    var selfiesCount = 0;
    var documentsCount = 0;
    var screenshotsCount = 0;
    var blurryCount = 0;
    var otherCount = 0;

    for (final cluster in clusters) {
      reviewGroupsCount += 1;
      reclaimableSize += cluster.reclaimableSize;
      final count = cluster.count == 0
          ? _uniqueItemCount([
              cluster.bestItem,
              ...cluster.deleteCandidates,
              ...cluster.items,
            ])
          : cluster.count;

      switch (cluster.category) {
        case SortaCategory.duplicate:
          possibleDuplicatesCount += count;
        case SortaCategory.similar:
          similarPhotosCount += count;
        case SortaCategory.selfie:
          selfiesCount += count;
        case SortaCategory.document:
          documentsCount += count;
        case SortaCategory.screenshot:
          screenshotsCount += count;
        case SortaCategory.blurry:
          blurryCount += count;
        case SortaCategory.other:
          otherCount += count;
      }
    }

    for (final item in noise) {
      if (item.localAssetId.isEmpty) {
        continue;
      }
      reviewGroupsCount += 1;
      reclaimableSize += item.fileSize;
      switch (item.category) {
        case SortaCategory.duplicate:
          possibleDuplicatesCount += 1;
        case SortaCategory.similar:
          similarPhotosCount += 1;
        case SortaCategory.selfie:
          selfiesCount += 1;
        case SortaCategory.document:
          documentsCount += 1;
        case SortaCategory.screenshot:
          screenshotsCount += 1;
        case SortaCategory.blurry:
          blurryCount += 1;
        case SortaCategory.other:
          otherCount += 1;
      }
    }

    return _HomeAnalysisStats(
      scannedCount: 0,
      reclaimableSize: reclaimableSize,
      reviewGroupsCount: reviewGroupsCount,
      possibleDuplicatesCount: possibleDuplicatesCount,
      similarPhotosCount: similarPhotosCount,
      selfiesCount: selfiesCount,
      documentsCount: documentsCount,
      screenshotsCount: screenshotsCount,
      blurryCount: blurryCount,
      otherCount: otherCount,
    );
  }

  final int scannedCount;
  final int reclaimableSize;
  final int reviewGroupsCount;
  final int possibleDuplicatesCount;
  final int similarPhotosCount;
  final int selfiesCount;
  final int documentsCount;
  final int screenshotsCount;
  final int blurryCount;
  final int otherCount;

  static int _pickPositive(int first, [int second = 0, int third = 0]) {
    if (first > 0) return first;
    if (second > 0) return second;
    return third > 0 ? third : 0;
  }

  static int _sectionPhotoCount(
    ReviewSections sections,
    ReviewSectionKey section,
  ) {
    final ids = <String>{};
    var fallbackCount = 0;
    for (final group in sections[section]) {
      if (!group.shouldShowInReviewFlow) {
        continue;
      }
      fallbackCount += 1;
      for (final item in group.allItems) {
        if (item.localAssetId.isNotEmpty) {
          ids.add(item.localAssetId);
        }
      }
    }
    return ids.isEmpty ? fallbackCount : ids.length;
  }

  static int _uniqueItemCount(Iterable<MediaItem> items) {
    final ids = <String>{};
    for (final item in items) {
      if (item.localAssetId.isNotEmpty) {
        ids.add(item.localAssetId);
      }
    }
    return ids.length;
  }
}
