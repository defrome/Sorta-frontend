import 'analyze_models.dart';

typedef CleanupUndoToastCallback =
    void Function({
      required int photoCount,
      required void Function() onUndo,
      Duration? duration,
    });

class CleanupBasketItem {
  const CleanupBasketItem({
    required this.groupKey,
    required this.title,
    required this.section,
    required this.localAssetIds,
    required this.reclaimableSize,
  });

  factory CleanupBasketItem.fromReviewGroup({
    required String groupKey,
    required ReviewGroup group,
  }) {
    final ids = group.deletionItems
        .map((item) => item.localAssetId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    return CleanupBasketItem(
      groupKey: groupKey,
      title: group.reason.trim().isNotEmpty
          ? group.reason
          : group.section.label,
      section: group.section,
      localAssetIds: ids,
      reclaimableSize: group.effectiveReclaimableSize,
    );
  }

  final String groupKey;
  final String title;
  final ReviewSectionKey section;
  final List<String> localAssetIds;
  final int reclaimableSize;

  int get photoCount => localAssetIds.length;
}
