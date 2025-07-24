import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uquts1/models/user_account_model.dart';
import 'package:uquts1/screens/admin/admin_tasks_history_screen.dart';
import 'package:uquts1/screens/admin/employee_management_screen.dart';
import 'package:uquts1/screens/admin/reports_screen.dart';
import 'package:uquts1/screens/technician_stats_screen.dart';
import 'package:uquts1/screens/user_tasks_screen.dart';
import '../auth/auth_wrapper.dart'; // للعودة إلى شاشة المصادقة بعد الخروج
import 'admin/create_user_screen.dart'; // <<<=== هذا هو السطر الجديد والمهم
import '../services/permissions_service.dart'; // استيراد خدمة الصلاحيات
import 'package:uquts1/models/user_role_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  String? _error;
  UserRole? _currentUserRole;
  UserAccountModel? _currentUser;

  Future<void> _loadUserAndData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // تحميل معلومات المستخدم والصلاحيات

      _currentUserRole = await PermissionsService.getCurrentUserRole();
      _currentUser = await PermissionsService.getCurrentUserInfo();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ في تحميل البيانات: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    // مسح الذاكرة المؤقتة للصلاحيات عند تسجيل الخروج
    PermissionsService.clearCache(); // <--- إضافة هذا السطر
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // قسم إدارة النظام (يظهر للأدمن فقط)
          // قسم إدارة النظام (يظهر للأدمن فقط)
          ...(_currentUserRole == UserRole.admin ||
                  _currentUserRole == UserRole.supervisor
              ? [
                  Card(
                    elevation: 4,
                    child: ListTile(
                      leading: Icon(Icons.admin_panel_settings,
                          color: theme.colorScheme.primary),
                      title: const Text('إدارة الموظفين'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const EmployeeManagementScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    child: ListTile(
                      leading: Icon(Icons.analytics,
                          color: theme.colorScheme.primary),
                      title: const Text('التقارير'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    child: ListTile(
                      leading:
                          Icon(Icons.history, color: theme.colorScheme.primary),
                      title: const Text('سجل المهام'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminTasksHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ]
              : []),

          ...(_currentUserRole == UserRole.technician
              ? [
                  Card(
                    elevation: 4,
                    child: ListTile(
                      leading: Icon(Icons.task_alt,
                          color: theme.colorScheme.primary),
                      title: const Text('مهامي'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserTasksScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    child: ListTile(
                      leading: Icon(Icons.insights,
                          color: theme.colorScheme.primary),
                      title: const Text('إحصائياتي'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TechnicianStatsScreen(user: _currentUser!),
                          ),
                        );
                      },
                    ),
                  ),
                ]
              : []),

          const SizedBox(height: 16),

          // قسم الحساب
          Card(
            elevation: 4,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('تسجيل الخروج'),
              onTap: _signOut,
            ),
          ),
        ],
      ),
    );
  }
}
