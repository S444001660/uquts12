import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/device_form_constants.dart'; // <-- [تمت الإضافة] استيراد قائمة الكليات الموحدة
import '../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

// تعريف أنواع المهام لتسهيل التعامل معها
enum TaskType { inspection, setup, maintenance, deviceRegistration, other }

class ImprovedAddTaskScreen extends StatefulWidget {
  const ImprovedAddTaskScreen({super.key});

  @override
  State<ImprovedAddTaskScreen> createState() => _ImprovedAddTaskScreenState();
}

class _ImprovedAddTaskScreenState extends State<ImprovedAddTaskScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  final _formKey = GlobalKey<FormState>();
  TaskType _selectedTaskType = TaskType.deviceRegistration;
  String? _selectedCollege;
  String _notes = '';
  List<String> _assignedTechnicians = [];
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoading = false;
  int _targetCount = 1;
  String _searchQuery = '';

  // --- [تم الحذف] --- لم نعد بحاجة لهذه القائمة المكررة
  // final List<String> _colleges = [ ... ];

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  // ===========================================================================
  // 3. منطق العمل الرئيسي (Core Business Logic)
  // ===========================================================================

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate() || _assignedTechnicians.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('يرجى تعبئة جميع الحقول واختيار موظف واحد على الأقل')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final batch = FirebaseFirestore.instance.batch();

    try {
      final taskId = const Uuid().v4();
      final currentUser = FirebaseAuth.instance.currentUser;

      final taskRef =
          FirebaseFirestore.instance.collection('tasks').doc(taskId);
      final taskData = {
        'id': taskId,
        'type': _selectedTaskType.name,
        'typeDisplayName': _getTaskTypeDisplayName(_selectedTaskType),
        'college': _selectedCollege,
        'assignedTo': _assignedTechnicians,
        'notes': _notes,
        'targetCount': _selectedTaskType == TaskType.deviceRegistration
            ? _targetCount
            : null,
        'currentCount': 0,
        'isCompleted': false,
        'completionPercentage': 0.0,
        'createdAt': Timestamp.now(),
        'createdBy': currentUser?.uid,
        'completedAt': null,
      };
      batch.set(taskRef, taskData);

      for (String userId in _assignedTechnicians) {
        final individualTaskId = const Uuid().v4();
        final userTaskRef = FirebaseFirestore.instance
            .collection('user_tasks')
            .doc(individualTaskId);
        batch.set(userTaskRef, {
          'id': individualTaskId,
          'taskId': taskId,
          'userId': userId,
          'isCompleted': false,
          'progress': 0,
          'assignedAt': Timestamp.now(),
          'completedAt': null,
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم إنشاء المهمة بنجاح'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء إنشاء المهمة: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ===========================================================================
  // 4. دالة بناء واجهة المستخدم (UI Build Method)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _availableUsers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('إسناد مهمة جديدة')),
        body: const Center(child: CustomLoadingIndicator()),
      );
    }

    final filteredUsers = _availableUsers.where((user) {
      final fullName = user['fullName']?.toLowerCase() ?? '';
      final employeeId = user['employeeId']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return fullName.contains(query) || employeeId.contains(query);
    }).toList();

    final allFilteredSelected = filteredUsers.isNotEmpty &&
        filteredUsers
            .every((user) => _assignedTechnicians.contains(user['id']));

    return Scaffold(
      appBar: AppBar(title: const Text('إسناد مهمة جديدة')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<TaskType>(
                    value: _selectedTaskType,
                    items: TaskType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getTaskTypeDisplayName(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedTaskType = value);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'نوع المهمة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- [تم التحديث] --- استخدام القائمة الموحدة من الثوابت
                  DropdownButtonFormField<String>(
                    value: _selectedCollege,
                    // استخدام DeviceFormConstants.colleges مباشرة
                    items: DeviceFormConstants.colleges.map((college) {
                      return DropdownMenuItem(
                        value: college,
                        child: Text(college),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCollege = value),
                    decoration: const InputDecoration(
                      labelText: 'الكلية',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null ? 'يرجى اختيار الكلية' : null,
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
                      validator: (val) {
                        if (val == null ||
                            val.isEmpty ||
                            (int.tryParse(val) ?? 0) <= 0) {
                          return 'يرجى إدخال عدد صحيح أكبر من صفر';
                        }
                        return null;
                      },
                    ),
                  if (_selectedTaskType == TaskType.deviceRegistration)
                    const SizedBox(height: 16),
                  TextFormField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات المهمة',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _notes = val,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'إسناد إلى:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'بحث عن موظف بالاسم أو رقم الفني',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView(
                      children: [
                        if (filteredUsers.isNotEmpty)
                          CheckboxListTile(
                            title: const Text('تحديد كل الفنيين الظاهرين',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            value: allFilteredSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                final filteredUserIds = filteredUsers
                                    .map((u) => u['id'] as String)
                                    .toList();
                                if (value == true) {
                                  _assignedTechnicians.addAll(filteredUserIds);
                                  _assignedTechnicians =
                                      _assignedTechnicians.toSet().toList();
                                } else {
                                  _assignedTechnicians.removeWhere(
                                      (id) => filteredUserIds.contains(id));
                                }
                              });
                            },
                          ),
                        if (filteredUsers.isNotEmpty) const Divider(height: 1),
                        ...filteredUsers.map((user) {
                          final isSelected =
                              _assignedTechnicians.contains(user['id']);
                          return CheckboxListTile(
                            title: Text(user['fullName']),
                            subtitle: Text('رقم الفني: ${user['employeeId']}'),
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
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _createTask,
                    icon: const Icon(Icons.send),
                    label: const Text('إسناد المهمة'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(128),
              child: const Center(
                child: CustomLoadingIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. الدوال المساعدة (Helper Functions)
  // ===========================================================================

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isActive', isEqualTo: true)
          .where('role', whereIn: ['technician', 'supervisor']).get();

      if (!mounted) return;

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
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المستخدمين: $e')),
        );
      }
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
}
