import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';

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
          ? const Center(child: Text('المستخدم غير مسجل دخوله'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_tasks')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('لا توجد مهام مسندة حالياً.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final userTaskDoc = snapshot.data!.docs[index];
                    final userTask = UserTaskModel.fromMap(
                        userTaskDoc.data() as Map<String, dynamic>);
                    return _buildTaskCard(userTask);
                  },
                );
              },
            ),
    );
  }

  Widget _buildTaskCard(UserTaskModel userTask) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('tasks')
          .doc(userTask.taskId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
              child: ListTile(title: Text('جاري تحميل تفاصيل المهمة...')));
        }
        final mainTask =
            TaskModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);
        final progress =
            (mainTask.targetCount != null && mainTask.targetCount! > 0)
                ? (userTask.progress / mainTask.targetCount!)
                : (userTask.isCompleted ? 1.0 : 0.0);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mainTask.typeDisplayName,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (mainTask.college != null)
                  Text('الكلية: ${mainTask.college}'),
                if (mainTask.notes.isNotEmpty)
                  Text('ملاحظات: ${mainTask.notes}'),
                const SizedBox(height: 16),
                if (mainTask.targetCount != null)
                  Text(
                      'التقدم: ${userTask.progress} / ${mainTask.targetCount}'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    userTask.isCompleted ? 'اكتملت' : 'قيد التنفيذ',
                    style: TextStyle(
                      color:
                          userTask.isCompleted ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
