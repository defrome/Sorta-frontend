import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'sorta_colors.dart';
import 'sorta_spacing.dart';

class SortaHeader extends StatelessWidget {
  const SortaHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailingIcon = Icons.settings_outlined,
    this.trailingTooltip,
    this.onTrailingTap,
  });

  final String title;
  final Widget? leading;
  final IconData trailingIcon;
  final String? trailingTooltip;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: SortaSpacing.sm),
          ],
          Text(
            title,
            style: const TextStyle(
              color: SortaColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onTrailingTap,
            tooltip: trailingTooltip,
            icon: Icon(trailingIcon, size: 22, color: SortaColors.primary),
          ),
        ],
      ),
    );
  }
}

class ScanCircle extends StatefulWidget {
  const ScanCircle({super.key, this.isActive = false, this.onPressed});

  final bool isActive;
  final VoidCallback? onPressed;

  @override
  State<ScanCircle> createState() => _ScanCircleState();
}

class _ScanCircleState extends State<ScanCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant ScanCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.isActive ? null : widget.onPressed,
        child: SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.58),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(180, 180),
                    painter: ScanRingPainter(progress: _controller.value),
                  );
                },
              ),
              const Positioned(top: 34, child: SortaLogo(size: 94)),
              Positioned(
                bottom: 42,
                child: Text(
                  widget.isActive ? 'Scanning' : 'Scan',
                  style: const TextStyle(
                    color: SortaColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScanRingPainter extends CustomPainter {
  const ScanRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ringRect = rect.deflate(4);
    final baseAngle = progress * math.pi * 2;
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: baseAngle,
        endAngle: baseAngle + math.pi * 2,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.36, 0.5, 0.64, 0.82],
      ).createShader(rect);
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: baseAngle,
        endAngle: baseAngle + math.pi * 2,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.34),
          Colors.white,
          Colors.white.withValues(alpha: 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.28, 0.5, 0.62, 0.78],
      ).createShader(rect);
    final secondaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.5);

    canvas.drawArc(ringRect, baseAngle - 1.54, 1.64, false, glowPaint);
    canvas.drawArc(ringRect, baseAngle - 1.54, 1.64, false, mainPaint);
    canvas.drawArc(
      ringRect.deflate(7),
      baseAngle + math.pi * 0.66,
      1.72,
      false,
      secondaryPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ScanRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class SortaLogo extends StatelessWidget {
  const SortaLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'lib/assets/sorta-logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class ValueBlock extends StatelessWidget {
  const ValueBlock({
    super.key,
    required this.eyebrow,
    required this.value,
    required this.caption,
  });

  final String eyebrow;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: SortaColors.secondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: SortaSpacing.xs),
        Text(
          value,
          style: const TextStyle(
            color: SortaColors.primary,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: SortaSpacing.xxs),
        Text(
          caption,
          style: const TextStyle(
            color: SortaColors.secondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = SortaSpacing.lg,
  });

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: SortaColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SortaColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class StorageRow extends StatelessWidget {
  const StorageRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Icon(icon, size: 22, color: SortaColors.primary),
              const SizedBox(width: SortaSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: SortaColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: SortaSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: onTap == null
                    ? SortaColors.secondary.withValues(alpha: 0.42)
                    : SortaColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.date,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: SortaSpacing.md + SortaSpacing.xxs),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: SortaColors.secondary,
                    fontSize: 13,
                  ),
                ),
              ),
              SizedBox(
                width: 54,
                child: Text(
                  date,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: SortaColors.secondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(Icons.check_rounded, size: 16),
              ),
              const SizedBox(width: SortaSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: SortaColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: SortaSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: SortaColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AiCard extends StatelessWidget {
  const AiCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      padding: SortaSpacing.xl - SortaSpacing.xs,
      child: Row(
        children: [
          AiOrb(),
          SizedBox(width: SortaSpacing.xl + SortaSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI found',
                  style: TextStyle(
                    color: SortaColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: SortaSpacing.sm - SortaSpacing.xxs),
                Text(
                  '12.6 GB',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: SortaSpacing.xxs),
                Text(
                  'to clean',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: SortaSpacing.md),
                Text(
                  'Duplicates, cache and\nlarge files',
                  style: TextStyle(
                    color: SortaColors.secondary,
                    fontSize: 14,
                    height: 1.35,
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

class AiOrb extends StatelessWidget {
  const AiOrb({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: SortaColors.border),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          const Icon(Icons.auto_awesome_rounded, size: 32),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onClear,
    this.hasText = false,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool hasText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: SortaSpacing.md),
      decoration: BoxDecoration(
        color: SortaColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 18,
            color: SortaColors.secondary,
          ),
          const SizedBox(width: SortaSpacing.sm + SortaSpacing.xxs),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: SortaColors.primary,
              style: const TextStyle(
                color: SortaColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: const InputDecoration(
                hintText: 'Search files...',
                hintStyle: TextStyle(
                  color: SortaColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (hasText)
            IconButton(
              onPressed: onClear,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: SortaColors.secondary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              tooltip: 'Clear search',
            ),
        ],
      ),
    );
  }
}

class TabPills extends StatelessWidget {
  const TabPills({super.key, required this.activeIndex, this.onChanged});

  final int activeIndex;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    const tabs = ['All', 'Images', 'Videos'];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final isActive = index == activeIndex;

          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged?.call(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SortaSpacing.lg,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? SortaColors.active : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SortaColors.divider),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: isActive
                        ? SortaColors.primary
                        : SortaColors.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (context, index) =>
            const SizedBox(width: SortaSpacing.sm),
        itemCount: tabs.length,
      ),
    );
  }
}

class GlassDivider extends StatelessWidget {
  const GlassDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: SortaSpacing.xs),
      color: SortaColors.divider,
    );
  }
}
