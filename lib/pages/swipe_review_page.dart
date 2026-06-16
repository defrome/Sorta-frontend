import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/analyze_models.dart';
import '../models/cleanup_basket.dart';
import '../shared/sorta_colors.dart';
import '../shared/sorta_spacing.dart';

class SwipeReviewPage extends StatefulWidget {
  const SwipeReviewPage({
    super.key,
    required this.analysis,
    required this.section,
    required this.title,
    required this.queuedGroupKeys,
    required this.onQueueDelete,
    required this.onUndoQueuedDelete,
    required this.onShowQueuedDeleteToast,
  });

  final AnalyzeResponse analysis;
  final ReviewSectionKey section;
  final String title;
  final Set<String> queuedGroupKeys;
  final ValueChanged<CleanupBasketItem> onQueueDelete;
  final ValueChanged<String> onUndoQueuedDelete;
  final CleanupUndoToastCallback onShowQueuedDeleteToast;

  @override
  State<SwipeReviewPage> createState() => _SwipeReviewPageState();
}

class _SwipeReviewPageState extends State<SwipeReviewPage> {
  final Set<String> _reviewedGroupKeys = {};
  final Map<String, SwipeDecision> _decisions = {};
  final Map<String, String> _selectedKeepIds = {};

  @override
  Widget build(BuildContext context) {
    final queue = _swipeQueue;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SortaSpacing.lg,
                SortaSpacing.sm,
                SortaSpacing.lg,
                SortaSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SwipeHeader(title: widget.title),
                  const SizedBox(height: SortaSpacing.lg),
                  _LiquidStatusPill(
                    left: '${queue.length} left',
                    right: '${_decisions.length} reviewed',
                  ),
                  const SizedBox(height: SortaSpacing.lg),
                  Expanded(
                    child: queue.isEmpty
                        ? _SwipeCompletionState(
                            message: _decisions.isEmpty
                                ? 'No AI delete candidates here.'
                                : 'Все фото обработаны',
                          )
                        : PhotoSwipeDeck(
                            queue: queue,
                            emptyMessage: _decisions.isEmpty
                                ? 'No AI delete candidates here.'
                                : 'Все фото обработаны',
                            onDecision: _handleSwipeDecision,
                            onKeepChanged: _handleKeepChanged,
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

  List<SwipeQueueItem> get _swipeQueue {
    final items = <SwipeQueueItem>[];
    for (final group in widget.analysis.reviewSections[widget.section]) {
      final key = _groupKey(group);
      if (key.isEmpty ||
          _reviewedGroupKeys.contains(key) ||
          widget.queuedGroupKeys.contains(key) ||
          !group.shouldShowInReviewFlow) {
        continue;
      }
      items.add(SwipeQueueItem(group: _groupWithSelectedKeep(group)));
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
      _scheduleLocalDelete(queueItem.group);
    }
  }

  void _handleKeepChanged(SwipeQueueItem queueItem, MediaItem item) {
    setState(() {
      _selectedKeepIds[_groupKey(queueItem.group)] = item.localAssetId;
    });
  }

  void _scheduleLocalDelete(ReviewGroup group) {
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

class _SwipeCompletionState extends StatelessWidget {
  const _SwipeCompletionState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _LiquidGlassSurface(
        borderRadius: 28,
        child: Padding(
          padding: const EdgeInsets.all(SortaSpacing.xl),
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
              const SizedBox(height: SortaSpacing.sm),
              const Text(
                'Выбранные фото уже в корзине очистки снизу.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SortaColors.secondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeHeader extends StatelessWidget {
  const _SwipeHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          _LiquidIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: SortaSpacing.md),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SortaColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidStatusPill extends StatelessWidget {
  const _LiquidStatusPill({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return _LiquidGlassSurface(
      borderRadius: 24,
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SortaSpacing.lg),
          child: Row(
            children: [
              Text(left, style: _statusStyle),
              const Spacer(),
              Text(right, style: _statusStyle),
            ],
          ),
        ),
      ),
    );
  }

  static const _statusStyle = TextStyle(
    color: SortaColors.secondary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
}

class _LiquidIconButton extends StatelessWidget {
  const _LiquidIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _LiquidGlassSurface(
      borderRadius: 23,
      child: SizedBox.square(
        dimension: 46,
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: Icon(icon, color: SortaColors.primary, size: 22),
        ),
      ),
    );
  }
}

enum SwipeDecision { keep, delete }

class SwipeQueueItem {
  const SwipeQueueItem({required this.group});

  final ReviewGroup group;

  MediaItem get item => group.keepItem;
  String get reason => group.displayReasonShort;
  double? get confidence => group.confidence > 0 ? group.confidence : null;
  bool get canQuickDelete => group.canQuickDelete;
}

String _itemKey(MediaItem item) {
  return item.localAssetId.isNotEmpty ? item.localAssetId : item.filename;
}

String _groupKey(ReviewGroup group) {
  if (group.groupId.isNotEmpty) {
    return group.groupId;
  }
  return _itemKey(group.keepItem);
}

class PhotoSwipeDeck extends StatefulWidget {
  const PhotoSwipeDeck({
    super.key,
    required this.queue,
    required this.emptyMessage,
    required this.onDecision,
    required this.onKeepChanged,
  });

  final List<SwipeQueueItem> queue;
  final String emptyMessage;
  final void Function(SwipeQueueItem item, SwipeDecision decision) onDecision;
  final void Function(SwipeQueueItem item, MediaItem keepItem) onKeepChanged;

  @override
  State<PhotoSwipeDeck> createState() => _PhotoSwipeDeckState();
}

class _PhotoSwipeDeckState extends State<PhotoSwipeDeck>
    with TickerProviderStateMixin {
  late final AnimationController _flyController;
  late final AnimationController _returnController;
  late final AnimationController _appearController;
  final ValueNotifier<int> _dragTick = ValueNotifier<int>(0);

  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  Offset _flyStart = Offset.zero;
  Offset _flyEnd = Offset.zero;
  Offset _returnStart = Offset.zero;
  double _dragAngle = 0;
  double _flyStartAngle = 0;
  double _flyEndAngle = 0;
  double _returnStartAngle = 0;
  bool _isDragging = false;
  bool _isAnimatingOut = false;
  final Map<String, Future<Uint8List?>> _thumbnailFutures = {};
  final Map<String, Uint8List> _thumbnailBytes = {};

  @override
  void initState() {
    super.initState();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _returnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant PhotoSwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = oldWidget.queue.isEmpty
        ? null
        : _groupKey(oldWidget.queue.first.group);
    final newKey = widget.queue.isEmpty
        ? null
        : _groupKey(widget.queue.first.group);
    if (oldKey != newKey) {
      _resetDragState();
      _currentIndex = 0;
      _appearController.forward(from: 0);
    }

    final activeKeys = {
      for (final item in widget.queue)
        for (final groupItem in item.group.allItems) _itemKey(groupItem),
    };
    _thumbnailFutures.removeWhere((key, _) => !activeKeys.contains(key));
    _thumbnailBytes.removeWhere((key, _) => !activeKeys.contains(key));
  }

  @override
  void dispose() {
    _flyController.dispose();
    _returnController.dispose();
    _appearController.dispose();
    _dragTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deckItems = widget.queue.skip(_currentIndex).take(3).toList();

    if (deckItems.isEmpty) {
      return Center(child: _EmptySwipeState(message: widget.emptyMessage));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final controlsHeight = constraints.maxHeight < 520 ? 82.0 : 92.0;
        final cardAreaHeight = constraints.maxHeight - controlsHeight;
        final cardHeight = cardAreaHeight.clamp(320.0, 590.0).toDouble();
        final cardWidgets = [
          for (final entry in deckItems.asMap().entries)
            _PhotoSwipeCard(
              key: ValueKey('card-${_groupKey(entry.value.group)}'),
              queueItem: entry.value,
              thumbnailFuture: _thumbnailFutureFor(entry.value.item),
              thumbnailBytes: _thumbnailBytes[_itemKey(entry.value.item)],
              remainingCount: widget.queue.length - _currentIndex,
              height: cardHeight,
              showDetails: entry.key == 0,
              overlayDecision: null,
              overlayOpacity: 0,
              onKeepChanged: (keepItem) =>
                  widget.onKeepChanged(entry.value, keepItem),
            ),
        ];

        return Column(
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _dragTick,
                  _flyController,
                  _returnController,
                  _appearController,
                ]),
                builder: (context, _) {
                  final outProgress = _flyController.value;
                  final appearProgress = Curves.easeOut.transform(
                    _appearController.value,
                  );
                  final currentOffset = _animatedOffset;
                  final currentAngle = _animatedAngle;
                  final visibleDecision = _visibleDecision(
                    currentOffset.dx,
                    screenWidth,
                  );
                  final decision =
                      visibleDecision == SwipeDecision.delete &&
                          !deckItems.first.canQuickDelete
                      ? null
                      : visibleDecision;
                  final overlayOpacity = _overlayOpacity(
                    currentOffset.dx,
                    screenWidth,
                  );

                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      for (
                        var index = deckItems.length - 1;
                        index >= 0;
                        index--
                      )
                        _DeckCardPosition(
                          key: ValueKey(
                            'deck-${_groupKey(deckItems[index].group)}',
                          ),
                          index: index,
                          outProgress: outProgress,
                          appearProgress: appearProgress,
                          isTop: index == 0,
                          child: IgnorePointer(
                            ignoring: index != 0 || _isAnimatingOut,
                            child: index == 0
                                ? GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onPanStart: (_) {
                                      if (_isAnimating) return;
                                      _isDragging = true;
                                    },
                                    onPanUpdate: (details) {
                                      if (_isAnimating) return;
                                      _dragOffset += details.delta;
                                      _dragAngle =
                                          _dragOffset.dx /
                                          (screenWidth / 2) *
                                          0.3;
                                      _dragTick.value += 1;
                                    },
                                    onPanEnd: (_) => _finishDrag(screenWidth),
                                    onPanCancel: () => _animateBack(),
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..rotateZ(currentAngle)
                                        ..translateByDouble(
                                          currentOffset.dx,
                                          currentOffset.dy,
                                          0,
                                          1,
                                        ),
                                      child: _SwipeCardOverlayFrame(
                                        card: cardWidgets[index],
                                        decision: decision,
                                        overlayOpacity: overlayOpacity,
                                      ),
                                    ),
                                  )
                                : cardWidgets[index],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(
              height: controlsHeight,
              child: _SwipeBottomControls(
                canDelete: deckItems.first.canQuickDelete,
                onDelete: () => _animateOut(SwipeDecision.delete, screenWidth),
                onKeep: () => _animateOut(SwipeDecision.keep, screenWidth),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List?> _thumbnailFutureFor(MediaItem item) {
    final key = _itemKey(item);
    if (key.isEmpty || item.localAssetId.isEmpty) {
      return Future<Uint8List?>.value(null);
    }

    final cachedBytes = _thumbnailBytes[key];
    if (cachedBytes != null) {
      return Future<Uint8List?>.value(cachedBytes);
    }

    return _thumbnailFutures.putIfAbsent(key, () async {
      final asset = await AssetEntity.fromId(item.localAssetId);
      final bytes = await asset?.thumbnailDataWithSize(
        const ThumbnailSize(720, 720),
        format: ThumbnailFormat.jpeg,
        quality: 82,
      );
      if (bytes != null) {
        _thumbnailBytes[key] = bytes;
      }
      return bytes;
    });
  }

  bool get _isAnimating =>
      _flyController.isAnimating || _returnController.isAnimating;

  Offset get _animatedOffset {
    if (_flyController.isAnimating || _flyController.value > 0) {
      return Offset.lerp(
            _flyStart,
            _flyEnd,
            Curves.easeIn.transform(_flyController.value),
          ) ??
          _dragOffset;
    }
    if (_returnController.isAnimating || _returnController.value > 0) {
      return Offset.lerp(
            _returnStart,
            Offset.zero,
            Curves.elasticOut.transform(_returnController.value),
          ) ??
          _dragOffset;
    }
    return _dragOffset;
  }

  double get _animatedAngle {
    if (_flyController.isAnimating || _flyController.value > 0) {
      return lerpDouble(
            _flyStartAngle,
            _flyEndAngle,
            Curves.easeIn.transform(_flyController.value),
          ) ??
          _dragAngle;
    }
    if (_returnController.isAnimating || _returnController.value > 0) {
      return lerpDouble(
            _returnStartAngle,
            0,
            Curves.elasticOut.transform(_returnController.value),
          ) ??
          _dragAngle;
    }
    return _dragAngle.clamp(-0.3, 0.3);
  }

  SwipeDecision? _visibleDecision(double dx, double screenWidth) {
    if (dx.abs() <= 20) return null;
    return dx > 0 ? SwipeDecision.keep : SwipeDecision.delete;
  }

  double _overlayOpacity(double dx, double screenWidth) {
    if (dx.abs() <= 20) return 0;
    return (dx.abs() / (screenWidth * 0.3)).clamp(0.0, 1.0).toDouble();
  }

  void _finishDrag(double screenWidth) {
    if (!_isDragging) return;
    if (_currentIndex >= widget.queue.length) return;
    final threshold = screenWidth * 0.35;
    if (_dragOffset.dx < -threshold) {
      if (!widget.queue[_currentIndex].canQuickDelete) {
        _animateBack();
        return;
      }
      _animateOut(SwipeDecision.delete, screenWidth);
    } else if (_dragOffset.dx > threshold) {
      _animateOut(SwipeDecision.keep, screenWidth);
    } else {
      _animateBack();
    }
  }

  Future<void> _animateOut(SwipeDecision decision, double screenWidth) async {
    if (_isAnimating || _currentIndex >= widget.queue.length) return;

    final current = widget.queue[_currentIndex];
    if (decision == SwipeDecision.delete && !current.canQuickDelete) {
      await _animateBack();
      return;
    }
    _flyStart = _dragOffset;
    _flyStartAngle = _dragAngle;
    _flyEnd = Offset(
      decision == SwipeDecision.keep ? screenWidth * 1.5 : -screenWidth * 1.5,
      _dragOffset.dy,
    );
    _flyEndAngle = decision == SwipeDecision.keep ? 0.28 : -0.28;

    _isDragging = false;
    _isAnimatingOut = true;
    _dragTick.value += 1;

    await _flyController.forward(from: 0);
    if (!mounted) return;
    widget.onDecision(current, decision);
    if (!mounted) return;
    setState(_resetDragState);
    _appearController.forward(from: 0);
  }

  Future<void> _animateBack() async {
    _returnStart = _dragOffset;
    _returnStartAngle = _dragAngle;
    _isDragging = false;
    _dragTick.value += 1;
    await _returnController.forward(from: 0);
    if (!mounted) return;
    _resetDragState();
    _dragTick.value += 1;
  }

  void _resetDragState() {
    _dragOffset = Offset.zero;
    _flyStart = Offset.zero;
    _flyEnd = Offset.zero;
    _returnStart = Offset.zero;
    _dragAngle = 0;
    _flyStartAngle = 0;
    _flyEndAngle = 0;
    _returnStartAngle = 0;
    _isDragging = false;
    _isAnimatingOut = false;
    _flyController.reset();
    _returnController.reset();
  }
}

class _DeckCardPosition extends StatelessWidget {
  const _DeckCardPosition({
    super.key,
    required this.index,
    required this.outProgress,
    required this.appearProgress,
    required this.isTop,
    required this.child,
  });

  final int index;
  final double outProgress;
  final double appearProgress;
  final bool isTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isTop) {
      return child;
    }

    final lift = Curves.easeOut.transform(outProgress);
    final baseOffset = 24.0 * index;
    final baseScale = 1 - (0.08 * index);
    final promotedOffset = 24.0 * (index - 1);
    final promotedScale = 1 - (0.08 * (index - 1));

    final dy =
        lerpDouble(baseOffset, promotedOffset, lift)! +
        (1 - appearProgress) * 26;
    final scale = lerpDouble(baseScale, promotedScale, lift)!;

    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform.scale(scale: scale, child: child),
    );
  }
}

class _GlassCardFrame extends StatelessWidget {
  const _GlassCardFrame({required this.child, required this.borderRadius});

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PhotoSwipeCard extends StatelessWidget {
  const _PhotoSwipeCard({
    super.key,
    required this.queueItem,
    required this.thumbnailFuture,
    required this.thumbnailBytes,
    required this.remainingCount,
    required this.height,
    required this.showDetails,
    required this.overlayDecision,
    required this.overlayOpacity,
    required this.onKeepChanged,
  });

  final SwipeQueueItem queueItem;
  final Future<Uint8List?> thumbnailFuture;
  final Uint8List? thumbnailBytes;
  final int remainingCount;
  final double height;
  final bool showDetails;
  final SwipeDecision? overlayDecision;
  final double overlayOpacity;
  final ValueChanged<MediaItem>? onKeepChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: _GlassCardFrame(
          borderRadius: 28,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _SwipeAssetImage(
                  thumbnailFuture: thumbnailFuture,
                  initialBytes: thumbnailBytes,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.16),
                        Colors.black.withValues(alpha: 0.20),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0, 0.48, 1],
                    ),
                  ),
                ),
                if (showDetails)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _SwipeCardInfoPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SwipeCardCaption(
                            queueItem: queueItem,
                            remainingCount: remainingCount,
                          ),
                          const SizedBox(height: SortaSpacing.sm),
                          _SwipeThumbnailStrip(
                            group: queueItem.group,
                            onKeepChanged: onKeepChanged,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (overlayDecision != null && overlayOpacity > 0)
                  Positioned.fill(
                    child: _SwipeOverlay(
                      decision: overlayDecision!,
                      opacity: overlayOpacity,
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

class _SwipeCardOverlayFrame extends StatelessWidget {
  const _SwipeCardOverlayFrame({
    required this.card,
    required this.decision,
    required this.overlayOpacity,
  });

  final Widget card;
  final SwipeDecision? decision;
  final double overlayOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        card,
        if (decision != null && overlayOpacity > 0)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: _SwipeOverlay(
                decision: decision!,
                opacity: overlayOpacity,
              ),
            ),
          ),
      ],
    );
  }
}

class _SwipeCardInfoPanel extends StatelessWidget {
  const _SwipeCardInfoPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF050506).withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: child,
      ),
    );
  }
}

class _SwipeAssetImage extends StatefulWidget {
  const _SwipeAssetImage({
    required this.thumbnailFuture,
    required this.initialBytes,
  });

  final Future<Uint8List?> thumbnailFuture;
  final Uint8List? initialBytes;

  @override
  State<_SwipeAssetImage> createState() => _SwipeAssetImageState();
}

class _SwipeAssetImageState extends State<_SwipeAssetImage> {
  MemoryImage? _imageProvider;
  Future<Uint8List?>? _activeFuture;

  @override
  void initState() {
    super.initState();
    _imageProvider = _providerFromBytes(widget.initialBytes);
    _loadThumbnail(widget.thumbnailFuture);
  }

  @override
  void didUpdateWidget(covariant _SwipeAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thumbnailFuture != widget.thumbnailFuture) {
      _imageProvider = _providerFromBytes(widget.initialBytes);
      _loadThumbnail(widget.thumbnailFuture);
    } else if (_imageProvider == null && widget.initialBytes != null) {
      _imageProvider = _providerFromBytes(widget.initialBytes);
    }
  }

  void _loadThumbnail(Future<Uint8List?> future) {
    _activeFuture = future;
    _imageProvider ??= _providerFromBytes(widget.initialBytes);
    future
        .then((bytes) async {
          if (!mounted || _activeFuture != future || bytes == null) {
            return;
          }

          final provider = MemoryImage(bytes);
          await precacheImage(provider, context);
          if (mounted && _activeFuture == future) {
            setState(() => _imageProvider = provider);
          }
        })
        .catchError((_) {});
  }

  MemoryImage? _providerFromBytes(Uint8List? bytes) {
    if (bytes == null) {
      return null;
    }
    return MemoryImage(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider;

    return RepaintBoundary(
      child: provider == null
          ? const _SwipeImagePlaceholder()
          : Image(
              image: provider,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.none,
              isAntiAlias: false,
            ),
    );
  }
}

class _SwipeThumbnailStrip extends StatelessWidget {
  const _SwipeThumbnailStrip({
    required this.group,
    required this.onKeepChanged,
  });

  final ReviewGroup group;
  final ValueChanged<MediaItem>? onKeepChanged;

  @override
  Widget build(BuildContext context) {
    final items =
        (group.discardItems.isEmpty ? group.allItems : group.discardItems)
            .take(8)
            .toList();
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final isKeep = item.localAssetId == group.keepItem.localAssetId;
          return _SwipeStripThumbnail(
            item: item,
            isKeep: isKeep,
            onTap: () => _showDiscardItemSheet(
              context,
              item: item,
              onMakePrimary: onKeepChanged == null
                  ? null
                  : () => onKeepChanged?.call(item),
            ),
          );
        },
      ),
    );
  }
}

class _SwipeStripThumbnail extends StatelessWidget {
  const _SwipeStripThumbnail({
    required this.item,
    required this.isKeep,
    required this.onTap,
  });

  final MediaItem item;
  final bool isKeep;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: isKeep
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.22),
                  width: isKeep ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _AssetThumb(localAssetId: item.localAssetId),
                  if (isKeep)
                    const Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.check_circle_rounded, size: 14),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.displayDeleteReasonShort,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SortaColors.secondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetThumb extends StatefulWidget {
  const _AssetThumb({required this.localAssetId});

  final String localAssetId;

  @override
  State<_AssetThumb> createState() => _AssetThumbState();
}

class _AssetThumbState extends State<_AssetThumb> {
  static final Map<String, Future<Uint8List?>> _thumbFutures = {};
  static final Map<String, Uint8List> _thumbBytes = {};

  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _AssetThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localAssetId != widget.localAssetId) {
      _future = _load();
    }
  }

  Future<Uint8List?> _load() async {
    if (widget.localAssetId.isEmpty) {
      return null;
    }

    final cachedBytes = _thumbBytes[widget.localAssetId];
    if (cachedBytes != null) {
      return cachedBytes;
    }

    return _thumbFutures.putIfAbsent(widget.localAssetId, () async {
      final asset = await AssetEntity.fromId(widget.localAssetId);
      final bytes = await asset?.thumbnailDataWithSize(
        const ThumbnailSize(96, 96),
        format: ThumbnailFormat.jpeg,
        quality: 65,
      );
      if (bytes != null) {
        _thumbBytes[widget.localAssetId] = bytes;
      }
      return bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      initialData: _thumbBytes[widget.localAssetId],
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return const ColoredBox(color: Colors.white10);
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.none,
        );
      },
    );
  }
}

class _SwipeImagePlaceholder extends StatelessWidget {
  const _SwipeImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.white10,
      child: Icon(Icons.image_outlined, size: 42),
    );
  }
}

class _SwipeCardCaption extends StatelessWidget {
  const _SwipeCardCaption({
    required this.queueItem,
    required this.remainingCount,
  });

  final SwipeQueueItem queueItem;
  final int remainingCount;

  @override
  Widget build(BuildContext context) {
    final group = queueItem.group;
    final deleteCount = group.deletionItems.length;
    final reviewCount = deleteCount == 0 ? group.allItems.length : deleteCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.section.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SortaColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$remainingCount',
              style: const TextStyle(
                color: SortaColors.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: SortaSpacing.xs),
        Text(
          group.displayReasonShort,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: SortaColors.secondary, fontSize: 13),
        ),
        const SizedBox(height: SortaSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SwipeInfoPill(
              text:
                  'Можно освободить ${formatBytes(group.effectiveReclaimableSize)}',
            ),
            _SwipeInfoPill(text: '$reviewCount фото для проверки'),
            _SwipeInfoPill(text: group.confidenceLabel),
          ],
        ),
        const SizedBox(height: SortaSpacing.sm),
        TextButton(
          onPressed: () => _showGroupReasonSheet(context, group),
          style: TextButton.styleFrom(
            foregroundColor: SortaColors.primary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Почему это предложено?'),
        ),
      ],
    );
  }
}

class _SwipeInfoPill extends StatelessWidget {
  const _SwipeInfoPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: SortaColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

void _showGroupReasonSheet(BuildContext context, ReviewGroup group) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _ReasonSheetSurface(
        title: 'Почему это предложено?',
        body: group.displayReason,
        footer: group.confidenceLabel,
      );
    },
  );
}

void _showDiscardItemSheet(
  BuildContext context, {
  required MediaItem item,
  required VoidCallback? onMakePrimary,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _ReasonSheetSurface(
        title: item.displayDeleteReasonShort,
        body: item.displayDeleteReason,
        footer: item.deleteConfidenceLabel,
        preview: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: _AssetThumb(localAssetId: item.localAssetId),
          ),
        ),
        action: onMakePrimary == null
            ? null
            : () {
                Navigator.of(context).pop();
                onMakePrimary();
              },
      );
    },
  );
}

class _ReasonSheetSurface extends StatelessWidget {
  const _ReasonSheetSurface({
    required this.title,
    required this.body,
    required this.footer,
    this.preview,
    this.action,
  });

  final String title;
  final String body;
  final String footer;
  final Widget? preview;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SortaSpacing.lg,
            SortaSpacing.md,
            SortaSpacing.lg,
            SortaSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: SortaSpacing.lg),
              if (preview != null) ...[
                preview!,
                const SizedBox(height: SortaSpacing.lg),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: SortaColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: SortaSpacing.sm),
              Text(
                body,
                style: const TextStyle(
                  color: SortaColors.secondary,
                  fontSize: 14,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: SortaSpacing.md),
              Text(
                footer,
                style: const TextStyle(
                  color: SortaColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: SortaSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: action,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Сделать главным'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeBottomControls extends StatelessWidget {
  const _SwipeBottomControls({
    required this.canDelete,
    required this.onDelete,
    required this.onKeep,
  });

  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: LiquidGlassLayer(
        settings: const LiquidGlassSettings(
          thickness: 20,
          blur: 10,
          glassColor: Color(0x22FFFFFF),
          lightIntensity: 0.28,
          refractiveIndex: 1.20,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GlassButton(
              icon: Icons.close_rounded,
              tooltip: 'Delete',
              enabled: canDelete,
              onTap: onDelete,
            ),
            const SizedBox(width: 48),
            _GlassButton(
              icon: Icons.check_rounded,
              tooltip: 'Keep',
              enabled: true,
              onTap: onKeep,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatefulWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) return;
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  void _handlePointerUp(PointerUpEvent event) {
    final wasPressed = _isPressed;
    _setPressed(false);
    if (wasPressed && widget.enabled) {
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: _handlePointerUp,
        onPointerCancel: (_) => _setPressed(false),
        child: SizedBox.square(
          dimension: 76,
          child: Center(
            child: AnimatedScale(
              scale: _isPressed ? 0.96 : 1,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              child: LiquidGlass(
                shape: const LiquidRoundedSuperellipse(borderRadius: 50),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 110),
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: _isPressed ? 0.20 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.enabled
                        ? Colors.grey.shade400
                        : Colors.grey.shade700,
                    size: 34,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeOverlay extends StatelessWidget {
  const _SwipeOverlay({required this.decision, required this.opacity});

  final SwipeDecision decision;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final color = decision == SwipeDecision.keep
        ? const Color(0xFF35D07F)
        : const Color(0xFFFF4D5E);
    final icon = decision == SwipeDecision.keep
        ? Icons.check_rounded
        : Icons.delete_outline_rounded;

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color.withValues(alpha: 0.24)),
          child: Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.30),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
              ),
              child: Icon(icon, color: Colors.white, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySwipeState extends StatelessWidget {
  const _EmptySwipeState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SortaSpacing.xl),
        child: _LiquidGlassSurface(
          borderRadius: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SortaSpacing.xl,
              vertical: SortaSpacing.lg,
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: SortaColors.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassSurface extends StatelessWidget {
  const _LiquidGlassSurface({required this.child, this.borderRadius = 28});

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
