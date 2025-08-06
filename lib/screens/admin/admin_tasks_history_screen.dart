import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_task_details_screen.dart';
import '../../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

class AdminTasksHistoryScreen extends StatefulWidget {
  const AdminTasksHistoryScreen({super.key});

  @override
  State<AdminTasksHistoryScreen> createState() =>
      _AdminTasksHistoryScreenState();
}

class _AdminTasksHistoryScreenState extends State<AdminTasksHistoryScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  List<Map<String, dynamic>> _allTasks = [];
  List<Map<String, dynamic>> _filteredTasks = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus; // 'completed', 'in_progress'

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _searchController.addListener(_filterTasks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المهام'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
            tooltip: 'تصفية',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CustomLoadingIndicator())
                : _filteredTasks.isEmpty
                    ? const Center(child: Text('لا توجد مهام تطابق البحث.'))
                    : RefreshIndicator(
                        onRefresh: _loadTasks,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _filteredTasks.length,
                          itemBuilder: (context, index) {
                            return _buildTaskCard(_filteredTasks[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي (Core Business Logic)
  // ===========================================================================

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // *** [تم التصحيح] *** تحديد نوع البيانات للاستعلام
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('tasks')
              .where('createdBy', isEqualTo: adminId)
              .orderBy('createdAt', descending: true)
              .get();

      if (mounted) {
        setState(() {
          _allTasks = snapshot.docs.map((doc) =>
              // *** [تم التصحيح] *** إزالة التحويل غير الضروري
              {'id': doc.id, ...doc.data()}).toList();
          _isLoading = false;
        });
        _filterTasks();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المهام: $e')),
        );
      }
    }
  }

  void _filterTasks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTasks = _allTasks.where((task) {
        final matchesSearch = (task['typeDisplayName'] as String? ?? '')
                .toLowerCase()
                .contains(query) ||
            (task['notes'] as String? ?? '').toLowerCase().contains(query) ||
            (task['college'] as String? ?? '').toLowerCase().contains(query);

        final bool isTaskCompleted = _isTaskConsideredComplete(task);

        final matchesStatus = _selectedStatus == null ||
            (_selectedStatus == 'completed' && isTaskCompleted) ||
            (_selectedStatus == 'in_progress' && !isTaskCompleted);

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تصفية حسب الحالة',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  RadioListTile<String?>(
                    title: const Text('الكل'),
                    value: null,
                    groupValue: _selectedStatus,
                    onChanged: (value) {
                      setModalState(() => _selectedStatus = value);
                    },
                  ),
                  RadioListTile<String?>(
                    title: const Text('مكتملة'),
                    value: 'completed',
                    groupValue: _selectedStatus,
                    onChanged: (value) {
                      setModalState(() => _selectedStatus = value);
                    },
                  ),
                  RadioListTile<String?>(
                    title: const Text('قيد التنفيذ'),
                    value: 'in_progress',
                    groupValue: _selectedStatus,
                    onChanged: (value) {
                      setModalState(() => _selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    child: const Text('تطبيق'),
                    onPressed: () {
                      _filterTasks();
                      Navigator.pop(context);
                    },
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 5. دوال بناء مكونات الواجهة المساعدة (UI Helper Widgets)
  // ===========================================================================

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'البحث في المهام...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final bool isCompleted = _isTaskConsideredComplete(task);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: ListTile(
        title: Text(task['typeDisplayName'] ?? 'مهمة'),
        subtitle: Text(task['college'] ?? 'كلية غير محددة'),
        trailing: Icon(
          isCompleted ? Icons.check_circle : Icons.hourglass_top,
          color: isCompleted ? Colors.green : Colors.orange,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminTaskDetailsScreen(task: task),
            ),
          ).then((_) => _loadTasks());
        },
      ),
    );
  }

  // ===========================================================================
  // 6. الدوال المساعدة (Helper Functions)
  // ===========================================================================

  bool _isTaskConsideredComplete(Map<String, dynamic> task) {
    if (task['isCompleted'] == true) {
      return true;
    }
    if (task['completedAt'] != null) {
      return true;
    }
    final percentage =
        (task['completionPercentage'] as num?)?.toDouble() ?? 0.0;
    if (percentage >= 100.0) {
      return true;
    }

    return false;
  }
}
