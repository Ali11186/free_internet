import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'accounts_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => _ready = true);
    });
  }

  void _start() {
    final p = context.read<AppProvider>();
    if (p.accounts.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AccountsScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.4,
            colors: [Color(0xFF2A0F45), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              children: [
                const Spacer(),
                const LogoBadge(size: 110)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                        begin: const Offset(0.7, 0.7),
                        curve: Curves.easeOutBack),
                const SizedBox(height: 22),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                    children: [
                      TextSpan(
                          text: 'TWIST ',
                          style: TextStyle(color: Colors.white)),
                      TextSpan(
                          text: 'BOT',
                          style: TextStyle(color: AppColors.pink)),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 14),
                const Text(
                  'احصل على وحدات اتصالات مجاناً\nمن خلال مهام Twist',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ).animate().fadeIn(delay: 350.ms),

                const SizedBox(height: 32),

                _Feature(icon: Icons.bolt_rounded, label: 'مهام تلقائية'),
                const SizedBox(height: 10),
                _Feature(icon: Icons.verified_user_rounded, label: 'آمن وسريع'),
                const SizedBox(height: 10),
                _Feature(icon: Icons.trending_up_rounded, label: 'زيادة الرصيد'),
                const SizedBox(height: 10),
                _Feature(
                    icon: Icons.card_giftcard_rounded, label: 'استبدال الوحدات'),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'ابدأ الآن',
                    icon: Icons.send_rounded,
                    onTap: _ready ? _start : null,
                    loading: !_ready,
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.pink.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.pink, size: 16),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.2, end: 0);
  }
}
