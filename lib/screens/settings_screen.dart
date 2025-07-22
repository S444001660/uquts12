import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth/auth_wrapper.dart'; // للعودة إلى شاشة المصادقة بعد الخروج
import 'admin/create_user_screen.dart'; // <<<=== هذا هو السطر الجديد والمهم
import '../services/permissions_service.dart'; // استيراد خدمة الصلاحيات

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }
    // يجب استبدال هذا الإيميل بالإيميل الفعلي الخاص برئيس القسم
    return user.email == 'admin@uqu.edu.sa';
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
          if (_isAdmin())
            Card(
              elevation: 4,
              child: ListTile(
                leading: Icon(Icons.admin_panel_settings,
                    color: theme.colorScheme.primary),
                title: const Text('إدارة المستخدمين'),
                subtitle: const Text('إنشاء حسابات جديدة للمستخدمين'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // الانتقال إلى شاشة إنشاء المستخدم
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateUserScreen(),
                    ),
                  );
                },
              ),
            ),

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
