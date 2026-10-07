import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'report_screen.dart';

class CollectScreen extends StatefulWidget {
  const CollectScreen({super.key});
  @override
  State<CollectScreen> createState() => _CollectScreenState();
}

class _CollectScreenState extends State<CollectScreen> {
  bool _running = false;
  bool _done = false;
  int _currentIndex = 0;
  String _currentTitle = '';
  int _earned = 0;
  CollectResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _done = false;
      _currentIndex = 0;
      _currentTitle = '';
      _earned = 0;
      _result = null;
    });

    final p = context.read<AppProvider>();
    final res = await p.runCollect();

    if (!mounted) return;
    setState(() {
      _running = false;
      _done = true;
      _result = res;
      _earned = res.coins;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final total = p.currentTasks.isEmpty
        ? (_result?.tasks.length ?? 0)
        : p.currentTasks.length;
    final current = _running ? p.currentTaskIndex + 1 : total;
    final progress = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('تنفيذ المهام',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [Color(0xFF2A0F45), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ============ عنوان ============
                DarkCard(
                  gradient: AppColors.purpleGlow,
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('تنفيذ المهام',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900)),
                            SizedBox(height: 4),
                            Text(
                              'سيتم تنفيذ جميع المهام تلقائياً للحصول على أكبر عدد من النقاط',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ============ شريط التقدم ============
                DarkCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _running
                                  ? 'جاري تنفيذ المهام...'
                                  : (_done ? 'انتهى التنفيذ' : 'بالانتظار...'),
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                                color: AppColors.pink,
                                fontWeight: FontWeight.w800,
                                fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.cardAlt,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: AppColors.pinkGradient,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.pink.withOpacity(0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ============ قائمة المهام ============
                Expanded(
                  child: DarkCard(
                    padding: const EdgeInsets.all(8),
                    child: _buildTaskList(p),
                  ),
                ),

                const SizedBox(height: 16),

                // ============ الإحصائيات ============
                if (_done && _result != null) ...[
                  Row(
                    children: [
                      Expanded(
                          child: _StatBox(
                        value: '${_result!.tasks.where((t) => t.status == TaskStatus.success || t.status == TaskStatus.alreadyDone).length}',
                        label: 'المهام المكتملة',
                        color: AppColors.success,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _StatBox(
                        value: '${_result!.tasks.length}',
                        label: 'إجمالي المهام',
                        color: AppColors.pink,
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _StatBox(
                        value: '+$_earned',
                        label: 'النقاط المكتسبة',
                        color: AppColors.gold,
                      )),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // ============ زر ============
                if (_running)
                  GradientButton(
                    label: 'إيقاف التنفيذ',
                    icon: Icons.stop_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB71C1C), Color(0xFF6A1B9A)],
                    ),
                    onTap: () => Navigator.pop(context),
                  )
                else if (_done)
                  GradientButton(
                    label: 'عرض تقرير الوحدات',
                    icon: Icons.bar_chart_rounded,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportScreen()),
                      );
                    },
                  )
                else
                  GradientButton(
                    label: 'ابدأ التنفيذ',
                    icon: Icons.rocket_launch_rounded,
                    onTap: _start,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(AppProvider p) {
    // المهام من provider
    final liveTasks = p.currentTasks;

    if (liveTasks.isEmpty && _result == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.pink),
        ),
      );
    }

    // لو انتهى التنفيذ، نعرض النتائج
    if (_result != null) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _result!.tasks.length,
        separatorBuilder: (_, __) => Divider(
          color: Colors.white.withOpacity(0.05),
          height: 1,
        ),
        itemBuilder: (context, i) {
          final r = _result!.tasks[i];
          IconData trailingIcon;
          Color color;
          switch (r.status) {
            case TaskStatus.success:
              trailingIcon = Icons.check_circle_rounded;
              color = AppColors.success;
              break;
            case TaskStatus.alreadyDone:
              trailingIcon = Icons.check_circle_rounded;
              color = AppColors.success;
              break;
            case TaskStatus.forbidden:
              trailingIcon = Icons.cancel_rounded;
              color = AppColors.danger;
              break;
            case TaskStatus.failed:
              trailingIcon = Icons.error_rounded;
              color = AppColors.warning;
              break;
          }
          return ListTile(
            leading: const Icon(Icons.music_note_rounded,
                color: AppColors.pink, size: 20),
            title: Text(r.task.title,
                style: const TextStyle(
                    color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
            trailing: Icon(trailingIcon, color: color, size: 22),
          );
        },
      );
    }

    // عرض أثناء التنفيذ
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: liveTasks.length,
      separatorBuilder: (_, __) => Divider(
        color: Colors.white.withOpacity(0.05),
        height: 1,
      ),
      itemBuilder: (context, i) {
        final t = liveTasks[i];
        final isDone = t.rewarded;
        final isCurrent = _running && i == p.currentTaskIndex;

        return ListTile(
          leading: Icon(
            Icons.music_note_rounded,
            color: isDone ? AppColors.success : AppColors.pink,
            size: 20,
          ),
          title: Text(t.title,
              style: TextStyle(
                color: isDone ? AppColors.textDim : AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
          trailing: isDone
              ? const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 22)
              : isCurrent
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.pink),
                    )
                  : const Icon(Icons.access_time_rounded,
                      color: AppColors.textMute, size: 20),
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DarkCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textDim, fontSize: 10, height: 1.3)),
        ],
      ),
    );
  }
}
