import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'models/analyze_models.dart';
import 'models/auth_user.dart';
import 'models/cleanup_basket.dart';
import 'pages/files_page.dart';
import 'pages/home_page.dart';
import 'pages/smart_clean_page.dart';
import 'services/auth_session.dart';
import 'shared/liquid_glass_navigation.dart';
import 'shared/sorta_colors.dart';
import 'shared/sorta_components.dart';
import 'shared/sorta_spacing.dart';

class SortaShell extends StatefulWidget {
  const SortaShell({super.key, this.analysis, this.initialIndex = 0});

  final AnalyzeResponse? analysis;
  final int initialIndex;

  @override
  State<SortaShell> createState() => _SortaShellState();
}

class _SortaShellState extends State<SortaShell> {
  late int selectedIndex;
  final Map<String, CleanupBasketItem> _cleanupBasket = {};
  OverlayEntry? _cleanupToastEntry;
  AuthUser? _authUser;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex.clamp(0, 2);
    _loadCachedProfile();
  }

  @override
  void dispose() {
    _cleanupToastEntry?.remove();
    super.dispose();
  }

  Future<void> _loadCachedProfile() async {
    final session = await AuthSessionStore.readSession();
    if (!mounted) return;
    setState(() => _authUser = session?.user);
  }

  @override
  Widget build(BuildContext context) {
    final basketItems = _cleanupBasket.values.toList(growable: false);
    final contentBottomPadding = basketItems.isEmpty ? 96.0 : 180.0;
    final pages = [
      HomePage(
        analysis: widget.analysis,
        authUser: _authUser,
        onContinueReview: () => setState(() => selectedIndex = 1),
      ),
      SmartCleanPage(
        analysis: widget.analysis,
        queuedGroupKeys: _cleanupBasket.keys.toSet(),
        onQueueDelete: _queueForCleanup,
        onUndoQueuedDelete: _removeFromCleanup,
        onShowQueuedDeleteToast: _showQueuedDeleteToast,
      ),
      FilesPage(analysis: widget.analysis),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    SortaSpacing.lg,
                    SortaSpacing.sm,
                    SortaSpacing.lg,
                    contentBottomPadding,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: pages[selectedIndex],
                  ),
                ),
              ),
            ),
          ),
          if (basketItems.isNotEmpty)
            Positioned(
              left: SortaSpacing.lg,
              right: SortaSpacing.lg,
              bottom: 92,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: _CleanupBasketBar(
                    photoCount: _basketPhotoCount,
                    reclaimableSize: _basketReclaimableSize,
                    isDeleting: _isDeleting,
                    onPressed: () => _openCleanupConfirmation(basketItems),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SortaLiquidGlassNavigation(
            items: const [
              SortaLiquidGlassNavigationItem(
                icon: Icons.home_filled,
                label: 'Home',
              ),
              SortaLiquidGlassNavigationItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Review',
              ),
              SortaLiquidGlassNavigationItem(
                icon: Icons.folder_rounded,
                label: 'Results',
              ),
            ],
            currentIndex: selectedIndex,
            onTap: (index) => setState(() => selectedIndex = index),
          ),
        ),
      ),
    );
  }

  int get _basketPhotoCount {
    final ids = <String>{};
    for (final item in _cleanupBasket.values) {
      ids.addAll(item.localAssetIds);
    }
    return ids.length;
  }

  int get _basketReclaimableSize {
    return _cleanupBasket.values.fold<int>(
      0,
      (total, item) => total + item.reclaimableSize,
    );
  }

  void _queueForCleanup(CleanupBasketItem item) {
    if (item.localAssetIds.isEmpty) return;
    setState(() => _cleanupBasket[item.groupKey] = item);
  }

  void _removeFromCleanup(String groupKey) {
    if (!mounted) return;
    setState(() => _cleanupBasket.remove(groupKey));
  }

  void _showQueuedDeleteToast({
    required int photoCount,
    required void Function() onUndo,
    Duration? duration,
  }) {
    _cleanupToastEntry?.remove();

    final overlay = Overlay.of(context, rootOverlay: true);
    var isRemoved = false;
    late final OverlayEntry entry;

    void removeEntry() {
      if (isRemoved) return;
      isRemoved = true;
      entry.remove();
      if (_cleanupToastEntry == entry) {
        _cleanupToastEntry = null;
      }
    }

    entry = OverlayEntry(
      builder: (context) => _CleanupUndoToast(
        photoCount: photoCount,
        duration: duration ?? const Duration(seconds: 5),
        onUndo: () {
          removeEntry();
          onUndo();
        },
        onDismissed: removeEntry,
      ),
    );

    _cleanupToastEntry = entry;
    overlay.insert(entry);
  }

  Future<void> _openCleanupConfirmation(List<CleanupBasketItem> items) async {
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CleanupConfirmSheet(
        items: items,
        photoCount: _basketPhotoCount,
        reclaimableSize: _basketReclaimableSize,
      ),
    );

    if (shouldDelete == true) {
      await _deleteBasketItems();
    }
  }

  Future<void> _deleteBasketItems() async {
    if (_cleanupBasket.isEmpty || _isDeleting) return;

    final ids = <String>{
      for (final item in _cleanupBasket.values) ...item.localAssetIds,
    }.toList();
    if (ids.isEmpty) return;

    setState(() => _isDeleting = true);
    try {
      final deletedIds = await PhotoManager.editor.deleteWithIds(ids);
      if (!mounted) return;

      if (deletedIds.isNotEmpty) {
        setState(() {
          _cleanupBasket.clear();
          selectedIndex = 2;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Удалено ${deletedIds.length} фото')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Удаление отменено')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось удалить фото')));
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}

class _CleanupUndoToast extends StatefulWidget {
  const _CleanupUndoToast({
    required this.photoCount,
    required this.duration,
    required this.onUndo,
    required this.onDismissed,
  });

  final int photoCount;
  final Duration duration;
  final VoidCallback onUndo;
  final VoidCallback onDismissed;

  @override
  State<_CleanupUndoToast> createState() => _CleanupUndoToastState();
}

class _CleanupUndoToastState extends State<_CleanupUndoToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Timer? _timer;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 1200),
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _opacity = _curve;
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(_curve);

    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  void _undo() {
    if (_isClosing) return;
    _isClosing = true;
    _timer?.cancel();
    widget.onUndo();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: SortaSpacing.lg,
      right: SortaSpacing.lg,
      bottom: 84,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: FadeTransition(
              opacity: _opacity,
              child: SlideTransition(
                position: _offset,
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xCC2C2C2E),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_sweep_rounded,
                                color: SortaColors.primary,
                                size: 21,
                              ),
                              const SizedBox(width: SortaSpacing.sm),
                              const Expanded(
                                child: Text(
                                  'Группа отправлена на удаление',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: SortaColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _undo,
                                style: TextButton.styleFrom(
                                  foregroundColor: SortaColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Undo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

class _CleanupBasketBar extends StatelessWidget {
  const _CleanupBasketBar({
    required this.photoCount,
    required this.reclaimableSize,
    required this.isDeleting,
    required this.onPressed,
  });

  final int photoCount;
  final int reclaimableSize;
  final bool isDeleting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: SortaSpacing.sm,
      child: Row(
        children: [
          const SizedBox(width: SortaSpacing.sm),
          const Icon(Icons.delete_sweep_rounded, color: SortaColors.primary),
          const SizedBox(width: SortaSpacing.sm),
          Expanded(
            child: Text(
              '$photoCount фото · ${formatBytes(reclaimableSize)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SortaColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            onPressed: isDeleting ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white24,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}

class _CleanupConfirmSheet extends StatelessWidget {
  const _CleanupConfirmSheet({
    required this.items,
    required this.photoCount,
    required this.reclaimableSize,
  });

  final List<CleanupBasketItem> items;
  final int photoCount;
  final int reclaimableSize;

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
            SortaSpacing.lg,
            SortaSpacing.lg,
            SortaSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Готово удалить?',
                style: TextStyle(
                  color: SortaColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: SortaSpacing.sm),
              Text(
                '$photoCount фото · освободить ${formatBytes(reclaimableSize)}',
                style: const TextStyle(
                  color: SortaColors.secondary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: SortaSpacing.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 190),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const GlassDivider(),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: SortaSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.section.label,
                              style: const TextStyle(
                                color: SortaColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${item.photoCount} фото',
                            style: const TextStyle(
                              color: SortaColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: SortaSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: SortaSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Удалить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
