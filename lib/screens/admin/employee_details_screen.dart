import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/ui_helpers.dart';

class EmployeeDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> employeeData;

  const EmployeeDetailsScreen({super.key, required this.employeeData});

  // ===========================================================================
  // 1. دالة بناء واجهة المستخدم (UI Build Method) - (أساسي)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String fullName = employeeData['fullName'] ?? 'غير متوفر';
    final String email = employeeData['email'] ?? 'غير متوفر';
    final String employeeId = employeeData['employeeId'] ?? 'غير متوفر';
    final String role = employeeData['role'] ?? 'غير محدد';
    final int points = (employeeData['points'] ?? 0).toInt();
    final int tasksCompleted = (employeeData['tasksCompleted'] ?? 0).toInt();
    final int devicesRegistered =
        (employeeData['devicesRegistered'] ?? 0).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text(fullName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- قسم معلومات الحساب ---
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'معلومات الحساب',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  _buildInfoRow(Icons.person, 'الاسم الكامل:', fullName),
                  _buildInfoRow(Icons.badge, 'الرقم الوظيفي:', employeeId),
                  _buildInfoRow(Icons.email, 'البريد الإلكتروني:', email),
                  _buildInfoRow(Icons.work, 'الدور:', role),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('إعادة تعيين كلمة المرور'),
                      onPressed: () => _resetPassword(context, email),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- قسم إحصائيات الأداء ---
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إحصائيات الأداء',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  _buildStatCard('النقاط المكتسبة', points.toString(),
                      Icons.star, Colors.amber),
                  _buildStatCard('المهام المكتملة', tasksCompleted.toString(),
                      Icons.task_alt, Colors.green),
                  _buildStatCard('الأجهزة المسجلة',
                      devicesRegistered.toString(), Icons.devices, Colors.blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. الدوال المساعدة (Helper Functions) - (يمكن فصلها)
  // ===========================================================================

  /// دالة لإعادة تعيين كلمة المرور.
  Future<void> _resetPassword(BuildContext context, String email) async {
    final confirmed = await UIHelpers.showConfirmationDialog(
      context: context,
      title: 'إعادة تعيين كلمة المرور',
      content:
          'هل أنت متأكد أنك تريد إرسال رابط إعادة تعيين كلمة المرور إلى البريد الإلكتروني $email ؟',
      confirmText: 'إرسال',
      cancelText: 'إلغاء',
    );

    if (confirmed == true) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        if (context.mounted) {
          UIHelpers.showSuccessSnackBar(
              context, 'تم إرسال رابط إعادة التعيين بنجاح.');
        }
      } catch (e) {
        if (context.mounted) {
          UIHelpers.showErrorSnackBar(context, 'فشل إرسال الرابط: $e');
        }
      }
    }
  }

  /// ويدجت مساعد لبناء صف معلومات منسق.
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  /// ويدجت مساعد لبناء بطاقة إحصائية واحدة.
  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
