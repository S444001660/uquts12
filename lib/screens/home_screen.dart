import 'package:flutter/material.dart';
import '../services/permissions_service.dart';
import '../services/task_progress_service.dart';
import '../models/lab_model.dart';
import '../models/device_model.dart';
import '../models/user_account_model.dart';
import '../models/user_role_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_lab_screen.dart';
import 'add_device_screen.dart';
import 'barcode_scanner_screen.dart';
import 'settings_screen.dart';
import 'labs_list_screen.dart';
import 'devices_list_screen.dart';
import 'admin/employee_management_screen.dart';
import 'admin/reports_screen.dart';
import 'admin/admin_tasks_history_screen.dart'; // <-- 1. استيراد شاشة سجل المهام
import 'admin/admin_task_details_screen.dart'; // استيراد شاشة تفاصيل الأدمن
import 'add_task.dart';
import 'user_tasks_screen.dart';
import '../services/firebase_database_service.dart';
import 'task_details_screen.dart';
import 'lab_details_screen.dart';
import 'view_device_screen.dart';
import '../screens/technician_stats_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UpdatedHomeScreen extends StatefulWidget {
  const UpdatedHomeScreen({super.key});

  @override
  State<UpdatedHomeScreen> createState() => _UpdatedHomeScreenState();
}

class _UpdatedHomeScreenState extends State<UpdatedHomeScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<RecentActivity> _recentActivities = [];
  List<Map<String, dynamic>> _userTasks = [];
  String? _error;
  UserRole? _currentUserRole;
  UserAccountModel? _currentUser;
  String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> assignedTasks = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadUserAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _currentUser = await PermissionsService.getCurrentUserInfo();
      _currentUserRole = await PermissionsService.getCurrentUserRole();

      await Future.wait([
        _loadRecentActivities(),
        _loadTasksForHomeScreen(),
      ]);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ في تحميل البيانات: $e';
          _isLoading = false;
        });
      }
    }
  }

  // دالة واحدة لجلب المهام بناءً على دور المستخدم
  Future<void> _loadTasksForHomeScreen() async {
    if (_currentUser == null) return;

    try {
      List<Map<String, dynamic>> tasks = [];
      if (_currentUserRole == UserRole.technician) {
        // الفني يرى مهامه النشطة
        tasks = await TaskProgressService.getUserActiveTasks(_currentUser!.uid);
        if (mounted) setState(() => _userTasks = tasks);
      } else {
        // الأدمن والمشرف يرون آخر 5 مهام قاموا بإنشائها
        final snapshot = await FirebaseFirestore.instance
            .collection('tasks')
            .where('createdBy', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
            .limit(5) // <-- 2. تحديد عدد المهام بـ 5 فقط
            .get();
        tasks =
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        if (mounted) setState(() => assignedTasks = tasks);
      }
    } catch (e) {
      debugPrint('خطأ في تحميل المهام للشاشة الرئيسية: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    final List<LabModel> labs = await FirebaseDatabaseService.getLabs();
    final List<DeviceModel> devices =
        await FirebaseDatabaseService.getDevices();
    List<RecentActivity> allActivities = [];

    Future<String?> _getUserName(String? uid) async {
      if (uid == null) return null;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return userDoc.data()?['fullName'];
    }

    for (var lab in labs) {
      final createdByName = await _getUserName(lab.createdBy);
      allActivities.add(RecentActivity(
        id: lab.id,
        title:
            'إضافة معمل ${lab.labNumber} بواسطة ${createdByName ?? "غير معروف"}',
        type: 'lab',
        timestamp: lab.createdAt,
        originalObject: lab,
      ));
    }

    for (var device in devices) {
      final createdByName = await _getUserName(device.createdBy);
      allActivities.add(RecentActivity(
        id: device.id,
        title:
            'إضافة جهاز "${device.name}" بواسطة ${createdByName ?? "غير معروف"}',
        type: 'device',
        timestamp: device.createdAt,
        originalObject: device,
      ));
    }

    allActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (mounted) {
      setState(() {
        _recentActivities = allActivities.take(5).toList();
      });
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 0) {
      return 'قبل ${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return 'قبل ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'قبل ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  void _onNavBarTapped(int index) {
    Widget page;
    switch (index) {
      case 0:
        page = const LabsListScreen();
        break;
      case 1:
        page = const DevicesListScreen();
        break;
      case 2:
        page = const BarcodeScannerScreen();
        break;
      case 3:
        page = const SettingsScreen();
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => page))
        .then((_) => _loadUserAndData());
  }

  void _navigateAndReload(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen))
        .then((_) => _loadUserAndData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          _buildUserInfoHeader(theme),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
            child: _buildCustomTabBar(theme),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _tabController.index == 0
                    ? _buildRecentActivitiesSection(theme)
                    : _buildTasksSection(theme),
              ),
            ),
          ),
          _buildQuickActions(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(theme),
    );
  }

  Widget _buildCustomTabBar(ThemeData theme) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(5.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          color: theme.colorScheme.primary,
        ),
        labelColor: theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(10.0),
        tabs: const [
          Tab(text: 'آخر العمليات'),
          Tab(text: 'المهام'),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar(ThemeData theme) {
    return BottomNavigationBar(
      onTap: _onNavBarTapped,
      type: BottomNavigationBarType.fixed,
      backgroundColor: theme.colorScheme.surface,
      selectedItemColor: Colors.grey,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.science_outlined), label: 'المعامل'),
        BottomNavigationBarItem(
            icon: Icon(Icons.computer_outlined), label: 'الأجهزة'),
        BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner), label: 'مسح'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined), label: 'الإعدادات'),
      ],
    );
  }

  Widget _buildUserInfoHeader(ThemeData theme) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final userName = _currentUser?.fullName ?? 'مستخدم';
    final userRole = _currentUserRole?.displayName ?? 'مستخدم';

    return Container(
      padding: EdgeInsets.only(
          top: topPadding + 16, bottom: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userRole,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withOpacity(0.9),
                  ),
                ),
                if (_currentUser?.points != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentUser!.points} نقطة',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
      child: _buildActionButtons(),
    );
  }

  Widget _buildActionButtons() {
    List<_HomeButton> buttons = [];

    buttons.addAll([
      _HomeButton(Icons.add_business_outlined, 'إضافة معمل',
          () => _navigateAndReload(const AddLabScreen())),
      _HomeButton(Icons.add_to_queue_outlined, 'إضافة جهاز',
          () => _navigateAndReload(const AddDeviceScreen())),
    ]);

    if (_currentUserRole == UserRole.admin ||
        _currentUserRole == UserRole.supervisor) {
      buttons.add(_HomeButton(Icons.assignment_add, 'إسناد مهمة',
          () => _navigateAndReload(const ImprovedAddTaskScreen())));

      if (_currentUserRole == UserRole.admin) {
        buttons.addAll([
          _HomeButton(Icons.people, 'إدارة الموظفين',
              () => _navigateAndReload(const EmployeeManagementScreen())),
          _HomeButton(Icons.analytics, 'التقارير',
              () => _navigateAndReload(const ReportsScreen())),
          // <-- 3. إضافة الزر الجديد هنا
          _HomeButton(Icons.history, 'سجل المهام',
              () => _navigateAndReload(const AdminTasksHistoryScreen())),
        ]);
      }
    }
    if (_currentUserRole == UserRole.technician) {
      buttons.addAll([
        _HomeButton(Icons.task_alt, 'مهامي',
            () => _navigateAndReload(const UserTasksScreen())),
        _HomeButton(
            Icons.insights,
            'إحصائياتي',
            () =>
                _navigateAndReload(TechnicianStatsScreen(user: _currentUser!))),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double itemWidth = (constraints.maxWidth - 24) / 4;

          return Wrap(
            spacing: 8,
            runSpacing: 12,
            children: buttons.map((btn) {
              return SizedBox(
                width: itemWidth,
                child: _buildStyledButton(btn),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildRecentActivitiesSection(ThemeData theme) {
    return Container(
      key: const ValueKey<int>(0),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(theme, _error!)
              : _recentActivities.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off,
                              size: 50, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('لا يوجد أي عمليات أخيرة',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    )
                  : _buildActivitiesList(theme),
    );
  }

  Widget _buildTasksSection(ThemeData theme) {
    return Container(
      key: const ValueKey<int>(1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_currentUserRole == UserRole.technician
              ? _buildUserTasksList(theme)
              : _buildAdminAssignedTasksList(theme)),
    );
  }

  Widget _buildUserTasksList(ThemeData theme) {
    if (_userTasks.isEmpty) {
      return const Center(child: Text('لا توجد مهام نشطة حالياً.'));
    }
    return ListView.separated(
      itemCount: _userTasks.length,
      itemBuilder: (context, index) {
        final taskData = _userTasks[index];
        final mainTask = taskData['mainTask'];
        final userTask = taskData['userTask'];
        return ListTile(
          title: Text(mainTask['typeDisplayName'] ?? 'مهمة'),
          onTap: () => _navigateAndReload(TaskDetailsScreen(
            taskId: mainTask['id'],
            userTaskId: userTask['id'],
          )),
        );
      },
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
    );
  }

  Widget _buildAdminAssignedTasksList(ThemeData theme) {
    if (assignedTasks.isEmpty) {
      return const Center(child: Text('لم تقم بإسناد أي مهام مؤخراً.'));
    }
    return ListView.separated(
      itemCount: assignedTasks.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final task = assignedTasks[index];
        return ListTile(
          title: Text(task['typeDisplayName'] ?? 'مهمة'),
          subtitle: Text(task['notes'] ?? 'لا توجد ملاحظات',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminTaskDetailsScreen(task: task),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActivitiesList(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)),
      child: ListView.separated(
        itemCount: _recentActivities.length,
        itemBuilder: (context, index) {
          final activity = _recentActivities[index];
          return _buildActivityTile(activity, theme);
        },
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
      ),
    );
  }

  Widget _buildActivityTile(RecentActivity activity, ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const Icon(Icons.chevron_left, color: Colors.grey),
      title: Text(activity.title,
          style: theme.textTheme.titleMedium, textAlign: TextAlign.right),
      subtitle: Text(
        _formatTimestamp(activity.timestamp),
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.right,
      ),
      trailing: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        child: Icon(
          activity.type == 'lab'
              ? Icons.science_outlined
              : Icons.computer_outlined,
          color: theme.colorScheme.primary,
        ),
      ),
      onTap: () {
        if (activity.type == 'lab') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LabDetailsScreen(lab: activity.originalObject),
            ),
          );
        } else if (activity.type == 'device') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewDeviceScreen(device: activity.originalObject),
            ),
          );
        }
      },
    );
  }

  Widget _buildErrorState(ThemeData theme, String errorMessage) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
            const SizedBox(height: 16),
            Text(errorMessage,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
                onPressed: _loadUserAndData,
                child: const Text('إعادة المحاولة'))
          ],
        ),
      ),
    );
  }

  Widget _buildStyledButton(_HomeButton btn) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: btn.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(btn.icon, size: 26, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              btn.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            )
          ],
        ),
      ),
    );
  }
}

class _HomeButton {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _HomeButton(this.icon, this.label, this.onTap);
}

class RecentActivity {
  final String id;
  final String title;
  final String type;
  final DateTime timestamp;
  final dynamic originalObject;

  RecentActivity({
    required this.id,
    required this.title,
    required this.type,
    required this.timestamp,
    required this.originalObject,
  });
}
