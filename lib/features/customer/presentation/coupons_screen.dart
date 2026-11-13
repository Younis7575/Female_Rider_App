import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/config_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../rides/domain/ride_models.dart';
import 'customer_providers.dart';

/// Active promo codes.
class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(couponsProvider);
    final currency = ref.watch(appConfigProvider).currency;
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons')),
      body: AsyncView<List<Coupon>>(
        value: coupons,
        onRetry: () => ref.invalidate(couponsProvider),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(couponsProvider.future),
          child: list.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EmptyState(icon: Icons.local_offer_outlined, title: 'No coupons right now', message: 'New offers will appear here. Enter a code when booking a ride.'),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpace.md),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
                  itemBuilder: (_, i) => _CouponCard(coupon: list[i], currency: currency),
                ),
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon, required this.currency});
  final Coupon coupon;
  final String currency;

  String get _headline {
    final percent = (coupon.type ?? '').toLowerCase().startsWith('percent');
    return percent ? '${coupon.value.toStringAsFixed(coupon.value % 1 == 0 ? 0 : 1)}% off' : '${formatMoney(coupon.value, currency: currency)} off';
  }

  @override
  Widget build(BuildContext context) {
    final terms = [
      if (coupon.maxDiscount != null && coupon.maxDiscount! > 0) 'Up to ${formatMoney(coupon.maxDiscount, currency: currency)}',
      if (coupon.minFare != null && coupon.minFare! > 0) 'Min fare ${formatMoney(coupon.minFare, currency: currency)}',
      if (coupon.endsAt != null) 'Valid until ${formatDate(coupon.endsAt)}',
    ];
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.card, boxShadow: AppShadows.card),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 96,
            decoration: const BoxDecoration(gradient: AppColors.brandGradient),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(AppSpace.xs),
            child: Text(_headline, textAlign: TextAlign.center, style: AppText.h3.copyWith(color: Colors.white)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.roseSoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.roseAccent),
                    ),
                    child: Text(coupon.code, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppColors.crimson)),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: coupon.code));
                      if (context.mounted) showSnack(context, 'Code ${coupon.code} copied', success: true);
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                  ),
                ]),
                if (coupon.description != null && coupon.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(coupon.description!, style: AppText.body),
                ],
                if (terms.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(terms.join(' · '), style: AppText.caption),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
