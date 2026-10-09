cat > ~/free_internet/lib/screens/report_screen.dart << 'EOF'
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
  List<Transaction> _allTx = [];
  String? _error;
  bool _showDebug = false;

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
        _allTx = txs;
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
      RegExp(r'(\d+)\s*Units?', caseSensitive: false),
      RegExp(r'(\d+)\s*وحدات'),
      RegExp(r'(\d+)\s*EAND', caseSensitive: false),
    ];
    for (final p in pats) {
      final m = p.firstMatch(desc);
      if (m != null) return int.tryParse(m.group(1) ?? '') ?? 0;
    }
    if (desc.contains('خصم') || desc.toLowerCase().contains('discount')) {
      return 0;
    }
    final nums = RegExp(r'\d+').allMatches(desc);
    if (nums.isNotEmpty) {
      final n = int.tryParse(nums.first.group(0) ?? '') ?? 0;
      if (n >= 50) return n;
    }
    return 0;
  }

  List<RedeemPackage> get _available {
    if (_remainingUnits <= 0) return [];
    return _allPackages
        .where((p) => p.cost <= _balance && p.units <= _remainingUnits)
        .toList();
  }

  // ============ نسبة الاستخدام ============
  double get _percentage =>
      (_monthlyUnits / AppConstants.monthlyUnitLimit).clamp(0.0, 1.0);

  // ============ الحالة ============
  _StatusType get _status {
    if (_remainingUnits <= 0) return _StatusType.full;
    if (_remainingUnits < 500) return _StatusType.low;
    return _StatusType.available;
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

    if (ok) {
      // نعرض رسالة نجاح + نحدّث البيانات
      messenger.showSnackBar(
        SnackBar(
          content: Text('✓ تم استبدال ${pkg.units} وحدة بنجاح!'),
          backgroundColor: AppColors.success,
        ),
      );
      await _load();

      // نعرض dialog فيه التقرير المحدث
      if (mounted) _showUpdatedReport(pkg);
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✗ فشل الاستبدال'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showUpdatedReport(RedeemPackage pkg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UpdatedReportSheet(
        unitsRedeemed: pkg.units,
        monthlyUnits: _monthlyUnits,
        remainingUnits: _remainingUnits,
        percentage: _percentage,
        status: _status,
      ),
    );
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
            icon: Icon(_showDebug
                ? Icons.bug_report_rounded
                : Icons.bug_report_outlined),
            color: _showDebug ? AppColors.pink : null,
            tooltip: 'عرض كل المعاملات',
            onPressed: () => setState(() => _showDebug = !_showDebug),
          ),
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

    if (_showDebug) return _buildDebug();

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

          const SizedBox(height: 16),

          // ============ 📊 تقرير السحوبات الشهرية ============
          Row(
            children: const [
              Icon(Icons.analytics_rounded, color: AppColors.pink, size: 20),
              SizedBox(width: 8),
              Text('تقرير السحوبات الشهرية',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),

          DarkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الصفوف
                _ReportRow(
                  label: 'الحد الشهري',
                  value: '${AppConstants.monthlyUnitLimit} وحدة',
                  valueColor: AppColors.warning,
                ),
                const SizedBox(height: 10),
                _ReportRow(
                  label: 'تم السحب',
                  value: '$_monthlyUnits وحدة',
                  valueColor: AppColors.danger,
                ),
                const SizedBox(height: 10),
                _ReportRow(
                  label: 'المتبقي',
                  value: '$_remainingUnits وحدة',
                  valueColor: AppColors.success,
                ),
                const SizedBox(height: 10),
                _ReportRow(
                  label: 'النسبة المستخدمة',
                  value: '${(_percentage * 100).toStringAsFixed(1)}%',
                  valueColor: AppColors.pink,
                ),

                const SizedBox(height: 16),

                // Progress bar + التقدم
                const Text('التقدم:',
                    style: TextStyle(
                        color: AppColors.textDim, fontSize: 12)),
                const SizedBox(height: 8),

                // Progress bar with dots
                _ProgressBarDots(progress: _percentage),

                const SizedBox(height: 16),

                // الحالة
                _StatusBox(
                  status: _status,
                  remainingUnits: _remainingUnits,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ============ 📊 الملخص النهائي ============
          Row(
            children: const [
              Icon(Icons.summarize_rounded, color: AppColors.pink, size: 20),
              SizedBox(width: 8),
              Text('الملخص النهائي',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),

          DarkCard(
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'الرصيد الحالي',
                  value: '$_balance كوينز',
                  valueColor: AppColors.success,
                ),
                const Divider(color: Colors.white10, height: 20),
                _SummaryRow(
                  icon: Icons.arrow_downward_rounded,
                  label: 'وحدات مسحوبة هذا الشهر',
                  value: '$_monthlyUnits وحدة',
                  valueColor: AppColors.danger,
                ),
                const Divider(color: Colors.white10, height: 20),
                _SummaryRow(
                  icon: Icons.hourglass_bottom_rounded,
                  label: 'الحد المتبقي',
                  value: '$_remainingUnits وحدة',
                  valueColor: AppColors.success,
                ),
                const Divider(color: Colors.white10, height: 20),
                _SummaryRow(
                  icon: Icons.info_rounded,
                  label: 'الحالة',
                  value: _status.label,
                  valueColor: _status.color,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ============ سجل السحوبات ============
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
                              Text(dateFmt.format(w.date),
                                  style: const TextStyle(
                                      color: AppColors.textMute,
                                      fontSize: 11)),
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

  Widget _buildDebug() {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final debits = _allTx.where((t) => t.direction == 'DEBIT').toList();
    debits.sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: const [
              Icon(Icons.bug_report_rounded,
                  color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'عرض خام لكل عمليات السحب — للتصحيح فقط',
                  style: TextStyle(
                      color: AppColors.warning, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('إجمالي السجلات: ${_allTx.length} | DEBIT: ${debits.length}',
            style: const TextStyle(color: AppColors.text, fontSize: 13)),
        const SizedBox(height: 12),
        ...debits.take(30).map((t) {
          final d = t.date == 0
              ? '-'
              : fmt.format(DateTime.fromMillisecondsSinceEpoch(t.date));
          final detected = _extract(t.description);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(d,
                        style: const TextStyle(
                            color: AppColors.textMute, fontSize: 10)),
                    const Spacer(),
                    Text('amount: ${t.amount}',
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 11)),
                    const SizedBox(width: 8),
                    Text('units: $detected',
                        style: TextStyle(
                            color: detected > 0
                                ? AppColors.success
                                : AppColors.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(t.description,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 12)),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

// ============ Status ============
enum _StatusType { available, low, full }

extension on _StatusType {
  Color get color {
    switch (this) {
      case _StatusType.full:
        return AppColors.danger;
      case _StatusType.low:
        return AppColors.warning;
      case _StatusType.available:
        return AppColors.success;
    }
  }

  String get label {
    switch (this) {
      case _StatusType.full:
        return 'وصلت للحد ⛔';
      case _StatusType.low:
        return 'قاربت على الانتهاء ⚠️';
      case _StatusType.available:
        return 'متاح ✅';
    }
  }

  String get message {
    switch (this) {
      case _StatusType.full:
        return 'لقد وصلت للحد الشهري! (2000 وحدة)';
      case _StatusType.low:
        return 'تبقى أقل من 500 وحدة!';
      case _StatusType.available:
        return 'الحد متاح للسحب';
    }
  }
}

// ============ تقرير - صف ============
class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _ReportRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textDim, fontSize: 13)),
        ),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ============ Progress bar with dots ============
class _ProgressBarDots extends StatelessWidget {
  final double progress;
  const _ProgressBarDots({required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final barWidth = constraints.maxWidth;
      final filledWidth = barWidth * progress;

      return Stack(
        children: [
          // الخلفية
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.cardAlt,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          // الممتلئ
          Container(
            height: 12,
            width: filledWidth,
            decoration: BoxDecoration(
              gradient: AppColors.pinkGradient,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pink.withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

// ============ Status box ============
class _StatusBox extends StatelessWidget {
  final _StatusType status;
  final int remainingUnits;
  const _StatusBox({required this.status, required this.remainingUnits});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == _StatusType.full
                    ? Icons.block_rounded
                    : status == _StatusType.low
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                color: status.color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.message,
                  style: TextStyle(
                      color: status.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (status != _StatusType.full && remainingUnits > 0) ...[
            const SizedBox(height: 6),
            Text(
              'ℹ️  يمكنك سحب $remainingUnits وحدة هذا الشهر',
              style: const TextStyle(
                  color: AppColors.textDim, fontSize: 12),
            ),
          ],
          if (status == _StatusType.full) ...[
            const SizedBox(height: 6),
            const Text(
              '❌ لا يمكنك سحب المزيد حتى الشهر القادم',
              style: TextStyle(color: AppColors.textDim, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ============ Summary row ============
class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: valueColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textDim, fontSize: 13)),
        ),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ============ Bottom sheet: التقرير المحدث بعد الاستبدال ============
class _UpdatedReportSheet extends StatelessWidget {
  final int unitsRedeemed;
  final int monthlyUnits;
  final int remainingUnits;
  final double percentage;
  final _StatusType status;

  const _UpdatedReportSheet({
    required this.unitsRedeemed,
    required this.monthlyUnits,
    required this.remainingUnits,
    required this.percentage,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.textMute,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 20),

          // أيقونة النجاح
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: AppColors.pinkGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.pink.withOpacity(0.5),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),

          Text('تم استبدال $unitsRedeemed وحدة',
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),

          const SizedBox(height: 24),

          // التقرير المحدث
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_rounded,
                        color: AppColors.pink, size: 18),
                    SizedBox(width: 8),
                    Text('التقرير المحدث',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 14),
                _ReportRow(
                  label: 'الحد الشهري',
                  value: '${AppConstants.monthlyUnitLimit} وحدة',
                  valueColor: AppColors.warning,
                ),
                const SizedBox(height: 10),
                _ReportRow(
                  label: 'تم السحب',
                  value: '$monthlyUnits وحدة',
                  valueColor: AppColors.danger,
                ),
                const SizedBox(height: 10),
                _ReportRow(
                  label: 'المتبقي',
                  value: '$remainingUnits وحدة',
                  valueColor: AppColors.success,
                ),
                const SizedBox(height: 14),
                _ProgressBarDots(progress: percentage),
                const SizedBox(height: 14),
                _StatusBox(
                    status: status, remainingUnits: remainingUnits),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: 'تمام',
              icon: Icons.check_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ============ Helpers ============
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
EOF