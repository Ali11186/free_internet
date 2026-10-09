import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/vpn_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class VpnBlockScreen extends StatefulWidget {
  const VpnBlockScreen({super.key});
  @override
  State<VpnBlockScreen> createState() => _VpnBlockScreenState();
}

class _VpnBlockScreenState extends State<VpnBlockScreen> {
  bool _checking = false;

  Future<void> _recheck() async {
    setState(() => _checking = true);
    final blocked = await VpnService.shouldBlock();
    if (!mounted) return;
    setState(() => _checking = false);

    if (blocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ لا تزال الحماية تكتشف VPN — أوقفه أولاً'),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope يمنع الرجوع لوراء (زر back)
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.4,
              colors: [Color(0xFF3D1568), AppColors.bg],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB71C1C), Color(0xFF6A1B9A)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withOpacity(0.6),
                          blurRadius: 40,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: Colors.white, size: 70),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.08, 1.08),
                        duration: 900.ms,
                      ),

                  const SizedBox(height: 32),

                  const Text(
                    '🚫 الحماية نشطة',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 8),

                  const Text(
                    'تم كشف VPN',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 20),

                  const Text(
                    'لا يمكن استخدام التطبيق أثناء تشغيل VPN.\nأوقف الـ VPN ثم اضغط "إعادة المحاولة".',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textDim,
                      fontSize: 15,
                      height: 1.8,
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: const [
                        _InfoLine(
                          icon: Icons.security_rounded,
                          text: 'فحص متعدد الطبقات للشبكة',
                        ),
                        SizedBox(height: 10),
                        _InfoLine(
                          icon: Icons.sync_rounded,
                          text: 'مراقبة مستمرة كل 5 ثواني',
                        ),
                        SizedBox(height: 10),
                        _InfoLine(
                          icon: Icons.public_rounded,
                          text: 'تحقق من سمعة الـ IP',
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 450.ms),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      label: _checking ? 'جاري التحقق...' : 'إعادة المحاولة',
                      icon: Icons.refresh_rounded,
                      loading: _checking,
                      onTap: _recheck,
                    ),
                  ).animate().fadeIn(delay: 550.ms),

                  const SizedBox(height: 14),

                  const Text(
                    'الحماية تعمل تلقائياً — أعد المحاولة بعد إيقاف VPN',
                    style: TextStyle(color: AppColors.textMute, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.danger, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
        ),
      ],
    );
  }
}
