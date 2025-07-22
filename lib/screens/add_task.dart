import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/permissions_service.dart';
import '../models/task_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum TaskType { inspection, setup, maintenance, deviceRegistration, other }

class ImprovedAddTaskScreen extends StatefulWidget {
  const ImprovedAddTaskScreen({super.key});

  @override
  State<ImprovedAddTaskScreen> createState() => _ImprovedAddTaskScreenState();
}

class _ImprovedAddTaskScreenState extends State<ImprovedAddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  TaskType _selectedTaskType = TaskType.deviceRegistration;
  String? _selectedCollege;
  String _notes = '';
  List<String> _assignedTechnicians = [];
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoading = false;
  int _targetCount = 1;

  final List<String> _colleges = [
    'كلية الحاسب',
    'كلية الهندسة',
    'كلية العلوم',
    'كلية الطب',
    'كلية الإدارة والاقتصاد'
  ];

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isActive', isEqualTo: true)
          .where('role', whereIn: ['technician', 'supervisor'])
          .get();

      setState(() {
        _availableUsers = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'fullName': data['fullName'] ?? 'مستخدم غير معروف',
            'employeeId': data['employeeId'] ?? '',
            'department': data['department'] ?? '',
            'role': data['role'] ?? 'technician',
            'points': data['points'] ?? 0,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل المستخدمين: $e')),
      );
    }
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate() || _assignedTechnicians.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تعبئة جميع الحقول واختيار موظف واحد على الأقل')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final taskId = const Uuid().v4();
      final currentUser = FirebaseAuth.instance.currentUser;
      final taskData = {
        'id': taskId,
        'type': _selectedTaskType.name,
        'typeDisplayName': _getTaskTypeDisplayName(_selectedTaskType),
        'college': _selectedCollege,
        'assignedTo': _assignedTechnicians,
        'notes': _notes,
        'targetCount': _selectedTaskType == TaskType.deviceRegistration ? _targetCount : null,
        'currentCount': 0,
        'isCompleted': false,
        'completionPercentage': 0.0,
        'createdAt': Timestamp.now(),
        'createdBy': currentUser?.uid,
        'completedAt': null,
      };

      await FirebaseFirestore.instance.collection('tasks').doc(taskId).set(taskData);

      for (String userId in _assignedTechnicians) {
        final individualTaskId = const Uuid().v4();
        await FirebaseFirestore.instance
            .collection('user_tasks')
            .doc(individualTaskId)
            .set({
          'id': individualTaskId,
          'taskId': taskId,
          'userId': userId,
          'isCompleted': false,
          'progress': 0,
          'assignedAt': Timestamp.now(),
          'completedAt': null,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء المهمة بنجاح'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getTaskTypeDisplayName(TaskType type) {
    switch (type) {
      case TaskType.inspection:
        return 'فحص';
      case TaskType.setup:
        return 'تجهيز';
      case TaskType.maintenance:
        return 'صيانة';
      case TaskType.deviceRegistration:
        return 'تسجيل أجهزة';
      case TaskType.other:
        return 'أخرى';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final filteredUsers = _availableUsers.where((user) {
      return user['fullName'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user['employeeId'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('إسناد مهمة جديدة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // نوع المهمة
              DropdownButtonFormField<TaskType>(
                value: _selectedTaskType,
                items: TaskType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getTaskTypeDisplayName(type)),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedTaskType = value!),
                decoration: const InputDecoration(
                  labelText: 'نوع المهمة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // الكلية
              DropdownButtonFormField<String>(
                value: _selectedCollege,
                items: _colleges.map((college) {
                  return DropdownMenuItem(
                    value: college,
                    child: Text(college),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedCollege = value),
                decoration: const InputDecoration(
                  labelText: 'الكلية',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? 'يرجى اختيار الكلية' : null,
              ),
              const SizedBox(height: 16),

              if (_selectedTaskType == TaskType.deviceRegistration)
                TextFormField(
                  initialValue: _targetCount.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد الأجهزة المطلوب تسجيلها',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _targetCount = int.tryParse(val) ?? 1,
                ),
              const SizedBox(height: 16),

              // الملاحظات
              TextFormField(
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات المهمة',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => _notes = val,
              ),
              const SizedBox(height: 16),

              // البحث واختيار الموظفين
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'بحث عن موظف',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 8),
              ...filteredUsers.map((user) {
                final isSelected = _assignedTechnicians.contains(user['id']);
                return CheckboxListTile(
                  title: Text(user['fullName']),
                  subtitle: Text('رقم الموظف: ${user['employeeId']}'),
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _assignedTechnicians.add(user['id']);
                      } else {
                        _assignedTechnicians.remove(user['id']);
                      }
                    });
                  },
                );
              }).toList(),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _createTask,
                icon: const Icon(Icons.send),
                label: const Text('إسناد المهمة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
