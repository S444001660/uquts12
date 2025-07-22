import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;
  final String userTaskId;

  const TaskDetailsScreen({
    super.key,
    required this.taskId,
    required this.userTaskId,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  Map<String, dynamic>? taskData;
  Map<String, dynamic>? userTaskData;
  File? proofImage;
  final TextEditingController noteController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final taskSnap = await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.taskId)
        .get();
    final userTaskSnap = await FirebaseFirestore.instance
        .collection('user_tasks')
        .doc(widget.userTaskId)
        .get();

    setState(() {
      taskData = taskSnap.data();
      userTaskData = userTaskSnap.data();
      isLoading = false;
    });
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        proofImage = File(picked.path);
      });
    }
  }

  Future<String?> uploadProofImage(String taskId, String userTaskId) async {
    if (proofImage == null) return null;

    final fileName = '$userTaskId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('task_proofs')
        .child(taskId)
        .child(fileName);

    await ref.putFile(proofImage!);
    return await ref.getDownloadURL();
  }

  Future<void> completeTask() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    final proofUrl = await uploadProofImage(widget.taskId, widget.userTaskId);
    final note = noteController.text;

    await FirebaseFirestore.instance
        .collection('user_tasks')
        .doc(widget.userTaskId)
        .update({
      'isCompleted': true,
      'completedAt': Timestamp.now(),
      'proofImages': proofUrl != null ? [proofUrl] : [],
      'completionNote': note,
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'points': FieldValue.increment(3),
    });

    if (mounted) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إكمال المهمة بنجاح')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || taskData == null || userTaskData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isCompleted = userTaskData!['isCompleted'] == true;
    final note = userTaskData!['completionNote'] ?? '';
    final proofImages = (userTaskData!['proofImages'] ?? []) as List;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المهمة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _infoTile('نوع المهمة', taskData!['typeDisplayName']),
            _infoTile('الوصف', taskData!['notes']),
            const SizedBox(height: 16),
            if (isCompleted) ...[
              _infoTile('ملاحظات الفني', note.isEmpty ? 'لا توجد' : note),
              if (proofImages.isNotEmpty) ...[
                const Text('صور الإثبات:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: proofImages.map<Widget>((url) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ] else ...[
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظاتك',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (proofImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(proofImage!, height: 200),
                )
              else
                const Text('لم يتم اختيار صورة بعد'),
              TextButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('إرفاق صورة إثبات'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: completeTask,
                icon: const Icon(Icons.check),
                label: const Text('إكمال المهمة'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 4),
        Text(
          value?.toString() ?? '---',
          textAlign: TextAlign.right,
        ),
        const Divider(),
      ],
    );
  }
}
