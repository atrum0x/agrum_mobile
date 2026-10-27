import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import 'app_shell.dart';

/// Bottom tab bar: a white bar with a notch under the selected tab, holding a raised circle in
/// the primary color. The notch and circle slide to the tab that is tapped.
class NotchedTabBar extends StatelessWidget {
  const NotchedTabBar({super.key, required this.tabs, required this.selected, required this.onSelect});

  final List<AppTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  static const _barHeight = 68.0;
  static const _circleRadius = 27.0;
  static const _notchRadius = 35.0;

  /// How far the circle rises above the bar.
  static const _overhang = 30.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: _overhang + _barHeight + bottomInset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / tabs.length;
          return TweenAnimationBuilder<double>(
            tween: Tween(end: selected.toDouble()),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, position, _) {
              final centerX = itemWidth * (position + 0.5);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _NotchedBarPainter(centerX: centerX, top: _overhang, notchRadius: _notchRadius),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _overhang,
                    height: _barHeight,
                    child: Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: _TabItem(
                              tab: tabs[i],
                              selected: i == selected,
                              onTap: () {
                                if (i == selected) return;
                                HapticFeedback.selectionClick();
                                onSelect(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: centerX - _circleRadius,
                    top: _overhang - _circleRadius - 4,
                    child: _RaisedCircle(icon: tabs[selected].icon, radius: _circleRadius),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected, required this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // The selected tab's icon is in the raised circle; keep the label on the same line
            AnimatedOpacity(
              opacity: selected ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Icon(tab.icon, size: 24, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 4),
            // Fixed height, so a label shrunk to fit stays on the same line as the others
            Container(
              height: 22,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: selected ? AppColors.primary : AppColors.mutedForeground,
                  ),
                  child: Text(tab.label, maxLines: 1),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _RaisedCircle extends StatelessWidget {
  const _RaisedCircle({required this.icon, required this.radius});

  final IconData icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: Icon(icon, key: ValueKey(icon), color: Colors.white, size: 26),
      ),
    );
  }
}

/// The white bar with rounded top corners and a smooth circular notch at [centerX].
class _NotchedBarPainter extends CustomPainter {
  _NotchedBarPainter({required this.centerX, required this.top, required this.notchRadius});

  final double centerX;
  final double top;
  final double notchRadius;

  static const _cornerRadius = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Rect.fromLTRB(0, top, size.width, size.height);
    final notch = Rect.fromCircle(center: Offset(centerX, top), radius: notchRadius);
    final notched = const CircularNotchedRectangle().getOuterPath(bar, notch);
    final rounded = Path()
      ..addRRect(RRect.fromRectAndCorners(
        bar,
        topLeft: const Radius.circular(_cornerRadius),
        topRight: const Radius.circular(_cornerRadius),
      ));
    final path = Path.combine(PathOperation.intersect, notched, rounded);

    // The page is white too, so the edge needs both a shadow and a fine line
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.6), 12, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.border,
    );
  }

  @override
  bool shouldRepaint(_NotchedBarPainter old) =>
      old.centerX != centerX || old.top != top || old.notchRadius != notchRadius;
}
