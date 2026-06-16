class AnalyzeResponse {
  const AnalyzeResponse({
    required this.scanId,
    required this.totalFiles,
    required this.totalOriginalSize,
    required this.reclaimableSize,
    required this.clustersCount,
    required this.deleteCandidatesCount,
    required this.summary,
    required this.reviewSections,
    required this.clusters,
    required this.noise,
    required this.report,
  });

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) {
    final parsedReviewSections = ReviewSections.fromJson(
      _mapValue(json['review_sections']),
    );
    final clusters = _listOfMaps(
      json['clusters'],
    ).map(ClusterGroup.fromJson).toList();
    final noise = _listOfMaps(json['noise']).map(MediaItem.fromJson).toList();
    final reviewSections = parsedReviewSections.isEmpty
        ? ReviewSections.fromLegacy(clusters: clusters, noise: noise)
        : parsedReviewSections;
    final report = AnalyzeReport.fromJson(_mapValue(json['report']));
    final parsedSummary = AnalyzeSummary.fromJson(_mapValue(json['summary']));
    final fallbackSummary = parsedSummary.hasValues
        ? parsedSummary
        : AnalyzeSummary(
            scannedCount: _intValue(json['total_files']),
            totalSize: _intValue(json['total_original_size']),
            canBeCleaned: _intValue(json['reclaimable_size']),
            duplicatesSize: 0,
            similarSize: _intValue(json['reclaimable_size']),
            screenshotsSize: 0,
            otherSize: 0,
          );
    final summary = fallbackSummary.withReviewSectionsFallback(reviewSections);
    final totalFiles = _intValue(
      json['total_files'],
      fallback: summary.scannedCount,
    );
    final totalOriginalSize = _intValue(
      json['total_original_size'],
      fallback: summary.totalSize,
    );
    final reclaimableSize = _intValue(
      json['reclaimable_size'],
      fallback: summary.potentialReclaimableSize == 0
          ? summary.canBeCleaned
          : summary.potentialReclaimableSize,
    );

    return AnalyzeResponse(
      scanId: _stringValue(json['scan_id']),
      totalFiles: totalFiles,
      totalOriginalSize: totalOriginalSize,
      reclaimableSize: reclaimableSize,
      clustersCount: _intValue(
        json['clusters_count'],
        fallback: reviewSections.totalGroupCount == 0
            ? clusters.length
            : reviewSections.totalGroupCount,
      ),
      deleteCandidatesCount: _intValue(json['delete_candidates_count']),
      summary: summary,
      reviewSections: reviewSections,
      clusters: clusters,
      noise: noise,
      report: report,
    );
  }

  factory AnalyzeResponse.empty() {
    return AnalyzeResponse(
      scanId: '',
      totalFiles: 0,
      totalOriginalSize: 0,
      reclaimableSize: 0,
      clustersCount: 0,
      deleteCandidatesCount: 0,
      summary: const AnalyzeSummary(
        scannedCount: 0,
        totalSize: 0,
        canBeCleaned: 0,
        duplicatesSize: 0,
        similarSize: 0,
        screenshotsSize: 0,
        otherSize: 0,
      ),
      reviewSections: ReviewSections.empty(),
      clusters: const [],
      noise: const [],
      report: AnalyzeReport.empty(),
    );
  }

  final String scanId;
  final int totalFiles;
  final int totalOriginalSize;
  final int reclaimableSize;
  final int clustersCount;
  final int deleteCandidatesCount;
  final AnalyzeSummary summary;
  final ReviewSections reviewSections;
  final List<ClusterGroup> clusters;
  final List<MediaItem> noise;
  final AnalyzeReport report;

  AnalyzeResponse copyWith({
    String? scanId,
    int? totalFiles,
    int? totalOriginalSize,
    int? reclaimableSize,
    int? clustersCount,
    int? deleteCandidatesCount,
    AnalyzeSummary? summary,
    ReviewSections? reviewSections,
    List<ClusterGroup>? clusters,
    List<MediaItem>? noise,
    AnalyzeReport? report,
  }) {
    return AnalyzeResponse(
      scanId: scanId ?? this.scanId,
      totalFiles: totalFiles ?? this.totalFiles,
      totalOriginalSize: totalOriginalSize ?? this.totalOriginalSize,
      reclaimableSize: reclaimableSize ?? this.reclaimableSize,
      clustersCount: clustersCount ?? this.clustersCount,
      deleteCandidatesCount:
          deleteCandidatesCount ?? this.deleteCandidatesCount,
      summary: summary ?? this.summary,
      reviewSections: reviewSections ?? this.reviewSections,
      clusters: clusters ?? this.clusters,
      noise: noise ?? this.noise,
      report: report ?? this.report,
    );
  }

  AnalyzeResponse mergeWith(AnalyzeResponse other) {
    final mergedClusters = <ClusterGroup>[
      ...clusters,
      ...other.clusters.map((cluster) {
        return cluster.copyWith(clusterId: clusters.length + cluster.clusterId);
      }),
    ];

    return AnalyzeResponse(
      scanId: scanId.isNotEmpty ? scanId : other.scanId,
      totalFiles: totalFiles + other.totalFiles,
      totalOriginalSize: totalOriginalSize + other.totalOriginalSize,
      reclaimableSize: reclaimableSize + other.reclaimableSize,
      clustersCount: mergedClusters.length,
      deleteCandidatesCount:
          deleteCandidatesCount + other.deleteCandidatesCount,
      summary: summary.mergeWith(other.summary),
      reviewSections: reviewSections.mergeWith(other.reviewSections),
      clusters: mergedClusters,
      noise: [...noise, ...other.noise],
      report: report.mergeWith(other.report),
    );
  }
}

class AnalyzeReport {
  const AnalyzeReport({
    required this.summary,
    required this.suggestedKeep,
    required this.suggestedDelete,
    required this.decisions,
    required this.generatedByAi,
    required this.note,
  });

  factory AnalyzeReport.fromJson(Map<String, dynamic> json) {
    return AnalyzeReport(
      summary: _stringValue(json['summary']),
      suggestedKeep: _listOfStrings(json['suggested_keep']),
      suggestedDelete: _listOfStrings(json['suggested_delete']),
      decisions: _listOfMaps(
        json['decisions'],
      ).map(AnalyzeDecision.fromJson).toList(),
      generatedByAi: _boolValue(json['generated_by_ai']),
      note: _nullableStringValue(json['note']),
    );
  }

  factory AnalyzeReport.empty() {
    return const AnalyzeReport(
      summary: '',
      suggestedKeep: [],
      suggestedDelete: [],
      decisions: [],
      generatedByAi: false,
      note: null,
    );
  }

  final String summary;
  final List<String> suggestedKeep;
  final List<String> suggestedDelete;
  final List<AnalyzeDecision> decisions;
  final bool generatedByAi;
  final String? note;

  bool get hasValues {
    return summary.isNotEmpty ||
        suggestedKeep.isNotEmpty ||
        suggestedDelete.isNotEmpty ||
        decisions.isNotEmpty ||
        generatedByAi ||
        (note?.isNotEmpty ?? false);
  }

  AnalyzeReport mergeWith(AnalyzeReport other) {
    if (!hasValues) {
      return other;
    }
    if (!other.hasValues) {
      return this;
    }

    return AnalyzeReport(
      summary: [
        summary,
        other.summary,
      ].where((value) => value.trim().isNotEmpty).join('\n\n'),
      suggestedKeep: [...suggestedKeep, ...other.suggestedKeep],
      suggestedDelete: [...suggestedDelete, ...other.suggestedDelete],
      decisions: [...decisions, ...other.decisions],
      generatedByAi: generatedByAi || other.generatedByAi,
      note: [note, other.note]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join('\n\n'),
    );
  }
}

class ReviewSections {
  const ReviewSections({required this.groupsBySection});

  factory ReviewSections.fromJson(Map<String, dynamic> json) {
    return ReviewSections(
      groupsBySection: {
        for (final section in ReviewSectionKey.values)
          section: _listOfMaps(
            json[section.apiValue],
          ).map((item) => ReviewGroup.fromJson(item, section)).toList(),
      },
    );
  }

  factory ReviewSections.empty() {
    return ReviewSections(
      groupsBySection: {
        for (final section in ReviewSectionKey.values) section: const [],
      },
    );
  }

  factory ReviewSections.fromLegacy({
    required List<ClusterGroup> clusters,
    required List<MediaItem> noise,
  }) {
    final groupsBySection = {
      for (final section in ReviewSectionKey.values) section: <ReviewGroup>[],
    };

    for (final cluster in clusters) {
      final section = _sectionForLegacyCategory(cluster.category);
      final group = _reviewGroupFromLegacyCluster(cluster, section);
      if (group != null) {
        groupsBySection[section]!.add(group);
      }
    }

    for (final item in noise) {
      if (item.localAssetId.isEmpty) {
        continue;
      }
      final section = _sectionForLegacyCategory(item.category);
      groupsBySection[section]!.add(
        ReviewGroup(
          groupId: 'legacy-noise-${item.localAssetId}',
          section: section,
          keepItem: item,
          discardItems: const [],
          allItems: [item],
          reclaimableSize: item.fileSize,
          reviewAction: 'review_only',
          undoSeconds: 5,
          confidence: 0,
          reason: item.category.label,
          groupReasonShort: section.defaultShortReason,
          groupReason: section.defaultLongReason,
          reasonSource: 'legacy',
        ),
      );
    }

    return ReviewSections(groupsBySection: groupsBySection);
  }

  final Map<ReviewSectionKey, List<ReviewGroup>> groupsBySection;

  List<ReviewGroup> operator [](ReviewSectionKey section) {
    return groupsBySection[section] ?? const [];
  }

  bool get isEmpty {
    return groupsBySection.values.every((groups) => groups.isEmpty);
  }

  int get totalGroupCount {
    return groupsBySection.values.fold<int>(
      0,
      (total, groups) =>
          total + groups.where((group) => group.shouldShowInReviewFlow).length,
    );
  }

  int groupCount(ReviewSectionKey section) {
    return this[section].where((group) => group.shouldShowInReviewFlow).length;
  }

  int reclaimableSize(ReviewSectionKey section) {
    return this[section]
        .where((group) => group.shouldShowInReviewFlow)
        .fold<int>(0, (total, group) => total + group.effectiveReclaimableSize);
  }

  ReviewSections mergeWith(ReviewSections other) {
    return ReviewSections(
      groupsBySection: {
        for (final section in ReviewSectionKey.values)
          section: [...this[section], ...other[section]],
      },
    );
  }
}

class ReviewGroup {
  const ReviewGroup({
    required this.groupId,
    required this.section,
    required this.keepItem,
    required this.discardItems,
    required this.allItems,
    required this.reclaimableSize,
    required this.reviewAction,
    required this.undoSeconds,
    required this.confidence,
    required this.reason,
    required this.groupReasonShort,
    required this.groupReason,
    required this.reasonSource,
  });

  factory ReviewGroup.fromJson(
    Map<String, dynamic> json,
    ReviewSectionKey fallbackSection,
  ) {
    final section = ReviewSectionKey.fromJson(
      json['category'],
      fallback: fallbackSection,
    );
    final keepItem = MediaItem.fromJson(_mapValue(json['keep_item']));
    final discardItems = _listOfMaps(
      json['discard_items'],
    ).map(MediaItem.fromJson).toList();
    final allItems = _listOfMaps(
      json['all_items'],
    ).map(MediaItem.fromJson).toList();

    return ReviewGroup(
      groupId: _stringValue(json['group_id']),
      section: section,
      keepItem: keepItem,
      discardItems: discardItems,
      allItems: allItems.isEmpty ? [keepItem, ...discardItems] : allItems,
      reclaimableSize: _intValue(json['reclaimable_size']),
      reviewAction: _stringValue(json['review_action']),
      undoSeconds: _intValue(json['undo_seconds'], fallback: 5),
      confidence: _doubleValue(json['confidence']),
      reason: _stringValue(json['reason']),
      groupReasonShort: _stringValue(json['group_reason_short']),
      groupReason: _stringValue(json['group_reason']),
      reasonSource: _stringValue(json['reason_source']),
    );
  }

  final String groupId;
  final ReviewSectionKey section;
  final MediaItem keepItem;
  final List<MediaItem> discardItems;
  final List<MediaItem> allItems;
  final int reclaimableSize;
  final String reviewAction;
  final int undoSeconds;
  final double confidence;
  final String reason;
  final String groupReasonShort;
  final String groupReason;
  final String reasonSource;

  String get displayReasonShort {
    if (groupReasonShort.trim().isNotEmpty) {
      return groupReasonShort;
    }
    if (reason.trim().isNotEmpty) {
      return reason;
    }
    return section.defaultShortReason;
  }

  String get displayReason {
    if (groupReason.trim().isNotEmpty) {
      return groupReason;
    }
    if (reason.trim().isNotEmpty) {
      return reason;
    }
    return section.defaultLongReason;
  }

  String get confidenceLabel {
    if (section == ReviewSectionKey.other) {
      return 'Нужна проверка';
    }
    if (confidence >= 0.85) {
      return 'Высокая уверенность';
    }
    if (confidence >= 0.65) {
      return 'Средняя уверенность';
    }
    return 'Нужна проверка';
  }

  List<MediaItem> get deletionItems {
    if (discardItems.isNotEmpty) {
      return discardItems;
    }
    if (section == ReviewSectionKey.other) {
      return _uniqueMediaItems(allItems.isEmpty ? [keepItem] : allItems);
    }
    if (section == ReviewSectionKey.selfies && allItems.length > 1) {
      final keepId = keepItem.localAssetId;
      return _uniqueMediaItems(
        allItems.where((item) => item.localAssetId != keepId),
      );
    }
    return const [];
  }

  int get effectiveReclaimableSize {
    if (reclaimableSize > 0) {
      return reclaimableSize;
    }
    return deletionItems.fold<int>(0, (total, item) => total + item.fileSize);
  }

  bool get shouldShowInReviewFlow {
    if (section != ReviewSectionKey.selfies) {
      return true;
    }
    return allItems.length > 1 && deletionItems.isNotEmpty;
  }

  bool get canQuickDelete {
    final normalizedAction = reviewAction.trim().toLowerCase();
    if (deletionItems.isEmpty) {
      return false;
    }
    if (section == ReviewSectionKey.selfies ||
        section == ReviewSectionKey.other) {
      return true;
    }
    return normalizedAction != 'review_only';
  }

  ReviewGroup copyWith({
    String? groupId,
    ReviewSectionKey? section,
    MediaItem? keepItem,
    List<MediaItem>? discardItems,
    List<MediaItem>? allItems,
    int? reclaimableSize,
    String? reviewAction,
    int? undoSeconds,
    double? confidence,
    String? reason,
    String? groupReasonShort,
    String? groupReason,
    String? reasonSource,
  }) {
    return ReviewGroup(
      groupId: groupId ?? this.groupId,
      section: section ?? this.section,
      keepItem: keepItem ?? this.keepItem,
      discardItems: discardItems ?? this.discardItems,
      allItems: allItems ?? this.allItems,
      reclaimableSize: reclaimableSize ?? this.reclaimableSize,
      reviewAction: reviewAction ?? this.reviewAction,
      undoSeconds: undoSeconds ?? this.undoSeconds,
      confidence: confidence ?? this.confidence,
      reason: reason ?? this.reason,
      groupReasonShort: groupReasonShort ?? this.groupReasonShort,
      groupReason: groupReason ?? this.groupReason,
      reasonSource: reasonSource ?? this.reasonSource,
    );
  }
}

ReviewGroup? _reviewGroupFromLegacyCluster(
  ClusterGroup cluster,
  ReviewSectionKey section,
) {
  final allItems = _uniqueMediaItems([
    cluster.bestItem,
    ...cluster.deleteCandidates,
    ...cluster.items,
  ]);
  if (allItems.isEmpty) {
    return null;
  }

  final keepItem = cluster.bestItem.localAssetId.isNotEmpty
      ? cluster.bestItem
      : allItems.first;
  final keepId = keepItem.localAssetId;
  final legacyDiscardItems = _uniqueMediaItems(
    cluster.deleteCandidates,
  ).where((item) => item.localAssetId != keepId).toList();
  final discardItems = legacyDiscardItems.isNotEmpty
      ? legacyDiscardItems
      : section == ReviewSectionKey.possibleDuplicates ||
            section == ReviewSectionKey.similarPhotos
      ? allItems.where((item) => item.localAssetId != keepId).toList()
      : const <MediaItem>[];

  return ReviewGroup(
    groupId: 'legacy-${cluster.category.apiValue}-${cluster.clusterId}',
    section: section,
    keepItem: keepItem,
    discardItems: discardItems,
    allItems: allItems,
    reclaimableSize: cluster.reclaimableSize == 0
        ? discardItems.fold<int>(0, (total, item) => total + item.fileSize)
        : cluster.reclaimableSize,
    reviewAction: discardItems.isEmpty
        ? 'review_only'
        : 'keep_best_discard_rest',
    undoSeconds: 5,
    confidence: cluster.recommendation.confidence,
    reason: cluster.recommendation.description.isNotEmpty
        ? cluster.recommendation.description
        : cluster.category.label,
    groupReasonShort: cluster.recommendation.title,
    groupReason: cluster.recommendation.description,
    reasonSource: 'legacy',
  );
}

ReviewSectionKey _sectionForLegacyCategory(SortaCategory category) {
  return switch (category) {
    SortaCategory.duplicate => ReviewSectionKey.possibleDuplicates,
    SortaCategory.similar => ReviewSectionKey.similarPhotos,
    SortaCategory.selfie => ReviewSectionKey.selfies,
    SortaCategory.document => ReviewSectionKey.documents,
    SortaCategory.screenshot => ReviewSectionKey.screenshots,
    SortaCategory.blurry => ReviewSectionKey.blurry,
    SortaCategory.other => ReviewSectionKey.other,
  };
}

List<MediaItem> _uniqueMediaItems(Iterable<MediaItem> items) {
  final seen = <String>{};
  final unique = <MediaItem>[];
  for (final item in items) {
    final id = item.localAssetId;
    if (id.isEmpty || !seen.add(id)) {
      continue;
    }
    unique.add(item);
  }
  return unique;
}

enum ReviewSectionKey {
  possibleDuplicates,
  similarPhotos,
  selfies,
  documents,
  screenshots,
  blurry,
  other;

  factory ReviewSectionKey.fromJson(
    Object? value, {
    ReviewSectionKey fallback = ReviewSectionKey.other,
  }) {
    return switch (_stringValue(value, fallback: fallback.apiValue)) {
      'possible_duplicates' => ReviewSectionKey.possibleDuplicates,
      'similar_photos' => ReviewSectionKey.similarPhotos,
      'selfies' => ReviewSectionKey.selfies,
      'documents' => ReviewSectionKey.documents,
      'screenshots' => ReviewSectionKey.screenshots,
      'blurry' || 'blurred' => ReviewSectionKey.blurry,
      'other' => ReviewSectionKey.other,
      _ => fallback,
    };
  }

  String get apiValue {
    return switch (this) {
      ReviewSectionKey.possibleDuplicates => 'possible_duplicates',
      ReviewSectionKey.similarPhotos => 'similar_photos',
      ReviewSectionKey.selfies => 'selfies',
      ReviewSectionKey.documents => 'documents',
      ReviewSectionKey.screenshots => 'screenshots',
      ReviewSectionKey.blurry => 'blurry',
      ReviewSectionKey.other => 'other',
    };
  }

  String get label {
    return switch (this) {
      ReviewSectionKey.possibleDuplicates => 'Вероятные дубликаты',
      ReviewSectionKey.similarPhotos => 'Похожие фото',
      ReviewSectionKey.selfies => 'Дубликаты селфи',
      ReviewSectionKey.documents => 'Документы',
      ReviewSectionKey.screenshots => 'Скриншоты',
      ReviewSectionKey.blurry => 'Размытые фото',
      ReviewSectionKey.other => 'Другое',
    };
  }

  String get defaultShortReason {
    return switch (this) {
      ReviewSectionKey.possibleDuplicates => 'Почти одинаковые кадры',
      ReviewSectionKey.similarPhotos => 'Лучший кадр выбран автоматически',
      ReviewSectionKey.selfies => 'Повторяющиеся селфи',
      ReviewSectionKey.documents => 'Проверьте перед удалением',
      ReviewSectionKey.screenshots => 'Часто быстро теряют актуальность',
      ReviewSectionKey.blurry => 'Фото выглядит менее четким',
      ReviewSectionKey.other => 'Нужна ручная проверка',
    };
  }

  String get defaultLongReason {
    return switch (this) {
      ReviewSectionKey.possibleDuplicates =>
        'В этой группе собраны почти одинаковые кадры. Лучший выбран по качеству, остальные можно проверить перед удалением.',
      ReviewSectionKey.similarPhotos =>
        'В этой группе собраны похожие фото. Проверьте кадры спокойно и оставьте тот вариант, который вам нравится.',
      ReviewSectionKey.selfies =>
        'В этой группе собраны похожие или повторяющиеся селфи. Лучший кадр выбран по качеству, остальные можно спокойно проверить перед удалением.',
      ReviewSectionKey.documents =>
        'Это могут быть документы или важные снимки. Проверьте группу вручную перед любым удалением.',
      ReviewSectionKey.screenshots =>
        'Скриншоты часто быстро теряют актуальность, но их все равно стоит проверить перед очисткой.',
      ReviewSectionKey.blurry =>
        'Фото выглядит менее четким, поэтому мы предлагаем проверить его отдельно.',
      ReviewSectionKey.other =>
        'Для этой группы нужна ручная проверка. Мы не будем агрессивно предлагать удаление.',
    };
  }
}

class AnalyzeDecision {
  const AnalyzeDecision({
    required this.filename,
    required this.suggestedAction,
    required this.reason,
    required this.confidence,
  });

  factory AnalyzeDecision.fromJson(Map<String, dynamic> json) {
    return AnalyzeDecision(
      filename: _stringValue(json['filename']),
      suggestedAction: _stringValue(json['suggested_action']),
      reason: _stringValue(json['reason']),
      confidence: _doubleValue(json['confidence']),
    );
  }

  final String filename;
  final String suggestedAction;
  final String reason;
  final double confidence;
}

class AnalyzeSummary {
  const AnalyzeSummary({
    required this.scannedCount,
    required this.totalSize,
    required this.canBeCleaned,
    required this.duplicatesSize,
    required this.similarSize,
    required this.screenshotsSize,
    required this.otherSize,
    this.reviewGroupsCount = 0,
    this.potentialReclaimableSize = 0,
    this.possibleDuplicatesCount = 0,
    this.similarPhotosCount = 0,
    this.selfiesCount = 0,
    this.documentsCount = 0,
    this.screenshotsCount = 0,
    this.blurryCount = 0,
    this.otherCount = 0,
    this.headline = '',
    this.subtitle = '',
  });

  factory AnalyzeSummary.fromJson(Map<String, dynamic> json) {
    final canBeCleaned = _intValue(json['can_be_cleaned']);
    final potentialReclaimableSize = _intValue(
      json['potential_reclaimable_size'],
      fallback: canBeCleaned,
    );
    return AnalyzeSummary(
      scannedCount: _intValue(json['scanned_count']),
      totalSize: _intValue(json['total_size']),
      canBeCleaned: canBeCleaned == 0 ? potentialReclaimableSize : canBeCleaned,
      duplicatesSize: _intValue(json['duplicates_size']),
      similarSize: _intValue(json['similar_size']),
      screenshotsSize: _intValue(json['screenshots_size']),
      otherSize: _intValue(json['other_size']),
      reviewGroupsCount: _intValue(json['review_groups_count']),
      potentialReclaimableSize: potentialReclaimableSize,
      possibleDuplicatesCount: _intValue(json['possible_duplicates_count']),
      similarPhotosCount: _intValue(json['similar_photos_count']),
      selfiesCount: _intValue(json['selfies_count']),
      documentsCount: _intValue(json['documents_count']),
      screenshotsCount: _intValue(json['screenshots_count']),
      blurryCount: _intValue(json['blurry_count']),
      otherCount: _intValue(json['other_count']),
      headline: _stringValue(json['headline']),
      subtitle: _stringValue(json['subtitle']),
    );
  }

  final int scannedCount;
  final int totalSize;
  final int canBeCleaned;
  final int duplicatesSize;
  final int similarSize;
  final int screenshotsSize;
  final int otherSize;
  final int reviewGroupsCount;
  final int potentialReclaimableSize;
  final int possibleDuplicatesCount;
  final int similarPhotosCount;
  final int selfiesCount;
  final int documentsCount;
  final int screenshotsCount;
  final int blurryCount;
  final int otherCount;
  final String headline;
  final String subtitle;

  bool get hasValues {
    return scannedCount > 0 ||
        totalSize > 0 ||
        canBeCleaned > 0 ||
        duplicatesSize > 0 ||
        similarSize > 0 ||
        screenshotsSize > 0 ||
        otherSize > 0 ||
        reviewGroupsCount > 0 ||
        potentialReclaimableSize > 0 ||
        possibleDuplicatesCount > 0 ||
        similarPhotosCount > 0 ||
        selfiesCount > 0 ||
        documentsCount > 0 ||
        screenshotsCount > 0 ||
        blurryCount > 0 ||
        otherCount > 0 ||
        headline.isNotEmpty ||
        subtitle.isNotEmpty;
  }

  AnalyzeSummary copyWith({
    int? scannedCount,
    int? totalSize,
    int? canBeCleaned,
    int? duplicatesSize,
    int? similarSize,
    int? screenshotsSize,
    int? otherSize,
    int? reviewGroupsCount,
    int? potentialReclaimableSize,
    int? possibleDuplicatesCount,
    int? similarPhotosCount,
    int? selfiesCount,
    int? documentsCount,
    int? screenshotsCount,
    int? blurryCount,
    int? otherCount,
    String? headline,
    String? subtitle,
  }) {
    return AnalyzeSummary(
      scannedCount: scannedCount ?? this.scannedCount,
      totalSize: totalSize ?? this.totalSize,
      canBeCleaned: canBeCleaned ?? this.canBeCleaned,
      duplicatesSize: duplicatesSize ?? this.duplicatesSize,
      similarSize: similarSize ?? this.similarSize,
      screenshotsSize: screenshotsSize ?? this.screenshotsSize,
      otherSize: otherSize ?? this.otherSize,
      reviewGroupsCount: reviewGroupsCount ?? this.reviewGroupsCount,
      potentialReclaimableSize:
          potentialReclaimableSize ?? this.potentialReclaimableSize,
      possibleDuplicatesCount:
          possibleDuplicatesCount ?? this.possibleDuplicatesCount,
      similarPhotosCount: similarPhotosCount ?? this.similarPhotosCount,
      selfiesCount: selfiesCount ?? this.selfiesCount,
      documentsCount: documentsCount ?? this.documentsCount,
      screenshotsCount: screenshotsCount ?? this.screenshotsCount,
      blurryCount: blurryCount ?? this.blurryCount,
      otherCount: otherCount ?? this.otherCount,
      headline: headline ?? this.headline,
      subtitle: subtitle ?? this.subtitle,
    );
  }

  AnalyzeSummary mergeWith(AnalyzeSummary other) {
    return AnalyzeSummary(
      scannedCount: scannedCount + other.scannedCount,
      totalSize: totalSize + other.totalSize,
      canBeCleaned: canBeCleaned + other.canBeCleaned,
      duplicatesSize: duplicatesSize + other.duplicatesSize,
      similarSize: similarSize + other.similarSize,
      screenshotsSize: screenshotsSize + other.screenshotsSize,
      otherSize: otherSize + other.otherSize,
      reviewGroupsCount: reviewGroupsCount + other.reviewGroupsCount,
      potentialReclaimableSize:
          potentialReclaimableSize + other.potentialReclaimableSize,
      possibleDuplicatesCount:
          possibleDuplicatesCount + other.possibleDuplicatesCount,
      similarPhotosCount: similarPhotosCount + other.similarPhotosCount,
      selfiesCount: selfiesCount + other.selfiesCount,
      documentsCount: documentsCount + other.documentsCount,
      screenshotsCount: screenshotsCount + other.screenshotsCount,
      blurryCount: blurryCount + other.blurryCount,
      otherCount: otherCount + other.otherCount,
      headline: other.headline.isNotEmpty ? other.headline : headline,
      subtitle: other.subtitle.isNotEmpty ? other.subtitle : subtitle,
    );
  }

  AnalyzeSummary withReviewSectionsFallback(ReviewSections sections) {
    if (sections.isEmpty) {
      return this;
    }

    final groupsCount = sections.totalGroupCount;
    final possibleDuplicatesGroups = sections.groupCount(
      ReviewSectionKey.possibleDuplicates,
    );
    final similarPhotosGroups = sections.groupCount(
      ReviewSectionKey.similarPhotos,
    );
    final selfiesGroups = sections.groupCount(ReviewSectionKey.selfies);
    final documentsGroups = sections.groupCount(ReviewSectionKey.documents);
    final screenshotsGroups = sections.groupCount(ReviewSectionKey.screenshots);
    final blurryGroups = sections.groupCount(ReviewSectionKey.blurry);
    final otherGroups = sections.groupCount(ReviewSectionKey.other);
    final duplicatesReclaimable = sections.reclaimableSize(
      ReviewSectionKey.possibleDuplicates,
    );
    final similarReclaimable = sections.reclaimableSize(
      ReviewSectionKey.similarPhotos,
    );
    final otherReclaimable = sections.reclaimableSize(ReviewSectionKey.other);
    final totalReclaimable =
        duplicatesReclaimable +
        similarReclaimable +
        sections.reclaimableSize(ReviewSectionKey.selfies) +
        sections.reclaimableSize(ReviewSectionKey.documents) +
        sections.reclaimableSize(ReviewSectionKey.screenshots) +
        sections.reclaimableSize(ReviewSectionKey.blurry) +
        otherReclaimable;

    return copyWith(
      canBeCleaned: canBeCleaned == 0 ? totalReclaimable : canBeCleaned,
      duplicatesSize: duplicatesSize == 0
          ? duplicatesReclaimable
          : duplicatesSize,
      similarSize: similarSize == 0 ? similarReclaimable : similarSize,
      otherSize: otherSize == 0 ? otherReclaimable : otherSize,
      reviewGroupsCount: reviewGroupsCount == 0
          ? groupsCount
          : reviewGroupsCount,
      potentialReclaimableSize: potentialReclaimableSize == 0
          ? totalReclaimable
          : potentialReclaimableSize,
      possibleDuplicatesCount: possibleDuplicatesCount == 0
          ? possibleDuplicatesGroups
          : possibleDuplicatesCount,
      similarPhotosCount: similarPhotosCount == 0
          ? similarPhotosGroups
          : similarPhotosCount,
      selfiesCount: selfiesCount == 0 ? selfiesGroups : selfiesCount,
      documentsCount: documentsCount == 0 ? documentsGroups : documentsCount,
      screenshotsCount: screenshotsCount == 0
          ? screenshotsGroups
          : screenshotsCount,
      blurryCount: blurryCount == 0 ? blurryGroups : blurryCount,
      otherCount: otherCount == 0 ? otherGroups : otherCount,
    );
  }
}

class ClusterGroup {
  const ClusterGroup({
    required this.clusterId,
    required this.category,
    required this.count,
    required this.bestItem,
    required this.deleteCandidates,
    required this.items,
    required this.reclaimableSize,
    required this.recommendation,
  });

  factory ClusterGroup.fromJson(Map<String, dynamic> json) {
    return ClusterGroup(
      clusterId: _intValue(json['cluster_id']),
      category: SortaCategory.fromJson(json['category']),
      count: _intValue(json['count']),
      bestItem: MediaItem.fromJson(_mapValue(json['best_item'])),
      deleteCandidates: _listOfMaps(
        json['delete_candidates'],
      ).map(MediaItem.fromJson).toList(),
      items: _listOfMaps(json['items']).map(MediaItem.fromJson).toList(),
      reclaimableSize: _intValue(json['reclaimable_size']),
      recommendation: Recommendation.fromJson(
        _mapValue(json['recommendation']),
      ),
    );
  }

  final int clusterId;
  final SortaCategory category;
  final int count;
  final MediaItem bestItem;
  final List<MediaItem> deleteCandidates;
  final List<MediaItem> items;
  final int reclaimableSize;
  final Recommendation recommendation;

  ClusterGroup copyWith({
    int? clusterId,
    SortaCategory? category,
    int? count,
    MediaItem? bestItem,
    List<MediaItem>? deleteCandidates,
    List<MediaItem>? items,
    int? reclaimableSize,
    Recommendation? recommendation,
  }) {
    return ClusterGroup(
      clusterId: clusterId ?? this.clusterId,
      category: category ?? this.category,
      count: count ?? this.count,
      bestItem: bestItem ?? this.bestItem,
      deleteCandidates: deleteCandidates ?? this.deleteCandidates,
      items: items ?? this.items,
      reclaimableSize: reclaimableSize ?? this.reclaimableSize,
      recommendation: recommendation ?? this.recommendation,
    );
  }
}

class MediaItem {
  const MediaItem({
    required this.localAssetId,
    required this.filename,
    required this.mediaType,
    required this.category,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.createdAt,
    required this.quality,
    this.deleteReasonShort = '',
    this.deleteReason = '',
    this.deleteConfidence = 0,
    this.reasonSource = '',
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      localAssetId: _stringValue(json['local_asset_id']),
      filename: _stringValue(json['filename']),
      mediaType: _stringValue(json['media_type'], fallback: 'image'),
      category: SortaCategory.fromJson(json['category']),
      width: _intValue(json['width']),
      height: _intValue(json['height']),
      fileSize: _intValue(json['file_size']),
      createdAt: _stringValue(json['created_at']),
      quality: ItemQuality.fromJson(_mapValue(json['quality'])),
      deleteReasonShort: _stringValue(json['delete_reason_short']),
      deleteReason: _stringValue(json['delete_reason']),
      deleteConfidence: _doubleValue(json['delete_confidence']),
      reasonSource: _stringValue(json['reason_source']),
    );
  }

  final String localAssetId;
  final String filename;
  final String mediaType;
  final SortaCategory category;
  final int width;
  final int height;
  final int fileSize;
  final String createdAt;
  final ItemQuality quality;
  final String deleteReasonShort;
  final String deleteReason;
  final double deleteConfidence;
  final String reasonSource;

  String get displayDeleteReasonShort {
    if (deleteReasonShort.trim().isNotEmpty) {
      return deleteReasonShort;
    }
    return category == SortaCategory.other ? 'Нужна проверка' : category.label;
  }

  String get displayDeleteReason {
    if (deleteReason.trim().isNotEmpty) {
      return deleteReason;
    }
    return displayDeleteReasonShort;
  }

  String get deleteConfidenceLabel {
    if (deleteConfidence >= 0.85) {
      return 'Высокая уверенность';
    }
    if (deleteConfidence >= 0.65) {
      return 'Средняя уверенность';
    }
    return 'Нужна проверка';
  }

  MediaItem copyWith({
    String? localAssetId,
    String? filename,
    String? mediaType,
    SortaCategory? category,
    int? width,
    int? height,
    int? fileSize,
    String? createdAt,
    ItemQuality? quality,
    String? deleteReasonShort,
    String? deleteReason,
    double? deleteConfidence,
    String? reasonSource,
  }) {
    return MediaItem(
      localAssetId: localAssetId ?? this.localAssetId,
      filename: filename ?? this.filename,
      mediaType: mediaType ?? this.mediaType,
      category: category ?? this.category,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      quality: quality ?? this.quality,
      deleteReasonShort: deleteReasonShort ?? this.deleteReasonShort,
      deleteReason: deleteReason ?? this.deleteReason,
      deleteConfidence: deleteConfidence ?? this.deleteConfidence,
      reasonSource: reasonSource ?? this.reasonSource,
    );
  }
}

enum SortaCategory {
  duplicate,
  selfie,
  document,
  screenshot,
  blurry,
  similar,
  other;

  factory SortaCategory.fromJson(Object? value) {
    return switch (_stringValue(value, fallback: 'other')) {
      'duplicate' || 'possible_duplicates' => SortaCategory.duplicate,
      'selfie' || 'selfies' => SortaCategory.selfie,
      'document' || 'documents' => SortaCategory.document,
      'screenshot' || 'screenshots' => SortaCategory.screenshot,
      'blurry' || 'blurred' || 'blur' => SortaCategory.blurry,
      'similar' || 'similar_photos' => SortaCategory.similar,
      _ => SortaCategory.other,
    };
  }

  String get apiValue {
    return switch (this) {
      SortaCategory.duplicate => 'duplicate',
      SortaCategory.selfie => 'selfie',
      SortaCategory.document => 'document',
      SortaCategory.screenshot => 'screenshot',
      SortaCategory.blurry => 'blurry',
      SortaCategory.similar => 'similar',
      SortaCategory.other => 'other',
    };
  }

  String get label {
    return switch (this) {
      SortaCategory.duplicate => 'Вероятные дубликаты',
      SortaCategory.selfie => 'Похожее селфи',
      SortaCategory.document => 'Документы',
      SortaCategory.screenshot => 'Скриншоты',
      SortaCategory.blurry => 'Размытые фото',
      SortaCategory.similar => 'Похожие фото',
      SortaCategory.other => 'Другое',
    };
  }
}

class ItemQuality {
  const ItemQuality({
    required this.width,
    required this.height,
    required this.fileSize,
    required this.qualityScore,
    required this.blurScore,
  });

  factory ItemQuality.fromJson(Map<String, dynamic> json) {
    return ItemQuality(
      width: _intValue(json['width']),
      height: _intValue(json['height']),
      fileSize: _intValue(json['file_size']),
      qualityScore: _doubleValue(json['quality_score']),
      blurScore: _doubleValue(json['blur_score']),
    );
  }

  final int width;
  final int height;
  final int fileSize;
  final double qualityScore;
  final double blurScore;
}

class Recommendation {
  const Recommendation({
    required this.action,
    required this.title,
    required this.description,
    required this.confidence,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      action: _stringValue(json['action']),
      title: _stringValue(json['title']),
      description: _stringValue(json['description']),
      confidence: _doubleValue(json['confidence']),
    );
  }

  final String action;
  final String title;
  final String description;
  final double confidence;
}

String formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 GB';
  }

  final gigabytes = bytes / (1024 * 1024 * 1024);
  if (gigabytes >= 1) {
    return '${gigabytes.toStringAsFixed(2)} GB';
  }

  final megabytes = bytes / (1024 * 1024);
  if (megabytes >= 1) {
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  final kilobytes = bytes / 1024;
  return '${kilobytes.toStringAsFixed(1)} KB';
}

String formatShortDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    return '';
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

  return '${date.day} ${months[date.month - 1]}';
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

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList();
}

List<String> _listOfStrings(Object? value) {
  if (value is! List) {
    return const [];
  }

  return value.whereType<String>().where((item) => item.isNotEmpty).toList();
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

double _doubleValue(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return fallback;
}

String? _nullableStringValue(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

bool _boolValue(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return fallback;
}
