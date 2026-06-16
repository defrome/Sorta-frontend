import 'package:flutter/material.dart';

import '../models/analyze_models.dart';
import '../models/cleanup_basket.dart';
import '../shared/sorta_colors.dart';
import '../shared/sorta_components.dart';
import '../shared/sorta_spacing.dart';
import 'swipe_review_page.dart';

class SmartCleanPage extends StatefulWidget {
  const SmartCleanPage({
    super.key,
    this.analysis,
    required this.queuedGroupKeys,
    required this.onQueueDelete,
    required this.onUndoQueuedDelete,
    required this.onShowQueuedDeleteToast,
  });

  final AnalyzeResponse? analysis;
  final Set<String> queuedGroupKeys;
  final ValueChanged<CleanupBasketItem> onQueueDelete;
  final ValueChanged<String> onUndoQueuedDelete;
  final CleanupUndoToastCallback onShowQueuedDeleteToast;

  @override
  State<SmartCleanPage> createState() => _SmartCleanPageState();
}

class _SmartCleanPageState extends State<SmartCleanPage> {
  static const _sectionPriority = [
    ReviewSectionKey.possibleDuplicates,
    ReviewSectionKey.blurry,
    ReviewSectionKey.screenshots,
    ReviewSectionKey.similarPhotos,
    ReviewSectionKey.selfies,
    ReviewSectionKey.documents,
    ReviewSectionKey.other,
  ];

  final Set<String> _reviewedGroupKeys = {};
  final Map<String, SwipeDecision> _decisions = {};
  final Map<String, String> _selectedKeepIds = {};

  @override
  Widget build(BuildContext context) {
    final queue = _swipeQueue;
    final analysis = widget.analysis;
    final totalGroups = analysis?.reviewSections.totalGroupCount ?? 0;

    return LayoutBuilder(
      key: const ValueKey('smart'),
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SortaHeader(
                title: 'Smart Clean',
                trailingIcon: Icons.auto_awesome_rounded,
              ),
              const SizedBox(height: SortaSpacing.lg),
              _SmartCleanStatus(
                remainingGroups: queue.length,
                totalGroups: totalGroups,
                reviewedGroups: _decisions.length,
              ),
              const SizedBox(height: SortaSpacing.lg),
              Expanded(
                child: queue.isEmpty
                    ? _SmartCleanEmptyState(hasAnalysis: analysis != null)
                    : PhotoSwipeDeck(
                        queue: queue,
                        emptyMessage: 'Все выглядит аккуратно',
                        onDecision: _handleSwipeDecision,
                        onKeepChanged: _handleKeepChanged,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<SwipeQueueItem> get _swipeQueue {
    final analysis = widget.analysis;
    if (analysis == null) {
      return const [];
    }

    final items = <SwipeQueueItem>[];
    for (final section in _sectionPriority) {
      for (final group in analysis.reviewSections[section]) {
        final key = _groupKey(group);
        if (key.isEmpty ||
            _reviewedGroupKeys.contains(key) ||
            widget.queuedGroupKeys.contains(key) ||
            !group.shouldShowInReviewFlow) {
          continue;
        }
        items.add(SwipeQueueItem(group: _groupWithSelectedKeep(group)));
      }
    }

    return items;
  }

  ReviewGroup _groupWithSelectedKeep(ReviewGroup group) {
    final selectedId = _selectedKeepIds[_groupKey(group)];
    if (selectedId == null || selectedId.isEmpty) {
      return group;
    }

    MediaItem? selected;
    for (final item in group.allItems) {
      if (item.localAssetId == selectedId) {
        selected = item;
        break;
      }
    }
    if (selected == null) {
      return group;
    }

    final selectedIdValue = selected.localAssetId;
    return group.copyWith(
      keepItem: selected,
      discardItems: group.allItems
          .where((item) => item.localAssetId != selectedIdValue)
          .toList(),
    );
  }

  void _handleSwipeDecision(SwipeQueueItem queueItem, SwipeDecision decision) {
    final key = _groupKey(queueItem.group);
    setState(() {
      _reviewedGroupKeys.add(key);
      _decisions[key] = decision;
    });

    if (decision == SwipeDecision.delete && queueItem.group.canQuickDelete) {
      _queueGroupForCleanup(queueItem.group);
    }
  }

  void _handleKeepChanged(SwipeQueueItem queueItem, MediaItem item) {
    setState(() {
      _selectedKeepIds[_groupKey(queueItem.group)] = item.localAssetId;
    });
  }

  void _queueGroupForCleanup(ReviewGroup group) {
    final ids = group.deletionItems
        .map((item) => item.localAssetId)
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      return;
    }

    final groupKey = _groupKey(group);
    final onUndoQueuedDelete = widget.onUndoQueuedDelete;
    widget.onQueueDelete(
      CleanupBasketItem.fromReviewGroup(groupKey: groupKey, group: group),
    );
    widget.onShowQueuedDeleteToast(
      photoCount: ids.length,
      duration: Duration(seconds: group.undoSeconds),
      onUndo: () {
        if (mounted) {
          setState(() {
            _reviewedGroupKeys.remove(groupKey);
            _decisions.remove(groupKey);
          });
        }
        onUndoQueuedDelete(groupKey);
      },
    );
  }
}

class _SmartCleanStatus extends StatelessWidget {
  const _SmartCleanStatus({
    required this.remainingGroups,
    required this.totalGroups,
    required this.reviewedGroups,
  });

  final int remainingGroups;
  final int totalGroups;
  final int reviewedGroups;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: SortaSpacing.md,
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: SortaColors.primary),
          const SizedBox(width: SortaSpacing.md),
          Expanded(
            child: Text(
              totalGroups == 0
                  ? 'Запустите проверку, чтобы увидеть группы'
                  : '$remainingGroups групп осталось · $reviewedGroups проверено',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

class _SmartCleanEmptyState extends StatelessWidget {
  const _SmartCleanEmptyState({required this.hasAnalysis});

  final bool hasAnalysis;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: SortaColors.primary,
              size: 34,
            ),
            const SizedBox(height: SortaSpacing.md),
            Text(
              hasAnalysis
                  ? 'Все выглядит аккуратно'
                  : 'Проверка еще не запущена',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SortaColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: SortaSpacing.sm),
            Text(
              hasAnalysis
                  ? 'Мы не нашли уверенных групп для быстрой проверки.'
                  : 'Начните анализ на Home, затем вернитесь к разбору.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SortaColors.secondary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _groupKey(ReviewGroup group) {
  if (group.groupId.isNotEmpty) {
    return group.groupId;
  }
  return group.keepItem.localAssetId.isNotEmpty
      ? group.keepItem.localAssetId
      : group.keepItem.filename;
}
