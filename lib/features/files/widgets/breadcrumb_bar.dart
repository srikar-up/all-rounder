import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class BreadcrumbBar extends StatefulWidget {
  final List<MapEntry<String, String>> breadcrumbs;
  final ValueChanged<String> onSegmentTap;

  const BreadcrumbBar({
    super.key,
    required this.breadcrumbs,
    required this.onSegmentTap,
  });

  @override
  State<BreadcrumbBar> createState() => _BreadcrumbBarState();
}

class _BreadcrumbBarState extends State<BreadcrumbBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(BreadcrumbBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.breadcrumbs.length != widget.breadcrumbs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.breadcrumbs.length,
        separatorBuilder: (_, __) => Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
        ),
        itemBuilder: (context, index) {
          final crumb = widget.breadcrumbs[index];
          final isLast = index == widget.breadcrumbs.length - 1;

          return InkWell(
            onTap: isLast ? null : () => widget.onSegmentTap(crumb.value),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Center(
                child: Text(
                  crumb.key,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                    color: isLast
                        ? (isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight)
                        : (isDark ? AppColors.irisLight : AppColors.iris),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
