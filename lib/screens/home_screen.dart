import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';
import 'collect_screen.dart';
import 'report_screen.dart';
import 'accounts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadBalance();
    });
  }

  Future<void> _openWebsite() async {
    final uri = Uri.parse(AppConstants.websiteUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الرابط:\n${AppConstants.websiteUrl}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final phone = p.currentAccount?.phone ?? '';
    final balance = p.balance;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [Color(0xFF2A0F45), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.pink,
            backgroundColor: AppColors.card,
            onRefresh: () async {
              await p.loadBalance();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              children: [
                // ============ الهيدر ============
                Row(
                  children: [
                    const LogoBadge(size: 44),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TWIST BOT',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              )),
                          SizedBox(height: 2),
                          Text('bot',
                              style: TextStyle(
                                color: AppColors.pink,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await p.logout();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AccountsScreen()),
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.logout_rounded,
                          color: AppColors.textDim),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ============ بانر الترحيب ============
                DarkCard(
                  padding: EdgeInsets.zero,
                  gradient: AppColors.pinkPurpleGradient,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'TWIST ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'BOT',
                                      style: TextStyle(
                                        color: Color(0xFFFFD54F),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'قم بتنفيذ المهام واحصل على\nوحدات اتصالات مجاناً',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.music_note_rounded,
                            color: Colors.white54, size: 70),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ============ كارت الحساب ============
                DarkCard(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.pinkGradient,
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('مرحباً بك',
                                style: TextStyle(
                                    color: AppColors.textDim, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('+$phone',
                                style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            CircleAvatar(
                                radius: 4,
                                backgroundColor: AppColors.success),
                            SizedBox(width: 6),
                            Text('متصل',
                                style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ============ كارت الرصيد ============
                DarkCard(
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on_rounded,
                          color: AppColors.gold, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('رصيد النقاط الحالي',
                                style: TextStyle(
                                    color: AppColors.textDim, fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('$balance',
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    )),
                                const SizedBox(width: 6),
                                const Icon(Icons.circle,
                                    color: AppColors.gold, size: 14),
                              ],
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => p.loadBalance(),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppColors.cardAlt,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.refresh_rounded,
                              color: AppColors.pink, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ============ الأزرار الكبيرة ============
                Row(
                  children: [
                    Expanded(
                      child: DarkCard(
                        gradient: AppColors.pinkGradient,
                        padding: const EdgeInsets.symmetric(
                            vertical: 22, horizontal: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CollectScreen()),
                          );
                        },
                        child: Column(
                          children: const [
                            Icon(Icons.rocket_launch_rounded,
                                color: Colors.white, size: 34),
                            SizedBox(height: 10),
                            Text('تنفيذ المهام',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                            SizedBox(height: 4),
                            Text('احصل على نقاط الآن',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DarkCard(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2FF7), Color(0xFF3D1568)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 22, horizontal: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ReportScreen()),
                          );
                        },
                        child: Column(
                          children: const [
                            Icon(Icons.card_giftcard_rounded,
                                color: Colors.white, size: 34),
                            SizedBox(height: 10),
                            Text('استبدال الوحدات',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                            SizedBox(height: 4),
                            Text('حول النقاط إلى وحدات',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ============ شبكة القائمة ============
                Row(
                  children: [
                    Expanded(
                      child: _MiniTile(
                        icon: Icons.person_rounded,
                        label: 'صفحة الحساب',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AccountsScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniTile(
                        icon: Icons.emoji_events_rounded,
                        label: 'الإنجازات',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CollectScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniTile(
                        icon: Icons.help_outline_rounded,
                        label: 'المساعدة',
                        onTap: _openWebsite,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniTile(
                        icon: Icons.info_outline_rounded,
                        label: 'حول البوت',
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Free Internet',
                            applicationVersion: 'v1.0.0',
                            children: const [
                              Text(
                                  'أداة لجمع النقاط واستبدال الوحدات من Twist Music.',
                                  style:
                                      TextStyle(color: AppColors.textDim)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MiniTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DarkCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.pink.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.pink, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
