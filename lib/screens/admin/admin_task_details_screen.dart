import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

class AdminTaskDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> task;

  const AdminTaskDetailsScreen({super.key, required this.task});

  // ===========================================================================
  // 1. دالة بناء واجهة المستخدم (UI Build Method) - (أساسي)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title = task['typeDisplayName'] ?? 'تفاصيل المهمة';
    final String notes = task['notes'] ?? 'لا توجد ملاحظات.';
    final String college = task['college'] ?? 'غير محدد';
    final bool isCompleted = task['isCompleted'] ?? false;
    final int targetCount = (task['targetCount'] ?? 0).toInt();
    final int currentCount = (task['currentCount'] ?? 0).toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- قسم تفاصيل المهمة الرئيسية ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.info_outline, 'الكلية:', college),
                  _buildInfoRow(Icons.notes, 'الملاحظات:', notes),
                  _buildInfoRow(
                    Icons.check_circle,
                    'الحالة:',
                    isCompleted ? 'مكتملة' : 'قيد التنفيذ',
                    valueColor: isCompleted ? Colors.green : Colors.orange,
                  ),
                  if (targetCount > 0)
                    _buildInfoRow(Icons.track_changes, 'التقدم الإجمالي:',
                        '$currentCount / $targetCount'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // --- قسم الموظفين المسند إليهم ---
          Text('الفنيين المسند إليهم', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user_tasks')
                .where('taskId', isEqualTo: task['id'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CustomLoadingIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('لم يتم إسناد هذه المهمة لأي فني.'));
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final userTask =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final userId = userTask['userId'];
                  final bool userTaskCompleted =
                      userTask['isCompleted'] ?? false;

                  return FutureBuilder<String>(
                    future: _getUserName(userId),
                    builder: (context, nameSnapshot) {
                      if (nameSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const ListTile(
                            title: Text('جاري تحميل اسم الفني...'));
                      }

                      final userName = nameSnapshot.data ?? 'غير معروف';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(userName),
                          trailing: Icon(
                            userTaskCompleted
                                ? Icons.check_circle
                                : Icons.hourglass_top,
                            color: userTaskCompleted
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. الدوال المساعدة (Helper Functions) - (يمكن فصلها)
  // ===========================================================================

  /// دالة مساعدة لجلب اسم المستخدم بناءً على UID.
  Future<String> _getUserName(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return userDoc.data()?['fullName'] ?? 'مستخدم غير معروف';
    } catch (e) {
      return 'خطأ في جلب الاسم';
    }
  }

  /// ويدجت مساعد لبناء صف معلومات منسق.
  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
