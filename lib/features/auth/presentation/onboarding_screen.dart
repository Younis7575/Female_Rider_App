import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'session_controller.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(Icons.verified_user_rounded, 'Women-only, safety first',
      'Every rider and driver is a verified woman. Trip PINs, live trip sharing and a one-tap SOS keep you protected on every ride.'),
  _Slide(Icons.handshake_rounded, 'Name your fare',
      'Propose the price you think is fair. Nearby drivers accept or counter, and you choose the offer that suits you best.'),
  _Slide(Icons.drive_eta_rounded, 'Drive and earn',
      'Switch to Driver mode any time. Drive on your own schedule, keep most of the fare and get paid out to your bank or wallet.'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(sessionProvider.notifier).markOnboardingSeen();
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _finish, child: const Text('Skip')),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.crimson : AppColors.rose,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: AppButton(
              label: last ? 'Get started' : 'Next',
              icon: last ? Icons.arrow_forward_rounded : null,
              onPressed: last
                  ? _finish
                  : () => _controller.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 200,
          height: 200,
          decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle, boxShadow: AppShadows.brand),
          child: Icon(slide.icon, size: 88, color: Colors.white),
        ),
        const SizedBox(height: AppSpace.xxl),
        Text(slide.title, style: AppText.h1, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.sm),
        Text(slide.body, style: AppText.body.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
      ]),
    );
  }
}
