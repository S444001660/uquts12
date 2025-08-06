import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/permissions_service.dart';
import 'create_user_screen.dart';
import 'employee_details_screen.dart';
import '../../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen>
    with TickerProviderStateMixin {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  List<Map<String, dynamic>> _allEmployees = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'all';

  late TabController _tabController;

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPermissions();
    _loadEmployees();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('إدارة الحسابات'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: ' الفنيين'),
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
            tooltip: 'إضافة حساب جديد',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllEmployeesTab(),
          _buildStatisticsTab(),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي (Core Business Logic)
  // ===========================================================================

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('users').where('role',
              whereIn: ['technician', 'supervisor', 'admin']).get();

      if (mounted) {
        setState(() {
          _allEmployees = snapshot.docs.map((doc) {
            // *** [تم التصحيح] *** إزالة التحويل غير الضروري
            final data = doc.data();
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();

          _allEmployees
              .sort((a, b) => (b['points'] ?? 0).compareTo(a['points'] ?? 0));

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('خطأ في تحميل قائمة الفنيين: $e');
      }
    }
  }

  Future<void> _toggleEmployeeStatus(String employeeId, bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(employeeId)
          .update({'isActive': !isActive});

      _showSuccessSnackBar(
          isActive ? 'تم إلغاء تفعيل الفني' : 'تم تفعيل الفني');
      _loadEmployees();
    } catch (e) {
      _showErrorSnackBar('خطأ في تحديث حالة الفني: $e');
    }
  }

  // ===========================================================================
  // 5. دوال بناء مكونات الواجهة المساعدة (UI Helper Widgets)
  // ===========================================================================

  Widget _buildAllEmployeesTab() {
    final List<Map<String, dynamic>> filteredList = _filteredEmployees;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'البحث بالاسم, الايميل, أو رقم الفني...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
              ? const Center(child: CustomLoadingIndicator())
              : filteredList.isEmpty
                  ? const Center(child: Text('لا يوجد فنيون يطابقون البحث'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final employee = filteredList[index];
                        final rank = _allEmployees
                                .indexWhere((e) => e['id'] == employee['id']) +
                            1;
                        return _buildEmployeeCard(employee, rank);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStatisticsTab() {
    if (_isLoading) return const Center(child: CustomLoadingIndicator());

    final totalEmployees = _allEmployees.length;
    final activeEmployees =
        _allEmployees.where((emp) => emp['isActive'] == true).length;

    final totalPoints = _allEmployees.fold<int>(
      0,
      (total, emp) => total + ((emp['points'] ?? 0) as num).toInt(),
    );

    final completedTasks = _allEmployees.fold<int>(
      0,
      (total, emp) => total + ((emp['tasksCompleted'] ?? 0) as num).toInt(),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          _buildStatCard(
              'إجمالي الفنين', totalEmployees.toString(), Icons.people),
          _buildStatCard(
              'الفنين النشطين', activeEmployees.toString(), Icons.person),
          _buildStatCard(
              'إجمالي النقاط المكتسبة', totalPoints.toString(), Icons.star),
          _buildStatCard('إجمالي المهام المكتملة', completedTasks.toString(),
              Icons.task_alt),
        ],
      ),
    );
  }

  /// *** [تم التحديث النهائي] *** بناء بطاقة الموظف مع استخدام لون الدور.
  Widget _buildEmployeeCard(Map<String, dynamic> employee, int rank) {
    final bool isActive = employee['isActive'] ?? true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        side: BorderSide(
            color: isActive ? Colors.transparent : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EmployeeDetailsScreen(employeeData: employee),
            ),
          );
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                _getRoleColor(employee['role']), // <-- تم الاستفادة منها هنا
            child: Text(
              '$rank',
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
              Text('رقم الفني: ${employee['employeeId'] ?? 'غير محدد'}'),
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_getRankIcon(rank) != null) _getRankIcon(rank)!,
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: () =>
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                      _toggleEmployeeStatus(employee['id'], isActive);
                    }),
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
            ],
          ),
          tileColor: isActive ? null : Colors.grey[100],
        ),
      ),
    );
  }

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

  // ===========================================================================
  // 6. دوال مساعدة (Helper Functions)
  // ===========================================================================

  Future<void> _checkPermissions() async {
    final hasPermission =
        await PermissionsService.hasPermission('manage_users');
    if (!hasPermission && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ليس لديك صلاحية للوصول إلى إدارة الحسابات'),
          backgroundColor: Colors.red,
        ),
      );
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
      final query = _searchController.text.toLowerCase();

      final matchesSearch = fullName.contains(query) ||
          email.contains(query) ||
          employeeId.contains(query);

      final matchesRole =
          _selectedRole == 'all' || employee['role'] == _selectedRole;

      return matchesSearch && matchesRole;
    }).toList();
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
