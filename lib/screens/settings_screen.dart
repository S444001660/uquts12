import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uquts1/models/user_account_model.dart';
import 'package:uquts1/models/user_role_model.dart';
import 'package:uquts1/screens/admin/admin_tasks_history_screen.dart';
import 'package:uquts1/screens/admin/employee_management_screen.dart';
import 'package:uquts1/screens/admin/reports_screen.dart';
import 'package:uquts1/screens/technician_stats_screen.dart';
import 'package:uquts1/screens/user_tasks_screen.dart';
import '../auth/auth_wrapper.dart';
import 'admin/create_user_screen.dart'; // <-- أصبح هذا الاستيراد مستخدمًا الآن
import '../services/permissions_service.dart';
import '../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة (State Definitions)
  // ===========================================================================

  bool _isLoading = true;
  String? _error;
  UserRole? _currentUserRole;
  UserAccountModel? _currentUser;

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المزيد'),
        centerTitle: true,
      ),
      body: _buildBody(), // بناء المحتوى بناءً على الحالة
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي (Core Business Logic)
  // ===========================================================================

  /// دالة لتحميل بيانات المستخدم وصلاحياته.
  Future<void> _loadUserAndData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _currentUserRole = await PermissionsService.getCurrentUserRole();
      _currentUser = await PermissionsService.getCurrentUserInfo();

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

  /// دالة لتسجيل الخروج والعودة إلى شاشة المصادقة.
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    PermissionsService.clearCache();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // ===========================================================================
  // 5. دوال بناء مكونات الواجهة المساعدة (UI Helper Widgets)
  // ===========================================================================

  /// ويدجت لبناء محتوى الشاشة بناءً على الحالة (تحميل، خطأ، نجاح).
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CustomLoadingIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserAndData,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    return _buildSettingsList();
  }

  /// ويدجت لبناء قائمة الإعدادات بعد تحميل البيانات بنجاح.
  Widget _buildSettingsList() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._buildAdminOptions(theme),
        ..._buildTechnicianOptions(theme),
        ..._buildAccountOptions(theme),
      ],
    );
  }

  /// بناء خيارات المدير والمشرف.
  List<Widget> _buildAdminOptions(ThemeData theme) {
    if (_currentUserRole == UserRole.admin ||
        _currentUserRole == UserRole.supervisor) {
      return [
        _buildSectionTitle('إدارة النظام'),
        _buildSettingsCard(
          icon: Icons.person_add_alt_1,
          title: 'إنشاء مستخدم جديد',
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CreateUserScreen())),
          theme: theme,
        ),
        _buildSettingsCard(
          icon: Icons.admin_panel_settings,
          title: 'إدارة الحسابات',
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const EmployeeManagementScreen())),
          theme: theme,
        ),
        _buildSettingsCard(
          icon: Icons.analytics,
          title: 'التقارير',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const ReportsScreen())),
          theme: theme,
        ),
        _buildSettingsCard(
          icon: Icons.history,
          title: 'سجل المهام',
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AdminTasksHistoryScreen())),
          theme: theme,
        ),
      ];
    }
    return [];
  }

  /// بناء خيارات الفني.
  List<Widget> _buildTechnicianOptions(ThemeData theme) {
    if (_currentUserRole == UserRole.technician) {
      return [
        _buildSectionTitle('أدوات الفني'),
        _buildSettingsCard(
          icon: Icons.task_alt,
          title: 'مهامي',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const UserTasksScreen())),
          theme: theme,
        ),
        _buildSettingsCard(
          icon: Icons.insights,
          title: 'إحصائياتي',
          onTap: () {
            if (_currentUser != null) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          TechnicianStatsScreen(user: _currentUser!)));
            }
          },
          theme: theme,
        ),
      ];
    }
    return [];
  }

  /// بناء خيارات الحساب العامة.
  List<Widget> _buildAccountOptions(ThemeData theme) {
    return [
      _buildSectionTitle('الحساب'),
      _buildSettingsCard(
        icon: Icons.logout,
        title: 'تسجيل الخروج',
        onTap: _signOut,
        theme: theme,
        color: Colors.redAccent,
      ),
    ];
  }

  /// ويدجت مساعد لبناء عنوان لكل قسم.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, right: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  /// ويدجت مساعد لبناء بطاقة إعدادات منسقة.
  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required ThemeData theme,
    Color? color,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color ?? theme.colorScheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
