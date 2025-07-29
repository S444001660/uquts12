import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/permissions_service.dart';
import '../../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  bool _isLoading = true;
  String? _error;

  // Data holders
  Map<String, dynamic> _generalStats = {};
  Map<String, int> _devicesByCollege = {};
  Map<String, int> _labsByStatus = {};
  Map<String, int> _devicesByTimePeriod = {};
  List<Map<String, dynamic>> _topEmployees = [];
  List<Map<String, dynamic>> _recentActivities = [];

  // Controllers and filters
  late TabController _tabController;
  String _selectedTimeFilter = 'month';
  final TextEditingController _employeeSearchController =
      TextEditingController();
  // ignore: prefer_final_fields
  String _selectedRoleFilter = 'all';

  // Pre-fetched data to avoid multiple reads
  List<QueryDocumentSnapshot>? _deviceDocs;
  List<QueryDocumentSnapshot>? _labDocs;
  List<QueryDocumentSnapshot>? _userDocs;

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // إضافة مستمع لتحديث الواجهة عند الكتابة في حقل البحث
    _employeeSearchController.addListener(() => setState(() {}));
    _initializeScreen();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _employeeSearchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'نظرة عامة'),
            Tab(icon: Icon(Icons.bar_chart), text: 'الرسوم البيانية'),
            Tab(icon: Icon(Icons.people), text: 'أفضل الفنيين'),
            Tab(icon: Icon(Icons.history), text: 'النشاطات الأخيرة'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CustomLoadingIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildChartsTab(),
                    _buildTopEmployeesTab(),
                    _buildActivitiesTab(),
                  ],
                ),
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي (Core Business Logic)
  // ===========================================================================

  Future<void> _initializeScreen() async {
    final hasPermission =
        await PermissionsService.hasPermission('view_reports');
    if (!hasPermission && mounted) {
      Navigator.pop(context);
      _showErrorSnackBar('ليس لديك صلاحية لعرض التقارير');
      return;
    }
    await _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_deviceDocs == null || _labDocs == null || _userDocs == null) {
        final results = await Future.wait([
          FirebaseFirestore.instance.collection('devices').get(),
          FirebaseFirestore.instance.collection('labs').get(),
          FirebaseFirestore.instance
              .collection('users')
              .where('role', whereIn: ['technician', 'supervisor']).get(),
        ]);
        _deviceDocs = results[0].docs;
        _labDocs = results[1].docs;
        _userDocs = results[2].docs;
      }

      _processAllStats();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'خطأ في تحميل البيانات: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processAllStats() {
    if (_deviceDocs == null || _labDocs == null || _userDocs == null) return;
    _processGeneralStats(_deviceDocs!, _labDocs!, _userDocs!);
    _processDevicesByCollege(_deviceDocs!);
    _processLabsByStatus(_labDocs!);
    _processDevicesByTime(_deviceDocs!);
    _processTopEmployees(_userDocs!);
    _processRecentActivities(_deviceDocs!, _labDocs!);
  }

  // ===========================================================================
  // 5. دوال بناء مكونات الواجهة المساعدة (UI Helper Widgets)
  // ===========================================================================

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإحصائيات العامة',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildStatCard(
                title: 'إجمالي الأجهزة',
                value: _generalStats['totalDevices']?.toString() ?? '0',
                icon: Icons.computer,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: 'إجمالي المعامل',
                value: _generalStats['totalLabs']?.toString() ?? '0',
                icon: Icons.science,
                color: Colors.green,
              ),
              _buildStatCard(
                title: 'الموظفين النشطين',
                value: _generalStats['totalEmployees']?.toString() ?? '0',
                icon: Icons.people,
                color: Colors.orange,
              ),
              _buildStatCard(
                title: 'أجهزة هذا الشهر',
                value: _generalStats['devicesThisMonth']?.toString() ?? '0',
                icon: Icons.trending_up,
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مؤشرات الأداء',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      (_generalStats['deviceGrowthRate'] ?? 0) >= 0
                          ? Icons.trending_up
                          : Icons.trending_down,
                      color: (_generalStats['deviceGrowthRate'] ?? 0) >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: const Text('معدل نمو الأجهزة'),
                    subtitle: const Text('مقارنة بالشهر الماضي'),
                    trailing: Text(
                      '${(_generalStats['deviceGrowthRate'] as double?)?.toStringAsFixed(1) ?? '0.0'}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: (_generalStats['deviceGrowthRate'] ?? 0) >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.analytics, color: Colors.blue),
                    title: const Text('متوسط الأجهزة لكل معمل'),
                    trailing: Text(
                      _generalStats['averageDevicesPerLab']?.toString() ?? '0',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeFilterChip('أسبوع', 'week'),
              _buildTimeFilterChip('شهر', 'month'),
              _buildTimeFilterChip('سنة', 'year'),
            ],
          ),
          const SizedBox(height: 24),
          _buildChartCard(
            title: 'إضافة الأجهزة حسب ${_getFilterDisplayName()}',
            chart: _buildLineChart(),
          ),
          const SizedBox(height: 24),
          _buildChartCard(
            title: 'توزيع الأجهزة حسب الكليات',
            chart: _buildPieChart(),
          ),
          const SizedBox(height: 24),
          _buildChartCard(
            title: 'حالة المعامل',
            chart: _buildBarChart(),
          ),
        ],
      ),
    );
  }

  /// *** [تم التحديث] *** بناء تبويب أفضل الموظفين مع إضافة فلاتر.
  Widget _buildTopEmployeesTab() {
    // استخدام الـ getter المفلتر بدلاً من القائمة الأصلية
    final List<Map<String, dynamic>> displayedEmployees = _filteredEmployees;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _employeeSearchController,
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم، البريد، أو رقم الفني...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: displayedEmployees.isEmpty
              ? const Center(child: Text('لا يوجد فنيون يطابقون البحث.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayedEmployees.length,
                  itemBuilder: (context, index) {
                    final employee = displayedEmployees[index];
                    final rank = index + 1;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRankColor(rank),
                          child: Text(
                            '$rank',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(employee['fullName'] ?? 'غير محدد'),
                        subtitle: Text('${employee['points'] ?? 0} نقطة'),
                        trailing: _getRankIcon(rank),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActivitiesTab() {
    if (_recentActivities.isEmpty) {
      return const Center(child: Text('لا توجد أنشطة حديثة'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentActivities.length,
      itemBuilder: (context, index) {
        final activity = _recentActivities[index];
        final createdAt = (activity['createdAt'] as Timestamp?)?.toDate();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  activity['type'] == 'lab' ? Colors.green : Colors.blue,
              child: Icon(
                  activity['type'] == 'lab' ? Icons.science : Icons.computer,
                  color: Colors.white),
            ),
            title: Text(activity['description'] ?? ''),
            subtitle: Text('الكلية: ${activity['college'] ?? ''}'),
            trailing: Text(createdAt != null ? _getTimeAgo(createdAt) : ''),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 6. دوال معالجة البيانات (Data Processing Functions)
  // ===========================================================================

  void _processGeneralStats(List<QueryDocumentSnapshot> devices,
      List<QueryDocumentSnapshot> labs, List<QueryDocumentSnapshot> users) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final devicesThisMonth = devices.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null && createdAt.isAfter(startOfMonth);
    }).length;

    _generalStats = {
      'totalDevices': devices.length,
      'totalLabs': labs.length,
      'totalEmployees': users.length,
      'devicesThisMonth': devicesThisMonth,
      'deviceGrowthRate': _calculateGrowthRate(devices),
      'averageDevicesPerLab': labs.isNotEmpty
          ? (devices.length / labs.length).toStringAsFixed(1)
          : '0',
    };
  }

  double _calculateGrowthRate(List<QueryDocumentSnapshot> devices) {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final thisMonth = DateTime(now.year, now.month, 1);

    final lastMonthCount = devices.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null &&
          createdAt.isAfter(lastMonth) &&
          createdAt.isBefore(thisMonth);
    }).length;

    final thisMonthCount = devices.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null && createdAt.isAfter(thisMonth);
    }).length;

    if (lastMonthCount == 0) return thisMonthCount > 0 ? 100.0 : 0.0;
    return ((thisMonthCount - lastMonthCount) / lastMonthCount * 100);
  }

  void _processDevicesByCollege(List<QueryDocumentSnapshot> devices) {
    final Map<String, int> collegeCount = {};
    for (final doc in devices) {
      final data = doc.data() as Map<String, dynamic>;
      final college = data['college'] as String? ?? 'غير محدد';
      collegeCount[college] = (collegeCount[college] ?? 0) + 1;
    }
    _devicesByCollege = collegeCount;
  }

  void _processLabsByStatus(List<QueryDocumentSnapshot> labs) {
    final Map<String, int> statusCount = {
      'مفتوح': 0,
      'يوجد مشكلة': 0,
      'مغلق': 0,
    };
    for (final doc in labs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'closed';
      switch (status) {
        case 'openWithDevices':
          statusCount['مفتوح'] = (statusCount['مفتوح'] ?? 0) + 1;
          break;
        case 'openNoDevices':
          statusCount['يوجد مشكلة'] = (statusCount['يوجد مشكلة'] ?? 0) + 1;
          break;
        case 'closed':
          statusCount['مغلق'] = (statusCount['مغلق'] ?? 0) + 1;
          break;
      }
    }
    _labsByStatus = statusCount;
  }

  void _processDevicesByTime(List<QueryDocumentSnapshot> devices) {
    final now = DateTime.now();
    Map<String, int> timeData = {};

    if (_selectedTimeFilter == 'week') {
      final daysOfWeek = List.generate(
          7, (i) => _getDayName(now.subtract(Duration(days: i)).weekday));
      timeData = {for (var day in daysOfWeek.reversed) day: 0};

      for (final doc in devices) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && now.difference(createdAt).inDays < 7) {
          final dayName = _getDayName(createdAt.weekday);
          timeData[dayName] = (timeData[dayName] ?? 0) + 1;
        }
      }
    } else if (_selectedTimeFilter == 'month') {
      final monthsOfYear = List.generate(
          12, (i) => _getMonthName(DateTime(now.year, now.month - i).month));
      timeData = {for (var month in monthsOfYear.reversed) month: 0};

      for (final doc in devices) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && now.difference(createdAt).inDays < 365) {
          final monthName = _getMonthName(createdAt.month);
          timeData[monthName] = (timeData[monthName] ?? 0) + 1;
        }
      }
    } else {
      // year
      timeData = {for (var i = 4; i >= 0; i--) (now.year - i).toString(): 0};

      for (final doc in devices) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && now.year - createdAt.year < 5) {
          final year = createdAt.year.toString();
          timeData[year] = (timeData[year] ?? 0) + 1;
        }
      }
    }
    _devicesByTimePeriod = timeData;
  }

  void _processTopEmployees(List<QueryDocumentSnapshot> users) {
    final employeeData =
        users.map((doc) => doc.data() as Map<String, dynamic>).toList();
    employeeData.sort((a, b) => (b['points'] ?? 0).compareTo(a['points'] ?? 0));
    _topEmployees = employeeData;
  }

  void _processRecentActivities(
      List<QueryDocumentSnapshot> devices, List<QueryDocumentSnapshot> labs) {
    List<Map<String, dynamic>> activities = [];

    for (var doc in devices) {
      final data = doc.data() as Map<String, dynamic>;
      activities.add({
        'description': 'تمت إضافة جهاز "${data['name'] ?? 'غير معروف'}"',
        'college': data['college'] ?? 'غير محدد',
        'createdAt': data['createdAt'],
        'type': 'device',
      });
    }

    for (var doc in labs) {
      final data = doc.data() as Map<String, dynamic>;
      activities.add({
        'description': 'تمت إضافة معمل "${data['labNumber'] ?? 'غير معروف'}"',
        'college': data['college'] ?? 'غير محدد',
        'createdAt': data['createdAt'],
        'type': 'lab',
      });
    }

    activities.sort((a, b) {
      final dateA = (a['createdAt'] as Timestamp?) ?? Timestamp(0, 0);
      final dateB = (b['createdAt'] as Timestamp?) ?? Timestamp(0, 0);
      return dateB.compareTo(dateA);
    });

    _recentActivities = activities.take(10).toList();
  }

  // ===========================================================================
  // 7. دوال مساعدة متنوعة (Misc Helpers)
  // ===========================================================================

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    return _topEmployees.where((employee) {
      final fullName = employee['fullName']?.toString().toLowerCase() ?? '';
      final email = employee['email']?.toString().toLowerCase() ?? '';
      final employeeId = employee['employeeId']?.toString().toLowerCase() ?? '';
      final query = _employeeSearchController.text.toLowerCase();

      final matchesSearch = fullName.contains(query) ||
          email.contains(query) ||
          employeeId.contains(query);

      final matchesRole = _selectedRoleFilter == 'all' ||
          employee['role'] == _selectedRoleFilter;

      return matchesSearch && matchesRole;
    }).toList();
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterChip(String label, String value) {
    final isSelected = _selectedTimeFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTimeFilter = value;
            _processDevicesByTime(_deviceDocs ?? []);
          });
        }
      },
      selectedColor: Theme.of(context).colorScheme.primary
        ..withAlpha((255 * 0.2).round()),
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildChartCard({required String title, required Widget chart}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 300, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    final data = _devicesByTimePeriod;
    if (data.isEmpty) return const Center(child: Text('لا توجد بيانات'));

    final labels = data.keys.toList();
    final values = data.values.toList();

    final spots = List.generate(
      labels.length,
      (i) => FlSpot(i.toDouble(), values[i].toDouble()),
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: labels.length - 1.toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          horizontalInterval: 10,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.shade300,
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: Colors.grey.shade300,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, _) {
                if (value % 1 != 0 || value < 0 || value >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    labels[value.toInt()],
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 4,
            color: Theme.of(context).colorScheme.primary,
            belowBarData: BarAreaData(show: false),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 6,
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    if (_devicesByCollege.isEmpty) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    final totalDevices = _devicesByCollege.values.fold(0, (a, b) => a + b);
    if (totalDevices == 0) return const Center(child: Text('لا توجد بيانات'));

    final sections = _devicesByCollege.entries.map((entry) {
      final percentage = (entry.value / totalDevices) * 100;
      return PieChartSectionData(
        color: _getCollegeColor(entry.key),
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 35,
              sectionsSpace: 2,
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _devicesByCollege.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                        width: 16,
                        height: 16,
                        color: _getCollegeColor(entry.key)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(entry.key,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    if (_labsByStatus.isEmpty) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    final barGroups = _labsByStatus.entries.map((entry) {
      final index = _labsByStatus.keys.toList().indexOf(entry.key);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: _getStatusColor(entry.key),
            width: 30,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final keys = _labsByStatus.keys.toList();
                if (value.toInt() < keys.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(keys[value.toInt()],
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        barGroups: barGroups,
        maxY: (_labsByStatus.values.isNotEmpty
                    ? _labsByStatus.values.reduce((a, b) => a > b ? a : b)
                    : 0)
                .toDouble() +
            2,
      ),
    );
  }

  String _getFilterDisplayName() {
    switch (_selectedTimeFilter) {
      case 'week':
        return 'الأيام';
      case 'month':
        return 'الشهور';
      case 'year':
        return 'السنوات';
      default:
        return '';
    }
  }

  String _getDayName(int weekday) {
    const days = ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    final correctedMonth = (month - 1).abs() % 12;
    const months = [
      'ينا',
      'فبر',
      'مار',
      'أبر',
      'ماي',
      'يون',
      'يول',
      'أغس',
      'سبت',
      'أكت',
      'نوف',
      'ديس'
    ];
    return months[correctedMonth];
  }

  Color _getCollegeColor(String college) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.indigo
    ];
    final index = _devicesByCollege.keys.toList().indexOf(college);
    return colors[index % colors.length];
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'مفتوح':
        return Colors.green;
      case 'يوجد مشكلة':
        return Colors.orange;
      case 'مغلق':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[600]!;
      case 3:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return 'منذ ${difference.inDays} يوم';
    if (difference.inHours > 0) return 'منذ ${difference.inHours} ساعة';
    if (difference.inMinutes > 0) return 'منذ ${difference.inMinutes} دقيقة';
    return 'منذ لحظات';
  }
}

Widget? _getRankIcon(int rank) {
  switch (rank) {
    case 1:
      return const Icon(Icons.emoji_events, color: Colors.amber, size: 32);
    case 2:
      return Icon(Icons.emoji_events, color: Colors.grey.shade600, size: 28);
    case 3:
      return Icon(Icons.emoji_events, color: Colors.brown.shade400, size: 24);
    default:
      return null;
  }
}
