import 'package:flutter/material.dart';

import '../models/analyze_models.dart';
import '../shared/sorta_colors.dart';
import '../shared/sorta_components.dart';
import '../shared/sorta_spacing.dart';
import 'media_preview_page.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key, this.analysis});

  final AnalyzeResponse? analysis;

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  late final TextEditingController _searchController;
  int _activeTabIndex = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = _groupedItems;
    final hasItems = groupedItems.values.any((items) => items.isNotEmpty);
    final emptyMessage = _searchQuery.isEmpty
        ? 'Analyzed files will appear here.'
        : 'No files match your search.';

    return Column(
      key: const ValueKey('files'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SortaHeader(
          title: 'Results',
          trailingIcon: Icons.ios_share_rounded,
        ),
        const SizedBox(height: SortaSpacing.lg),
        _ResultsSummaryCard(analysis: widget.analysis),
        const SizedBox(height: SortaSpacing.lg),
        SearchField(
          controller: _searchController,
          hasText: _searchQuery.isNotEmpty,
          onChanged: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
          },
          onClear: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        ),
        const SizedBox(height: SortaSpacing.lg),
        TabPills(
          activeIndex: _activeTabIndex,
          onChanged: (index) => setState(() => _activeTabIndex = index),
        ),
        const SizedBox(height: SortaSpacing.lg + SortaSpacing.xxs),
        Expanded(
          child: SingleChildScrollView(
            child: GlassCard(
              child: !hasItems
                  ? _EmptyState(message: emptyMessage)
                  : Column(
                      children: [
                        for (final entry in groupedItems.entries) ...[
                          if (entry.value.isNotEmpty) ...[
                            _CategoryHeader(category: entry.key),
                            for (var i = 0; i < entry.value.length; i++) ...[
                              FileRow(
                                icon: _categoryIcon(entry.value[i].category),
                                title: entry.value[i].filename,
                                value: formatBytes(entry.value[i].fileSize),
                                date: formatShortDate(entry.value[i].createdAt),
                                onTap: _canOpenPreview(entry.value[i])
                                    ? () => _openPreview(entry.value[i])
                                    : null,
                              ),
                              if (i != entry.value.length - 1)
                                const GlassDivider(),
                            ],
                            if (entry.key != SortaCategory.other)
                              const GlassDivider(),
                          ],
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Map<SortaCategory, List<MediaItem>> get _groupedItems {
    final grouped = {
      SortaCategory.duplicate: <MediaItem>[],
      SortaCategory.selfie: <MediaItem>[],
      SortaCategory.document: <MediaItem>[],
      SortaCategory.screenshot: <MediaItem>[],
      SortaCategory.blurry: <MediaItem>[],
      SortaCategory.similar: <MediaItem>[],
      SortaCategory.other: <MediaItem>[],
    };

    for (final item in _analysisItems.take(24)) {
      grouped[item.category]!.add(item);
    }

    return grouped;
  }

  List<MediaItem> get _analysisItems {
    final response = widget.analysis;
    if (response == null) {
      return const [];
    }

    final seen = <String>{};
    final items = <MediaItem>[];

    if (!response.reviewSections.isEmpty) {
      for (final section in ReviewSectionKey.values) {
        for (final group in response.reviewSections[section]) {
          for (final item in group.allItems) {
            if (item.localAssetId.isNotEmpty && seen.add(item.localAssetId)) {
              items.add(item);
            }
          }
        }
      }

      return items.where(_matchesActiveTab).where(_matchesSearchQuery).toList();
    }

    for (final cluster in response.clusters) {
      for (final item in [
        cluster.bestItem,
        ...cluster.deleteCandidates,
        ...cluster.items,
      ]) {
        if (item.localAssetId.isNotEmpty && seen.add(item.localAssetId)) {
          items.add(item);
        }
      }
    }

    for (final item in response.noise) {
      if (item.localAssetId.isNotEmpty && seen.add(item.localAssetId)) {
        items.add(item);
      }
    }

    return items.where(_matchesActiveTab).where(_matchesSearchQuery).toList();
  }

  bool _matchesActiveTab(MediaItem item) {
    final mediaType = item.mediaType.toLowerCase();

    return switch (_activeTabIndex) {
      1 => mediaType.startsWith('image') || mediaType.startsWith('photo'),
      2 => mediaType.startsWith('video'),
      _ => true,
    };
  }

  bool _matchesSearchQuery(MediaItem item) {
    final query = _searchQuery;
    if (query.isEmpty) {
      return true;
    }

    return item.filename.toLowerCase().contains(query) ||
        item.mediaType.toLowerCase().contains(query) ||
        item.category.label.toLowerCase().contains(query);
  }

  IconData _categoryIcon(SortaCategory category) {
    return switch (category) {
      SortaCategory.duplicate => Icons.copy_rounded,
      SortaCategory.selfie => Icons.face_retouching_natural_rounded,
      SortaCategory.document => Icons.description_rounded,
      SortaCategory.screenshot => Icons.screenshot_rounded,
      SortaCategory.blurry => Icons.blur_on_rounded,
      SortaCategory.similar => Icons.filter_none_rounded,
      SortaCategory.other => Icons.image_outlined,
    };
  }

  bool _canOpenPreview(MediaItem item) {
    return item.localAssetId.isNotEmpty &&
        item.mediaType.toLowerCase().startsWith('image');
  }

  void _openPreview(MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MediaPreviewPage(item: item)),
    );
  }
}

class _ResultsSummaryCard extends StatelessWidget {
  const _ResultsSummaryCard({required this.analysis});

  final AnalyzeResponse? analysis;

  @override
  Widget build(BuildContext context) {
    final response = analysis;
    final summary = response?.summary;
    final checked = summary?.scannedCount == 0
        ? response?.totalFiles ?? 0
        : summary?.scannedCount ?? 0;
    final candidates = response?.deleteCandidatesCount ?? 0;
    final kept = (checked - candidates).clamp(0, checked);
    final reclaimable = response?.reclaimableSize == 0
        ? summary?.potentialReclaimableSize ?? 0
        : response?.reclaimableSize ?? 0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Итог проверки',
            style: TextStyle(
              color: SortaColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SortaSpacing.sm),
          Text(
            'Можно освободить ${formatBytes(reclaimable)}',
            style: const TextStyle(
              color: SortaColors.secondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SortaSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _ResultMetric(label: 'Проверено', value: '$checked'),
              ),
              Expanded(
                child: _ResultMetric(label: 'К удалению', value: '$candidates'),
              ),
              Expanded(
                child: _ResultMetric(label: 'Оставлено', value: '$kept'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: SortaColors.primary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: SortaSpacing.xxs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: SortaColors.secondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final SortaCategory category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: SortaSpacing.xs,
        bottom: SortaSpacing.sm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          category.label,
          style: const TextStyle(
            color: SortaColors.secondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SortaSpacing.lg),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: SortaColors.secondary, fontSize: 14),
      ),
    );
  }
}
