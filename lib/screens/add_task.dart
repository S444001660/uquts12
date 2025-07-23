// screens/improved_add_task_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  int _targetCount = 1; // للمهام التي تتطلب عدد معين (مثل تسجيل أجهزة)

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
      // جلب جميع المستخدمين النشطين
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isActive', isEqualTo: true)
          .where('role', whereIn: ['technician', 'supervisor']) // فقط الفنيين والمشرفين
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
        SnackBar(content: Text('خطأ في تحميل قائمة المستخدمين: $e')),
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
      
      // إنشاء المهمة الأساسية
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
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'completedAt': null,
      };

      await FirebaseFirestore.instance.collection('tasks').doc(taskId).set(taskData);

      // إنشاء مهمة فردية لكل موظف مُسند إليه
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
        const SnackBar(
          content: Text('تم إنشاء المهمة وإسنادها بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في إنشاء المهمة: $e')),
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
      appBar: AppBar(
        title: const Text('إسناد مهمة جديدة'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // نوع المهمة
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نوع المهمة',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...TaskType.values.map((type) => RadioListTile<TaskType>(
                        title: Text(_getTaskTypeDisplayName(type)),
                        value: type,
                        groupValue: _selectedTaskType,
                        onChanged: (value) => setState(() => _selectedTaskType = value!),
                      )),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),

              // الكلية
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'اختر الكلية',
                  border: OutlineInputBorder(),
                ),
                value: _selectedCollege,
                items: _colleges.map((college) => DropdownMenuItem(
                  value: college,
                  child: Text(college),
                )).toList(),
                onChanged: (value) => setState(() => _selectedCollege = value),
                validator: (value) => value == null ? 'الرجاء اختيار الكلية' : null,
              ),

              const SizedBox(height: 16),

              // الهدف المطلوب (للمهام القابلة للقياس)
              if (_selectedTaskType == TaskType.deviceRegistration)
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'عدد الأجهزة المطلوب تسجيلها',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: _targetCount.toString(),
                  onChanged: (value) => _targetCount = int.tryParse(value) ?? 1,
                  validator: (value) {
                    final number = int.tryParse(value ?? '');
                    if (number == null || number <= 0) {
                      return 'يرجى إدخال رقم صحيح أكبر من صفر';
                    }
                    return null;
                  },
                ),

              const SizedBox(height: 16),

              // قائمة الموظفين
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'إسناد المهمة إلى:',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'المحدد: ${_assignedTechnicians.length}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // شريط البحث
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'بحث عن موظف...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),

                      const SizedBox(height: 12),

                      // أزرار التحديد السريع
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _assignedTechnicians = _availableUsers
                                    .map((user) => user['id'] as String)
                                    .toList();
                              });
                            },
                            child: const Text('تحديد الكل'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _assignedTechnicians.clear()),
                            child: const Text('إلغاء التحديد'),
                          ),
                        ],
                      ),

                      // قائمة الموظفين
                      SizedBox(
                        height: 300,
                        child: ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final isSelected = _assignedTechnicians.contains(user['id']);
                            
                            return Card(
                              color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _assignedTechnicians.add(user['id']);
                                    } else {
                                      _assignedTechnicians.remove(user['id']);
                                    }
                                  });
                                },
                                title: Text(user['fullName']),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('رقم الموظف: ${user['employeeId']}'),
                                    Text('القسم: ${user['department']}'),
                                    Text('النقاط: ${user['points']}', 
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                secondary: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  child: Text(
                                    user['fullName'][0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // الملاحظات
              TextFormField(
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات وتفاصيل المهمة',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _notes = value,
              ),

              const SizedBox(height: 24),

              // زر الإرسال
              ElevatedButton.icon(
                onPressed: _createTask,
                icon: const Icon(Icons.send),
                label: const Text('إسناد المهمة'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}