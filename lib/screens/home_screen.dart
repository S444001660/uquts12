import 'package:flutter/material.dart';
import '../services/permissions_service.dart';
import '../services/task_progress_service.dart';
import '../models/lab_model.dart';
import '../models/device_model.dart';
import '../models/user_account_model.dart';
import '../models/user_role_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- جميع الاستيرادات أصبحت الآن مستخدمة ---
import 'add_lab_screen.dart';
import 'add_device_screen.dart';
import 'barcode_scanner_screen.dart';
import 'settings_screen.dart';
import 'labs_list_screen.dart';
import 'devices_list_screen.dart';
import 'admin/admin_tasks_history_screen.dart';
import 'admin/admin_task_details_screen.dart';
import 'add_task.dart';
import 'user_tasks_screen.dart';
import 'task_details_screen.dart';
import 'lab_details_screen.dart';
import 'view_device_screen.dart';
import 'technician_stats_screen.dart';
import '../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

class UpdatedHomeScreen extends StatefulWidget {
  const UpdatedHomeScreen({super.key});

  @override
  State<UpdatedHomeScreen> createState() => _UpdatedHomeScreenState();
}

class _UpdatedHomeScreenState extends State<UpdatedHomeScreen>
    with TickerProviderStateMixin {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  bool _isLoading = true;
  List<RecentActivity> _recentActivities = [];
  List<Map<String, dynamic>> _userTasks = [];
  String? _error;
  UserRole? _currentUserRole;
  UserAccountModel? _currentUser;
  String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> assignedTasks = [];

  late TabController _tabController;

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle)
  // ===========================================================================

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

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method)
  // ===========================================================================

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

  // ===========================================================================
  // 4. منطق العمل الرئيسي والتنقل (Core Logic & Navigation)
  // ===========================================================================

  Future<void> _loadUserAndData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _currentUser =
          await PermissionsService.getCurrentUserInfo(forceRefresh: true);
      _currentUserRole = await PermissionsService.getCurrentUserRole();

      await Future.wait([
        _loadRecentActivitiesOptimized(),
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
    _navigateAndReload(page);
  }

  void _navigateAndReload(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen))
        .then((_) => _loadUserAndData());
  }

  // ===========================================================================
  // 5. دوال بناء مكونات الواجهة (UI Builder Methods)
  // ===========================================================================

  /// *** [تم التحديث] *** بناء رأس الصفحة مع عرض شعار الجامعة.
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
                    color: theme.colorScheme.onPrimary.withAlpha(230),
                  ),
                ),
                if (_currentUser?.points != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
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
          // --- [تم التغيير هنا] --- استبدال النص بالصورة
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(8.0), // هامش داخلي للصورة
              child: Image.asset(
                'assets/images/uquLogo.png',
                // في حالة عدم وجود الصورة، اعرض أيقونة بديلة
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.school,
                    size: 30,
                    color: theme.colorScheme.primary,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTabBar(ThemeData theme) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(5.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(26),
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

  Widget _buildRecentActivitiesSection(ThemeData theme) {
    return Container(
      key: const ValueKey<int>(0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: _isLoading
          ? const Center(child: CustomLoadingIndicator())
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("المهام الحالية", style: theme.textTheme.titleMedium),
                TextButton(
                  onPressed: () {
                    if (_currentUserRole == UserRole.technician) {
                      _navigateAndReload(const UserTasksScreen());
                    } else {
                      _navigateAndReload(const AdminTasksHistoryScreen());
                    }
                  },
                  child: const Text("عرض الكل"),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CustomLoadingIndicator())
                : (_currentUserRole == UserRole.technician
                    ? _buildUserTasksList(theme)
                    : _buildAdminAssignedTasksList(theme)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    List<_HomeButton> buttons = [];

    buttons.addAll([
      _HomeButton(Icons.add_business_outlined, 'إضافة معمل',
          () => _navigateAndReload(const AddLabScreen())),
      _HomeButton(Icons.add_to_queue_outlined, 'إضافة جهاز',
          () => _navigateAndReload(const AddDeviceScreen())),
    ]);

    if (_currentUserRole == UserRole.admin ||
        _currentUserRole == UserRole.supervisor) {
      buttons.addAll([
        _HomeButton(Icons.assignment_add, 'إسناد مهمة',
            () => _navigateAndReload(const ImprovedAddTaskScreen())),
        _HomeButton(Icons.history, 'سجل المهام',
            () => _navigateAndReload(const AdminTasksHistoryScreen())),
      ]);
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
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 1.0,
        children: buttons.map((btn) => _buildStyledButton(btn)).toList(),
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
            icon: Icon(Icons.more_horiz_outlined), label: 'المزيد'),
      ],
    );
  }

  Widget _buildActivitiesList(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
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

  Widget _buildUserTasksList(ThemeData theme) {
    if (_userTasks.isEmpty) {
      return const Center(child: Text('لا توجد مهام نشطة حالياً.'));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _userTasks.length,
        itemBuilder: (context, index) {
          final taskData = _userTasks[index];
          final mainTask = taskData['mainTask'];
          final userTask = taskData['userTask'];

          final progress =
              (mainTask['targetCount'] != null && mainTask['targetCount'] > 0)
                  ? (userTask['progress'] ?? 0.0) / mainTask['targetCount']
                  : null;

          return _buildTaskTile(
            icon: _getIconForTaskType(mainTask['type']),
            title: mainTask['typeDisplayName'] ?? 'مهمة',
            subtitle: Text('الكلية: ${mainTask['college'] ?? 'غير محدد'}'),
            progress: progress,
            onTap: () => _navigateAndReload(TaskDetailsScreen(
              taskId: mainTask['id'],
              userTaskId: userTask['id'],
            )),
            theme: theme,
          );
        },
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
      ),
    );
  }

  Widget _buildAdminAssignedTasksList(ThemeData theme) {
    if (assignedTasks.isEmpty) {
      return const Center(child: Text('لم تقم بإسناد أي مهام مؤخراً.'));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: assignedTasks.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final task = assignedTasks[index];
          final assignedCount = (task['assignedTo'] as List?)?.length ?? 0;

          return _buildTaskTile(
            icon: _getIconForTaskType(task['type']),
            title: task['typeDisplayName'] ?? 'مهمة',
            subtitle: Text(
                'الكلية: ${task['college'] ?? 'غير محدد'} | المسند إلى: $assignedCount فنيين'),
            progress: task['completionPercentage']?.toDouble() ?? 0.0,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminTaskDetailsScreen(task: task),
                ),
              );
            },
            theme: theme,
          );
        },
      ),
    );
  }

  Widget _buildActivityTile(RecentActivity activity, ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const Icon(Icons.chevron_left, color: Colors.grey),
      title: Text(activity.title,
          style: theme.textTheme.titleMedium, textAlign: TextAlign.right),
      subtitle: Text(_formatTimestamp(activity.timestamp),
          style: theme.textTheme.bodySmall, textAlign: TextAlign.right),
      trailing: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withAlpha(26),
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
                  builder: (_) =>
                      LabDetailsScreen(lab: activity.originalObject)));
        } else if (activity.type == 'device') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ViewDeviceScreen(device: activity.originalObject)));
        }
      },
    );
  }

  Widget _buildTaskTile({
    required IconData icon,
    required String title,
    required Widget subtitle,
    required VoidCallback onTap,
    double? progress,
    required ThemeData theme,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: const Icon(Icons.chevron_left, color: Colors.grey),
      title: Text(title,
          style: theme.textTheme.titleMedium, textAlign: TextAlign.right),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            subtitle,
            if (progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.primary.withAlpha(51),
                color: theme.colorScheme.primary,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ]
          ],
        ),
      ),
      trailing: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withAlpha(26),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      onTap: onTap,
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
              color: Colors.black.withAlpha(13),
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

  Widget _buildErrorState(ThemeData theme, String errorMessage) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.error.withAlpha(128))),
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

  // ===========================================================================
  // 6. دوال تحميل البيانات والمساعدة (Data & Helper Functions)
  // ===========================================================================

  Future<void> _loadTasksForHomeScreen() async {
    if (_currentUser == null) return;
    try {
      if (_currentUserRole == UserRole.technician) {
        List<Map<String, dynamic>> tasks =
            await TaskProgressService.getUserActiveTasks(_currentUser!.uid);

        tasks.sort((a, b) {
          final dateA = a['mainTask']?['createdAt'] as Timestamp?;
          final dateB = b['mainTask']?['createdAt'] as Timestamp?;

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;

          return dateB.toDate().compareTo(dateA.toDate());
        });

        if (mounted) setState(() => _userTasks = tasks);
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('tasks')
            .where('createdBy', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
        final tasks =
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        if (mounted) setState(() => assignedTasks = tasks);
      }
    } catch (e) {
      debugPrint('خطأ في تحميل المهام للشاشة الرئيسية: $e');
    }
  }

  Future<void> _loadRecentActivitiesOptimized() async {
    List<RecentActivity> allActivities = [];
    final firestore = FirebaseFirestore.instance;

    final results = await Future.wait([
      firestore
          .collection('labs')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get(),
      firestore
          .collection('devices')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get(),
    ]);

    final labDocs = results[0].docs;
    final deviceDocs = results[1].docs;

    for (var doc in labDocs) {
      final lab = LabModel.fromMap(doc.data());
      allActivities.add(RecentActivity(
        id: lab.id,
        title: 'إضافة معمل ${lab.labNumber}',
        type: 'lab',
        timestamp: lab.createdAt,
        originalObject: lab,
        createdBy: lab.createdBy,
        createdByName: lab.createdByName,
      ));
    }

    for (var doc in deviceDocs) {
      final device = DeviceModel.fromMap(doc.data());
      allActivities.add(RecentActivity(
        id: device.id,
        title: 'إضافة جهاز "${device.name}"',
        type: 'device',
        timestamp: device.createdAt,
        originalObject: device,
        createdBy: device.createdBy,
        createdByName: device.createdByName,
      ));
    }

    for (var activity in allActivities) {
      final creatorName = activity.createdByName ?? 'غير معروف';
      if (activity.type == 'lab') {
        activity.title =
            'إضافة معمل ${(activity.originalObject as LabModel).labNumber} بواسطة $creatorName';
      } else {
        activity.title =
            'إضافة جهاز "${(activity.originalObject as DeviceModel).name}" بواسطة $creatorName';
      }
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

  IconData _getIconForTaskType(String? taskType) {
    switch (taskType) {
      case 'deviceRegistration':
        return Icons.app_registration;
      case 'maintenance':
        return Icons.build_outlined;
      case 'inspection':
        return Icons.search_outlined;
      case 'setup':
        return Icons.settings_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }
}

// ===========================================================================
// 7. كلاسات مساعدة (Helper Classes)
// ===========================================================================

class _HomeButton {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _HomeButton(this.icon, this.label, this.onTap);
}

class RecentActivity {
  String id;
  String title;
  String type;
  DateTime timestamp;
  dynamic originalObject;
  String? createdBy;
  String? createdByName;

  RecentActivity({
    required this.id,
    required this.title,
    required this.type,
    required this.timestamp,
    required this.originalObject,
    this.createdBy,
    this.createdByName,
  });
}
