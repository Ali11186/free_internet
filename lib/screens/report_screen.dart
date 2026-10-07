import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/common.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _loading = true;
  int _balance = 0;
  int _monthlyUnits = 0;
  int _remainingUnits = 0;
  List<RedeemPackage> _packages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = context.read<AppProvider>();
    final acc = p.currentAccount;
    if (acc == null) return;

    setState(() => _loading = true);
    final balance = await ApiService.getBalance(acc.headers);
    final txs = await ApiService.getHistory(acc.headers);
    final units = _calc(txs);
    final packages = await ApiService.getPackages(acc.headers);

    if (!mounted) return;
    setState(() {
      _balance = balance;
      _monthlyUnits = units;
      _remainingUnits = AppConstants.monthlyUnitLimit - units;
      if (_remainingUnits < 0) _remainingUnits = 0;
      _packages = packages
          .where((p) => p.cost <= balance && p.units <= _remainingUnits)
          .toList();
      _loading = false;
    });
  }

  int _calc(List<Transaction> txs) {
    final now = DateTime.now();
    int total = 0;
    for (final t in txs) {
      if (t.date == 0) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      if (d.year == now.year && d.month == now.month) {
        if (t.direction == 'DEBIT' && t.amount > 0) {
          final u = _extract(t.description);
          if (u > 0) total += u;
        }
      }
    }
    return total;
  }

  int _extract(String desc) {
    final pats = [
      RegExp(r'(\d+)\s*وحدة\s*e&'),
      RegExp(r'(\d+)\s*وحده\s*e&'),
      RegExp(r'(\d+)\s*وحدة'),
      RegExp(r'(\d+)\s*وحده'),
      RegExp(r'(\d+)\s*Units?'),
      RegExp(r'(\d+)\s*وحدات'),
      RegExp(r'(\d+)\s*EAND'),
    ];
    for (final p in pats) {
      final m = p.firstMatch(desc);
      if (m != null) return int.tryParse(m.group(1) ?? '') ?? 0;
    }
    return 0;
  }

  Future<void> _redeem(RedeemPackage pkg) async {
    final acc = context.read<AppProvider>().currentAccount;
    if (acc == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('تأكيد الاستبدال'),
        content: Text('سحب ${pkg.units} وحدة مقابل ${pkg.cost} كوينز؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppColors.textDim))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('استبدال')),
        ],
      ),
    );
    if (confirm != true) return;

    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.pink)),
    );
    final ok = await ApiService.redeem(acc.headers, pkg.code);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'تم الاستبدال بنجاح ✓' : 'فشل الاستبدال ✗'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('استبدال الوحدات',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [Color(0xFF2A0F45), AppColors.bg],
          ),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.pink))
            : RefreshIndicator(
                color: AppColors.pink,
                backgroundColor: AppColors.card,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ============ بانر ============
                    DarkCard(
                      gradient: AppColors.pinkPurpleGradient,
                      child: Row(
                        children: [
                          const Icon(Icons.card_giftcard_rounded,
                              color: Colors.white, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('استبدال الوحدات',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900)),
                                SizedBox(height: 4),
                                Text(
                                    'حول نقاطك إلى وحدات اتصالات بسهولة وسرعة',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ============ الرصيد ============
                    DarkCard(
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on_rounded,
                              color: AppColors.gold, size: 40),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('رصيدك الحالي',
                                  style: TextStyle(
                                      color: AppColors.textDim, fontSize: 12)),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text('$_balance',
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ============ ملخص الشهر ============
                    DarkCard(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _Stat(
                                  label: 'الحد الشهري',
                                  value: '${AppConstants.monthlyUnitLimit}',
                                  color: AppColors.pink),
                              _Stat(
                                  label: 'تم السحب',
                                  value: '$_monthlyUnits',
                                  color: AppColors.warning),
                              _Stat(
                                  label: 'المتبقي',
                                  value: '$_remainingUnits',
                                  color: AppColors.success),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _monthlyUnits / AppConstants.monthlyUnitLimit,
                              minHeight: 8,
                              backgroundColor: AppColors.cardAlt,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.pink),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ============ الباقات ============
                    if (_remainingUnits <= 0)
                      DarkCard(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB71C1C), Color(0xFF6A1B9A)],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            '⚠ وصلت للحد الشهري! لا يمكنك السحب حتى الشهر القادم.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                    else if (_packages.isEmpty)
                      const DarkCard(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'لا توجد باقات متاحة للرصيد أو الحد الحالي.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textDim),
                          ),
                        ),
                      )
                    else ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('الباقات المتاحة',
                            style: TextStyle(
                                color: AppColors.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 10),
                      ..._packages.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DarkCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.pinkGradient,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.sim_card_rounded,
                                        color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('${p.units} وحدة',
                                            style: const TextStyle(
                                                color: AppColors.text,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons.monetization_on_rounded,
                                                color: AppColors.gold,
                                                size: 14),
                                            const SizedBox(width: 4),
                                            Text('${p.cost} نقطة',
                                                style: const TextStyle(
                                                    color: AppColors.textDim,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed: () => _redeem(p),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.pink,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        elevation: 0,
                                      ),
                                      child: const Text('استبدال',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],

                    const SizedBox(height: 20),

                    // ============ العودة ============
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.text),
                      label: const Text('العودة للقائمة الرئيسية',
                          style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                            color: Colors.white.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
      ],
    );
  }
}
