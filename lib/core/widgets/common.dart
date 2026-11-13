import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Rounded white surface card.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpace.md), this.onTap, this.color, this.border = true, this.shadow = false, this.margin});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool border;
  final bool shadow;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: AppRadius.card,
        border: border ? Border.all(color: AppColors.line) : null,
        boxShadow: shadow ? AppShadows.card : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? content
            : InkWell(borderRadius: AppRadius.card, onTap: onTap, child: content),
      ),
    );
  }
}

enum StatusTone { neutral, success, warning, danger, info, brand }

/// Small pill describing a status.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = StatusTone.neutral, this.icon, this.dense = false});

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool dense;

  static StatusTone toneFor(String status) {
    switch (status) {
      case 'approved':
      case 'completed':
      case 'paid':
      case 'active':
      case 'accepted':
      case 'resolved':
      case 'succeeded':
      case 'online':
        return StatusTone.success;
      case 'pending':
      case 'submitted':
      case 'under_review':
      case 'appealed':
      case 'processing':
      case 'open':
      case 'searching':
      case 'offers_available':
      case 'awaiting_approval':
      case 'requested':
        return StatusTone.warning;
      case 'rejected':
      case 'suspended':
      case 'failed':
      case 'expired':
      case 'cancelled_by_customer':
      case 'cancelled_by_driver':
      case 'cancelled_by_admin':
      case 'no_driver_found':
      case 'more_info_required':
        return StatusTone.danger;
      case 'driver_assigned':
      case 'driver_en_route':
      case 'arrived':
      case 'in_progress':
        return StatusTone.info;
      default:
        return StatusTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.success => (AppColors.successSoft, AppColors.success),
      StatusTone.warning => (AppColors.warningSoft, AppColors.warning),
      StatusTone.danger => (AppColors.dangerSoft, AppColors.danger),
      StatusTone.info => (AppColors.infoSoft, AppColors.info),
      StatusTone.brand => (AppColors.roseSoft, AppColors.crimson),
      StatusTone.neutral => (AppColors.field, AppColors.inkSoft),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: fg), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: dense ? 11 : 12, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

/// Avatar with network photo or initials fallback.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.url, this.name, this.size = 48, this.dark = false});

  final String? url;
  final String? name;
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: dark ? AppColors.driverGradient : null,
        color: dark ? null : AppColors.roseSoft,
      ),
      child: Text(
        initials(name),
        style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: dark ? Colors.white : AppColors.crimson),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (c, child, p) => p == null ? child : fallback,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.lg, AppSpace.md, AppSpace.xs)});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(child: Text(title.toUpperCase(), style: AppText.overline)),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}

/// Label / value row used in receipts and detail screens.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.bold = false, this.valueColor});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = bold ? AppText.h3 : AppText.title.copyWith(fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: bold ? AppText.h3 : AppText.body.copyWith(color: AppColors.muted))),
        const SizedBox(width: AppSpace.sm),
        // Right-aligned value that may wrap but never steals more than ~60% of the row.
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.55),
          child: Text(value, textAlign: TextAlign.right, style: style.copyWith(color: valueColor)),
        ),
      ]),
    );
  }
}

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.light = false});
  final num? rating;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
      const SizedBox(width: 2),
      Text(formatRating(rating), style: AppText.label.copyWith(color: light ? Colors.white : AppColors.ink)),
    ]);
  }
}

/// Brand mark from the bundled app icon.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) {
    // Align (shrink-wrapping via width/heightFactor) keeps the logo square even inside
    // stretching parents such as ListView, and centres it in both cases.
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.26), boxShadow: AppShadows.floating),
        padding: EdgeInsets.all(size * 0.06),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.2),
          child: Image.asset('assets/images/icon_square.png', fit: BoxFit.contain, semanticLabel: 'FemaleRider logo'),
        ),
      ),
    );
  }
}

/// Small grey drag handle / divider label.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.tone = StatusTone.info, this.icon, this.action, this.onAction, this.title});
  final String message;
  final String? title;
  final StatusTone tone;
  final IconData? icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.success => (AppColors.successSoft, AppColors.success),
      StatusTone.warning => (AppColors.warningSoft, AppColors.warning),
      StatusTone.danger => (AppColors.dangerSoft, AppColors.danger),
      StatusTone.brand => (AppColors.roseSoft, AppColors.crimson),
      StatusTone.neutral => (AppColors.field, AppColors.inkSoft),
      StatusTone.info => (AppColors.infoSoft, AppColors.info),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm + 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon ?? Icons.info_outline_rounded, color: fg, size: 20),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(title!, style: AppText.title.copyWith(color: fg))),
            Text(message, style: AppText.bodySm.copyWith(color: AppColors.inkSoft)),
            if (action != null)
              GestureDetector(
                onTap: onAction,
                child: Padding(padding: const EdgeInsets.only(top: 6), child: Text(action!, style: AppText.label.copyWith(color: fg, decoration: TextDecoration.underline))),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// A page-level gradient header (crimson in customer mode, charcoal in driver mode).
class GradientHeader extends StatelessWidget {
  const GradientHeader({super.key, required this.child, this.driver = false, this.padding = const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.lg)});
  final Widget child;
  final bool driver;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: driver ? AppColors.driverGradient : AppColors.brandGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      padding: padding,
      child: SafeArea(bottom: false, child: child),
    );
  }
}

/// Bottom-safe padded action area for forms.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line))),
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.sm),
      child: SafeArea(top: false, child: child),
    );
  }
}

class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}
