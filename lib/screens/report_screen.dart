import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  List<RedeemPackage> _allPackages = [];
  List<_WithdrawItem> _monthlyWithdrawals = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final p = context.read<AppProvider>();
      final acc = p.currentAccount;
      if (acc == null) {
        setState(() {
          _loading = false;
          _error = 'الحساب غير متاح';
        });
        return;
      }

      final results = await Future.wait([
        ApiService.getBalance(acc.headers),
        ApiService.getHistory(acc.headers),
        ApiService.getPackages(acc.headers),
      ]).timeout(const Duration(seconds: 25));

      final balance = results[0] as int;
      final txs = results[1] as List<Transaction>;
      final packages = results[2] as List<RedeemPackage>;

      // نستخرج كل السحوبات الشهرية
      final withdrawals = _extractMonthlyWithdrawals(txs);
      final units = withdrawals.fold<int>(0, (sum, w) => sum + w.units);
      final remaining = (AppConstants.monthlyUnitLimit - units)
          .clamp(0, AppConstants.monthlyUnitLimit);

      if (!mounted) return;
      setState(() {
        _balance = balance;
        _monthlyUnits = units;
        _remainingUnits = remaining;
        _allPackages = packages;
        _monthlyWithdrawals = withdrawals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'فشل تحميل البيانات، حاول مرة أخرى';
      });
    }
  }

  List<_WithdrawItem> _extractMonthlyWithdrawals(List<Transaction> txs) {
    final now = DateTime.now();
    final result = <_WithdrawItem>[];
    for (final t in txs) {
      if (t.date == 0) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      if (d.year == now.year && d.month == now.month) {
        if (t.direction == 'DEBIT' && t.amount > 0) {
          final u = _extract(t.description);
          if (u > 0) {
            result.add(_WithdrawItem(
              date: d,
              units: u,
              description: t.description,
              coins: t.amount,
            ));
          }
        }
      }
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
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

  List<RedeemPackage> get _available {
    if (_remainingUnits <= 0) return [];
    return _allPackages
        .where((p) => p.cost <= _balance && p.units <= _remainingUnits)
        .toList();
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
                style: TextStyle(color: AppColors.textDim)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('استبدال'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

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
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
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
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.pink),
            SizedBox(height: 16),
            Text('جاري تحميل البيانات...',
                style: TextStyle(color: AppColors.textDim)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 60),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.text, fontSize: 16)),
              const SizedBox(height: 20),
              GradientButton(
                label: 'إعادة المحاولة',
                icon: Icons.refresh_rounded,
                onTap: _load,
              ),
            ],
          ),
        ),
      );
    }

    final available = _available;
    final dateFmt = DateFormat('dd/MM/yyyy - HH:mm');

    return RefreshIndicator(
      color: AppColors.pink,
      backgroundColor: AppColors.card,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ============ البانر ============
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
                      Text('حول نقاطك إلى وحدات اتصالات بسهولة',
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
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.pink),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ============ سجل السحوبات الشهرية ============
          Row(
            children: [
              const Icon(Icons.history_rounded,
                  color: AppColors.pink, size: 20),
              const SizedBox(width: 8),
              const Text('سجل السحوبات هذا الشهر',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.pink.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_monthlyWithdrawals.length}',
                    style: const TextStyle(
                        color: AppColors.pink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_monthlyWithdrawals.isEmpty)
            DarkCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: const [
                    Icon(Icons.inbox_rounded,
                        color: AppColors.textMute, size: 40),
                    SizedBox(height: 10),
                    Text('لا توجد سحوبات هذا الشهر بعد',
                        style: TextStyle(
                            color: AppColors.textDim, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ..._monthlyWithdrawals.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DarkCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_upward_rounded,
                              color: AppColors.warning, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('-${w.units} وحدة',
                                  style: const TextStyle(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                dateFmt.format(w.date),
                                style: const TextStyle(
                                    color: AppColors.textMute, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('-${w.coins}',
                              style: const TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                )),

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
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            )
          else if (available.isEmpty)
            DarkCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.warning, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _balance < 100
                          ? 'الرصيد أقل من 100 كوينز — اجمع المزيد أولاً'
                          : 'لا توجد باقات مناسبة للحد المتبقي ($_remainingUnits وحدة)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              children: const [
                Icon(Icons.sim_card_rounded,
                    color: AppColors.pink, size: 20),
                SizedBox(width: 8),
                Text('الباقات المتاحة',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            ...available.map((p) => Padding(
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                  borderRadius: BorderRadius.circular(12)),
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

          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
            label: const Text('العودة للقائمة الرئيسية',
                style: TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.white.withOpacity(0.15)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
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

class _WithdrawItem {
  final DateTime date;
  final int units;
  final String description;
  final int coins;
  _WithdrawItem({
    required this.date,
    required this.units,
    required this.description,
    required this.coins,
  });
}
