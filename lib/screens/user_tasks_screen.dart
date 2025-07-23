import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// استيراد الموديلات مع إعطاء اسم مميز للثاني لتجنب التضارب
import '../models/task_model.dart';
import '../models/user_task_model.dart' as user_task_model; // <--- الحل هنا
import 'task_details_screen.dart';

class UserTasksScreen extends StatefulWidget {
  const UserTasksScreen({super.key});

  @override
  State<UserTasksScreen> createState() => _UserTasksScreenState();
}

class _UserTasksScreenState extends State<UserTasksScreen> {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مهامي'),
      ),
      body: userId == null
          ? const Center(child: Text('المستخدم غير مسجل دخوله. يرجى إعادة تسجيل الدخول.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_tasks')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('حدث خطأ في جلب المهام.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('لا توجد مهام مسندة حالياً.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final userTaskDoc = snapshot.data!.docs[index];
                    // استخدام الاسم المميز للوصول إلى الموديل الصحيح
                    final userTask = user_task_model.UserTaskModel.fromMap( // <--- الحل هنا
                        userTaskDoc.data() as Map<String, dynamic>);
                    
                    return _buildTaskCard(userTask);
                  },
                );
              },
            ),
    );
  }

  // استخدام الاسم المميز في نوع المتغير
  Widget _buildTaskCard(user_task_model.UserTaskModel userTask) { // <--- الحل هنا
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('tasks')
          .doc(userTask.taskId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: ListTile(
              title: Text('جاري تحميل المهمة...'),
              subtitle: SizedBox(height: 10, child: LinearProgressIndicator()),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const Card(
            color: Colors.grey,
            child: ListTile(
              title: Text('تعذر تحميل بيانات المهمة'),
              subtitle: Text('قد تكون المهمة قد حُذفت.'),
            ),
          );
        }

        final taskData = snapshot.data!.data() as Map<String, dynamic>;
        // هنا نستخدم TaskModel من الملف الأول وهو صحيح
        final task = TaskModel.fromMap(taskData);

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            title: Text(
              task.typeDisplayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                task.notes.isEmpty ? 'لا توجد ملاحظات' : task.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: Icon(
              userTask.isCompleted ? Icons.check_circle : Icons.hourglass_top_rounded,
              color: userTask.isCompleted ? Colors.green : Colors.orange,
              size: 28,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskDetailsScreen(
                    taskId: userTask.taskId,
                    userTaskId: userTask.id,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
