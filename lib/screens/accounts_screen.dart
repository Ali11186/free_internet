import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  Future<void> _select(BuildContext context, Account acc) async {
    final p = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.pink)),
    );
    final valid = await p.validateSession(acc);
    if (!context.mounted) return;
    Navigator.pop(context);
    if (valid) {
      await p.setAccount(acc);
      if (!context.mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('انتهت الجلسة — أعد تسجيل الدخول'),
            backgroundColor: AppColors.warning),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AppProvider>().accounts;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('اختر الحساب')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [Color(0xFF2A0F45), AppColors.bg],
          ),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: accounts.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == accounts.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GradientButton(
                  label: 'إضافة رقم جديد',
                  icon: Icons.add_rounded,
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()));
                  },
                ),
              );
            }
            final acc = accounts[i];
            return DarkCard(
              onTap: () => _select(context, acc),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: AppColors.pinkGradient,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.person_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('+${acc.phone}',
                            style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(_fmt(acc.lastUsed),
                            style: const TextStyle(
                                color: AppColors.textDim, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: AppColors.textDim),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}
