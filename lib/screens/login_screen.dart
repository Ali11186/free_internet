import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  int _step = 0;
  bool _loading = false;
  String? _error;
  String _phone = '';
  int _otpAttempts = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _formatPhone(String raw) {
    final s = raw.trim();
    if (s.startsWith('01')) return '2$s';
    if (s.startsWith('+2')) return s.substring(1);
    return s.replaceAll('+', '').replaceAll(' ', '');
  }

  Future<void> _sendOtp() async {
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'أدخل رقم الهاتف');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _phone = _formatPhone(raw);
    final ok = await ApiService.sendOtp(_phone);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ok) {
        _step = 1;
        _otpAttempts = 0;
      } else {
        _error = 'فشل إرسال الرمز. تأكد من الرقم.';
      }
    });
  }

  Future<void> _verifyOtp() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'أدخل رمز التحقق');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final headers = await ApiService.verifyOtp(_phone, code);
    if (!mounted) return;
    if (headers == null) {
      _otpAttempts++;
      setState(() {
        _loading = false;
        if (_otpAttempts >= 3) {
          _error = 'انتهت المحاولات. أعد الإرسال.';
          _step = 0;
        } else {
          _error = 'رمز غير صحيح ($_otpAttempts/3)';
        }
      });
      return;
    }
    final acc = Account(phone: _phone, headers: headers, lastUsed: DateTime.now());
    await context.read<AppProvider>().setAccount(acc);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LogoBadge(size: 80),
                const SizedBox(height: 18),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1),
                    children: [
                      TextSpan(
                          text: 'TWIST ',
                          style: TextStyle(color: Colors.white)),
                      TextSpan(
                          text: 'BOT',
                          style: TextStyle(color: AppColors.pink)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                if (_step == 0) ...[
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2),
                    decoration: const InputDecoration(
                      hintText: '01xxxxxxxxx',
                      prefixIcon:
                          Icon(Icons.phone_android_rounded, color: AppColors.pink),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'إرسال رمز التحقق',
                    icon: Icons.send_rounded,
                    loading: _loading,
                    onTap: _sendOtp,
                  ),
                ] else ...[
                  Text('تم إرسال الرمز إلى +$_phone',
                      style: const TextStyle(color: AppColors.textDim)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 26,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '● ● ● ● ● ●',
                    ),
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    label: 'تأكيد',
                    icon: Icons.check_rounded,
                    loading: _loading,
                    onTap: _verifyOtp,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _step = 0;
                              _otpAttempts = 0;
                              _codeCtrl.clear();
                            });
                          },
                    child: const Text('تغيير الرقم / إعادة الإرسال',
                        style: TextStyle(color: AppColors.pink)),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.danger.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.danger))),
                      ],
                    ),
                  ).animate().fadeIn().shake(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
