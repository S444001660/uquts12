// screens/admin/employee_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/permissions_service.dart';
import 'create_user_screen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRole = 'all';
  List<Map<String, dynamic>> _allEmployees = [];
  bool _isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkPermissions();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final hasPermission =
        await PermissionsService.hasPermission('manage_users');
    if (!hasPermission && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ليس لديك صلاحية للوصول إلى إدارة الموظفين'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _allEmployees = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('خطأ في تحميل قائمة الموظفين: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    return _allEmployees.where((employee) {
      final fullName = employee['fullName']?.toString().toLowerCase() ?? '';
      final email = employee['email']?.toString().toLowerCase() ?? '';
      final employeeId = employee['employeeId']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      final matchesSearch = fullName.contains(query) ||
          email.contains(query) ||
          employeeId.contains(query);

      final matchesRole =
          _selectedRole == 'all' || employee['role'] == _selectedRole;

      return matchesSearch && matchesRole;
    }).toList();
  }

  Future<void> _toggleEmployeeStatus(String employeeId, bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(employeeId)
          .update({'isActive': !isActive});

      _showSuccessSnackBar(
          isActive ? 'تم إلغاء تفعيل الموظف' : 'تم تفعيل الموظف');
      _loadEmployees();
    } catch (e) {
      _showErrorSnackBar('خطأ في تحديث حالة الموظف: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('إدارة الموظفين'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'جميع الموظفين'),
            Tab(icon: Icon(Icons.star), text: 'أفضل الموظفين'),
            Tab(icon: Icon(Icons.analytics), text: 'الإحصائيات'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateUserScreen()),
            ).then((_) => _loadEmployees()),
            icon: const Icon(Icons.person_add),
            tooltip: 'إضافة موظف جديد',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllEmployeesTab(),
          _buildTopEmployeesTab(),
          _buildStatisticsTab(),
        ],
      ),
    );
  }

  Widget _buildAllEmployeesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'البحث بالاسم, الايميل, أو الرقم الوظيفي...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('فلترة حسب الدور: '),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('الكل')),
                        DropdownMenuItem(value: 'admin', child: Text('مدير')),
                        DropdownMenuItem(
                            value: 'supervisor', child: Text('مشرف')),
                        DropdownMenuItem(
                            value: 'technician', child: Text('فني')),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedRole = value!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredEmployees.isEmpty
                  ? const Center(child: Text('لا يوجد موظفون يطابقون البحث'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final employee = _filteredEmployees[index];
                        return _buildEmployeeCard(employee);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> employee) {
    final bool isActive = employee['isActive'] ?? true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: isActive ? Colors.transparent : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(employee['role']),
          child: Text(
            employee['fullName']?[0]?.toUpperCase() ?? '؟',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          employee['fullName'] ?? 'غير محدد',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? null : Colors.grey,
            decoration: isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${employee['email'] ?? 'غير محدد'}'),
            Text('رقم الموظف: ${employee['employeeId'] ?? 'غير محدد'}'),
            Text('الدور: ${_getRoleDisplayName(employee['role'])}'),
            Text(
              'النقاط: ${employee['points'] ?? 0}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: () => _toggleEmployeeStatus(employee['id'], isActive),
              child: Row(
                children: [
                  Icon(isActive ? Icons.block : Icons.check_circle,
                      color: isActive ? Colors.red : Colors.green),
                  const SizedBox(width: 8),
                  Text(isActive ? 'إلغاء التفعيل' : 'تفعيل'),
                ],
              ),
            ),
          ],
        ),
        tileColor: isActive ? null : Colors.grey[100],
      ),
    );
  }

  Widget _buildTopEmployeesTab() {
    final topEmployees = List<Map<String, dynamic>>.from(_allEmployees)
      ..sort((a, b) => (b['points'] ?? 0).compareTo(a['points'] ?? 0));

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: topEmployees.length > 10 ? 10 : topEmployees.length,
            itemBuilder: (context, index) {
              final employee = topEmployees[index];
              final rank = index + 1;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getRankColor(rank),
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(employee['fullName'] ?? 'غير محدد'),
                  subtitle: Text('${employee['points'] ?? 0} نقطة'),
                  trailing: _getRankIcon(rank),
                ),
              );
            },
          );
  }

  // ====================== تم إصلاح الخطأ هنا ======================
  Widget _buildStatisticsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final totalEmployees = _allEmployees.length;
    final activeEmployees =
        _allEmployees.where((emp) => emp['isActive'] == true).length;

    // تم التعديل هنا: تحويل القيمة إلى int بشكل آمن
    final totalPoints = _allEmployees.fold<int>(
        0, (sum, emp) => sum + ((emp['points'] ?? 0) as num).toInt());

    // تم التعديل هنا: تحويل القيمة إلى int بشكل آمن
    final completedTasks = _allEmployees.fold<int>(
        0, (sum, emp) => sum + ((emp['tasksCompleted'] ?? 0) as num).toInt());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _buildStatCard(
              'إجمالي الموظفين', totalEmployees.toString(), Icons.people),
          _buildStatCard(
              'الموظفين النشطين', activeEmployees.toString(), Icons.person),
          _buildStatCard(
              'إجمالي النقاط المكتسبة', totalPoints.toString(), Icons.star),
          _buildStatCard('إجمالي المهام المكتملة', completedTasks.toString(),
              Icons.task_alt),
        ],
      ),
    );
  }
  // =================================================================

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'supervisor':
        return Colors.orange;
      case 'technician':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String? role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'supervisor':
        return 'مشرف';
      case 'technician':
        return 'فني';
      default:
        return 'غير محدد';
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey.shade600;
      case 3:
        return Colors.brown.shade400;
      default:
        return Colors.blueGrey;
    }
  }

  Widget? _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return const Icon(Icons.emoji_events, color: Colors.amber, size: 32);
      case 2:
        return Icon(Icons.emoji_events, color: Colors.grey.shade600, size: 28);
      case 3:
        return Icon(Icons.emoji_events, color: Colors.brown.shade400, size: 24);
      default:
        return null;
    }
  }
}
