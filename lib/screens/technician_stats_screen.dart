import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/user_account_model.dart';
import '../utils/ui_helpers.dart';
import '../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

class TechnicianStatsScreen extends StatefulWidget {
  final UserAccountModel user;
  const TechnicianStatsScreen({super.key, required this.user});

  @override
  State<TechnicianStatsScreen> createState() => _TechnicianStatsScreenState();
}

class _TechnicianStatsScreenState extends State<TechnicianStatsScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة (State Definitions)
  // ===========================================================================

  bool _isLoading = true;

  // Overall Stats
  int _totalTasks = 0;
  int _totalDevices = 0;

  // Time-based Stats
  int _weeklyTasks = 0;
  int _monthlyTasks = 0;
  int _yearlyTasks = 0;
  int _weeklyDevices = 0;
  int _monthlyDevices = 0;
  int _yearlyDevices = 0;

  // Chart Data
  List<BarChartGroupData> _weeklyChartData = [];

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle) - (أساسي)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method) - (أساسي)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('ملخص الأداء'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CustomLoadingIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 24),
                  _buildSummaryGrid(theme),
                  const SizedBox(height: 24),
                  _buildChartSection(theme),
                  const SizedBox(height: 24),
                  _buildTimeBasedStats(theme),
                ],
              ),
            ),
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي (Core Business Logic) - (أساسي)
  // ===========================================================================

  /// دالة لجلب ومعالجة جميع الإحصائيات من قاعدة البيانات.
  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final startOfWeek =
        now.subtract(Duration(days: now.weekday % 7)); // Sunday as start
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfYear = DateTime(now.year, 1, 1);
    final firestore = FirebaseFirestore.instance;

    try {
      final tasksSnapshot = await firestore
          .collection('user_tasks')
          .where('userId', isEqualTo: widget.user.uid)
          .where('isCompleted', isEqualTo: true)
          .get();

      final devicesSnapshot = await firestore
          .collection('devices')
          .where('createdBy', isEqualTo: widget.user.uid)
          .get();

      // --- Process Tasks ---
      int tempWeeklyTasks = 0;
      int tempMonthlyTasks = 0;
      int tempYearlyTasks = 0;
      List<int> weeklyTaskCounts = List.filled(7, 0); // Sun, Mon, ..., Sat

      for (var doc in tasksSnapshot.docs) {
        final completedAt = (doc.data()['completedAt'] as Timestamp?)?.toDate();
        if (completedAt == null) continue;

        if (completedAt.isAfter(startOfWeek)) {
          tempWeeklyTasks++;
          int dayIndex = completedAt.weekday % 7;
          weeklyTaskCounts[dayIndex]++;
        }
        if (completedAt.isAfter(startOfMonth)) tempMonthlyTasks++;
        if (completedAt.isAfter(startOfYear)) tempYearlyTasks++;
      }

      // --- Process Devices ---
      int tempWeeklyDevices = 0;
      int tempMonthlyDevices = 0;
      int tempYearlyDevices = 0;

      for (var doc in devicesSnapshot.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null) continue;

        if (createdAt.isAfter(startOfWeek)) tempWeeklyDevices++;
        if (createdAt.isAfter(startOfMonth)) tempMonthlyDevices++;
        if (createdAt.isAfter(startOfYear)) tempYearlyDevices++;
      }

      // --- Update State ---
      if (mounted) {
        setState(() {
          _totalTasks = tasksSnapshot.size;
          _totalDevices = devicesSnapshot.size;
          _weeklyTasks = tempWeeklyTasks;
          _monthlyTasks = tempMonthlyTasks;
          _yearlyTasks = tempYearlyTasks;
          _weeklyDevices = tempWeeklyDevices;
          _monthlyDevices = tempMonthlyDevices;
          _yearlyDevices = tempYearlyDevices;
          _weeklyChartData = _generateChartData(weeklyTaskCounts);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'فشل تحميل الإحصائيات: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  // ===========================================================================
  // 5. دوال بناء مكونات الواجهة والبيانات المساعدة (UI & Data Helpers)
  // ===========================================================================

  /// دالة لتوليد بيانات الرسم البياني الأسبوعي.
  List<BarChartGroupData> _generateChartData(List<int> dailyCounts) {
    return List.generate(7, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: dailyCounts[index].toDouble(),
            color: Theme.of(context).primaryColor,
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    });
  }

  /// ويدجت لبناء ترويسة الشاشة التي تعرض معلومات المستخدم.
  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor: theme.colorScheme.primary.withAlpha(51),
          child: Text(
            widget.user.fullName.isNotEmpty ? widget.user.fullName[0] : 'U',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user.fullName,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'فني صيانة',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ويدجت لبناء شبكة عرض الإحصائيات الإجمالية.
  Widget _buildSummaryGrid(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          title: 'إجمالي المهام',
          value: _totalTasks.toString(),
          icon: Icons.task_alt,
          color: Colors.orange,
          theme: theme,
        ),
        _buildStatCard(
          title: 'إجمالي الأجهزة',
          value: _totalDevices.toString(),
          icon: Icons.devices_other,
          color: Colors.blue,
          theme: theme,
        ),
        _buildStatCard(
          title: 'النقاط المكتسبة',
          value: widget.user.points.toString(),
          icon: Icons.star,
          color: Colors.amber,
          theme: theme,
        ),
        _buildStatCard(
          title: 'مهام الشهر',
          value: _monthlyTasks.toString(),
          icon: Icons.calendar_month,
          color: Colors.green,
          theme: theme,
        ),
      ],
    );
  }

  /// ويدجت مساعد لبناء بطاقة إحصائية واحدة.
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(230),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withAlpha(38),
            child: Icon(icon, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ويدجت لبناء قسم الرسم البياني.
  Widget _buildChartSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإنتاجية الأسبوعية (مهام)',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(25),
                spreadRadius: 1,
                blurRadius: 10,
              ),
            ],
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (_weeklyChartData
                          .map((d) => d.barRods.first.toY)
                          .reduce((a, b) => a > b ? a : b) *
                      1.2)
                  .clamp(5, double.infinity),
              barGroups: _weeklyChartData,
              titlesData: FlTitlesData(
                show: true,
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const style = TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12);
                      List<String> days = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        child: Text(days[value.toInt()], style: style),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value % 2 != 0) {
                        return const Text('');
                      }
                      return Text(
                        value.toInt().toString(),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.left,
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withAlpha(51),
                  strokeWidth: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ويدجت لبناء قسم الإحصائيات الزمنية (أسبوعي، شهري، سنوي).
  Widget _buildTimeBasedStats(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إحصائيات تفصيلية',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildTimeStatRow('هذا الأسبوع', _weeklyTasks, _weeklyDevices, theme),
        const Divider(height: 24),
        _buildTimeStatRow('هذا الشهر', _monthlyTasks, _monthlyDevices, theme),
        const Divider(height: 24),
        _buildTimeStatRow('هذه السنة', _yearlyTasks, _yearlyDevices, theme),
      ],
    );
  }

  /// ويدجت مساعد لبناء صف واحد في قسم الإحصائيات الزمنية.
  Widget _buildTimeStatRow(
      String label, int tasks, int devices, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        Row(
          children: [
            const Icon(Icons.task_alt, color: Colors.grey, size: 18),
            const SizedBox(width: 4),
            Text(tasks.toString(), style: theme.textTheme.titleMedium),
            const SizedBox(width: 16),
            const Icon(Icons.devices, color: Colors.grey, size: 18),
            const SizedBox(width: 4),
            Text(devices.toString(), style: theme.textTheme.titleMedium),
          ],
        ),
      ],
    );
  }
}
