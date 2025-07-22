import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart';
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.data() == null) {
          return const SizedBox(
            height: 80,
            child: Center(child: Text('تعذر تحميل بيانات المهمة')),
          );
        }

        final taskData = snapshot.data!.data() as Map<String, dynamic>;
        final task = TaskModel.fromMap(taskData);

        return InkWell(
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
          child: Card(
            child: ListTile(
              title: Text(task.typeDisplayName),
              subtitle: Text(task.notes),
              trailing: Icon(
                userTask.isCompleted ? Icons.check : Icons.pending,
                color: userTask.isCompleted ? Colors.green : Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }
}
