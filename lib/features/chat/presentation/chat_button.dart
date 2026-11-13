import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';

/// Unread-count badge used on chat entry points.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count, required this.child});
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      backgroundColor: AppColors.crimson,
      label: Text(count > 9 ? '9+' : '$count', semanticsLabel: '$count unread'),
      child: child,
    );
  }
}

/// Round chat icon button that opens the trip chat.
class TripChatIconButton extends StatelessWidget {
  const TripChatIconButton({super.key, required this.tripId, required this.unread, this.onReturn});
  final String tripId;
  final int unread;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Chat',
      style: IconButton.styleFrom(backgroundColor: AppColors.roseSoft, foregroundColor: AppColors.crimson),
      onPressed: () async {
        await context.push(Routes.tripChat(tripId));
        onReturn?.call();
      },
      icon: UnreadBadge(count: unread, child: const Icon(Icons.chat_bubble_outline_rounded)),
    );
  }
}
