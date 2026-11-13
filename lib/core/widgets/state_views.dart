import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../network/api_envelope.dart';
import '../theme/app_theme.dart';
import 'buttons.dart';

/// Animated shimmer placeholder block.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8, this.circle = false});
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: widget.circle ? widget.height : widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 + 2 * t, 0),
              colors: const [Color(0xFFEFEDF0), Color(0xFFF8F7F9), Color(0xFFEFEDF0)],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton list of card-like rows.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.padding = const EdgeInsets.all(AppSpace.md)});
  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.card, border: Border.all(color: AppColors.line)),
        child: const Row(children: [
          Skeleton(height: 44, circle: true),
          SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(width: 160, height: 14),
              SizedBox(height: 8),
              Skeleton(width: 220, height: 12),
            ]),
          ),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon = Icons.inbox_outlined, this.actionLabel, this.onAction});
  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: AppColors.roseSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 38, color: AppColors.crimson),
          ),
          const SizedBox(height: AppSpace.md),
          Text(title, style: AppText.h3, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(message!, style: AppText.bodySm, textAlign: TextAlign.center),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpace.lg),
            AppButton(label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ]),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry, this.compact = false});
  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final offline = error is ApiException && (error as ApiException).isNetwork;
    final msg = errorMessage(error);
    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(children: [
          Icon(offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(msg, style: AppText.bodySm)),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
    }
    return EmptyState(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: offline ? 'You are offline' : 'Something went wrong',
      message: msg,
      actionLabel: onRetry != null ? 'Try again' : null,
      onAction: onRetry,
    );
  }
}

/// Renders an [AsyncValue] with consistent loading / error / data handling.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.onRetry, this.loading, this.skipLoadingOnRefresh = true});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;
  final bool skipLoadingOnRefresh;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue && (skipLoadingOnRefresh || !value.isLoading)) {
      return data(value.value as T);
    }
    if (value.hasError && !value.isLoading) {
      return ErrorState(error: value.error!, onRetry: onRetry);
    }
    return loading ?? const SkeletonList();
  }
}

/// Thin banner shown when realtime/network connectivity is degraded.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.message = 'Reconnecting… live updates paused, refreshing automatically.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warningSoft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 8),
        child: Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning)),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(message, style: AppText.caption.copyWith(color: AppColors.inkSoft))),
        ]),
      ),
    );
  }
}

/// Full-screen centred spinner.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        if (message != null) ...[const SizedBox(height: AppSpace.md), Text(message!, style: AppText.bodySm)],
      ]),
    );
  }
}
