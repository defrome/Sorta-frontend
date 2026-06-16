import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'sorta_colors.dart';
import 'sorta_spacing.dart';

class SortaLiquidGlassNavigationItem {
  const SortaLiquidGlassNavigationItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class SortaLiquidGlassNavigation extends StatefulWidget {
  const SortaLiquidGlassNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  }) : assert(items.length >= 2);

  final List<SortaLiquidGlassNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  State<SortaLiquidGlassNavigation> createState() =>
      _SortaLiquidGlassNavigationState();
}

class _SortaLiquidGlassNavigationState
    extends State<SortaLiquidGlassNavigation> {
  static const _barHeight = 58.0;
  static const _borderRadius = 31.0;
  static const _duration = Duration(milliseconds: 260);
  static const _curve = Curves.easeOutCubic;

  double? _dragAlignment;
  bool _isDragging = false;

  int get _lastIndex => widget.items.length - 1;

  double _alignmentForIndex(int index) {
    if (_lastIndex == 0) return 0;
    return -1 + (index * 2 / _lastIndex);
  }

  int _indexForAlignment(double alignment) {
    final normalized = (alignment + 1) / 2;
    return (normalized * _lastIndex).round().clamp(0, _lastIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SortaSpacing.lg,
        SortaSpacing.sm,
        SortaSpacing.lg,
        SortaSpacing.xl,
      ),
      child: LiquidGlass.withOwnLayer(
        shape: const LiquidRoundedRectangle(borderRadius: _borderRadius),
        settings: const LiquidGlassSettings(
          thickness: 14,
          blur: 18,
          glassColor: Color(0x12FFFFFF),
          lightIntensity: 0.22,
          refractiveIndex: 1.18,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(_borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.36),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: SizedBox(
              height: _barHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth / widget.items.length;
                  final dragWidth = constraints.maxWidth - itemWidth;
                  final alignment =
                      _dragAlignment ?? _alignmentForIndex(widget.currentIndex);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) {
                      setState(() {
                        _isDragging = true;
                        _dragAlignment = _alignmentForIndex(
                          widget.currentIndex,
                        );
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      if (!_isDragging || dragWidth <= 0) return;

                      setState(() {
                        final delta = (details.primaryDelta! / dragWidth) * 2;
                        _dragAlignment = (_dragAlignment! + delta).clamp(
                          -1.0,
                          1.0,
                        );
                      });
                    },
                    onHorizontalDragEnd: (_) {
                      final index = _indexForAlignment(_dragAlignment!);

                      setState(() {
                        _isDragging = false;
                        _dragAlignment = null;
                      });

                      widget.onTap(index);
                    },
                    onHorizontalDragCancel: () {
                      setState(() {
                        _isDragging = false;
                        _dragAlignment = null;
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedAlign(
                          duration: _isDragging ? Duration.zero : _duration,
                          curve: _curve,
                          alignment: Alignment(alignment, 0),
                          child: _LiquidIndicator(width: itemWidth),
                        ),
                        Row(
                          children: [
                            for (
                              var index = 0;
                              index < widget.items.length;
                              index++
                            )
                              Expanded(
                                child: _LiquidNavItem(
                                  item: widget.items[index],
                                  isSelected: index == widget.currentIndex,
                                  onTap: () => widget.onTap(index),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidIndicator extends StatelessWidget {
  const _LiquidIndicator({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.13),
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 0),
          ),
        ],
      ),
    );
  }
}

class _LiquidNavItem extends StatelessWidget {
  const _LiquidNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final SortaLiquidGlassNavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? SortaColors.primary : SortaColors.secondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.16 : 1,
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              child: TweenAnimationBuilder<Color?>(
                duration: _SortaLiquidGlassNavigationState._duration,
                curve: _SortaLiquidGlassNavigationState._curve,
                tween: ColorTween(end: color),
                builder: (context, animatedColor, child) {
                  return Icon(item.icon, size: 23, color: animatedColor);
                },
              ),
            ),
            const SizedBox(height: SortaSpacing.xs),
            AnimatedDefaultTextStyle(
              duration: _SortaLiquidGlassNavigationState._duration,
              curve: _SortaLiquidGlassNavigationState._curve,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
