import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({
    super.key,
    required this.isRefreshing,
    required this.refreshAnimation,
    required this.onRefresh,
  });

  final bool isRefreshing;
  final Animation<double> refreshAnimation;
  final VoidCallback onRefresh;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(
        'Aedove',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isRefreshing
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(
                    context,
                  ).colorScheme.inversePrimary.withAlpha((0.5 * 255).round()),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            tooltip: 'Refresh Device Discovery',
            onPressed: onRefresh,
            icon: RotationTransition(
              turns: refreshAnimation,
              child: const Icon(Icons.refresh_rounded),
            ),
          ),
        ),
      ],
    );
  }
}
