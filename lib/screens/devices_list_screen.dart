import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../services/firebase_database_service.dart';
import '../utils/device_form_constants.dart';
import '../utils/ui_helpers.dart';
import 'add_device_screen.dart';
import 'view_device_screen.dart';
import '../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

//------------------------------------------------------------------------------

class DevicesListScreen extends StatefulWidget {
  const DevicesListScreen({super.key});

  @override
  State<DevicesListScreen> createState() => _DevicesListScreenState();
}

//------------------------------------------------------------------------------

class _DevicesListScreenState extends State<DevicesListScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  static const double _defaultPadding = 16.0;
  static const double _iconSize = 64.0;

  List<DeviceModel> _allDevices = [];
  List<DeviceModel> _filteredDevices = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String? _selectedCollege;
  String? _selectedDepartment;
  bool? _selectedNeedsMaintenance;

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _searchController.addListener(_filterDevices);
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الأجهزة'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterBottomSheet),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AddDeviceScreen()))
                .then((_) => _loadDevices()),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(theme),
          Expanded(child: _buildDevicesList(theme)),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي (Core Business Logic)
  // ===========================================================================

  /// *** [تم التحديث] *** دالة لتحميل الأجهزة وفرزها حسب الأحدث.
  Future<void> _loadDevices() async {
    try {
      setState(() => _isLoading = true);
      final devices = await FirebaseDatabaseService.getDevices();
      if (!mounted) return;

      // --- [إضافة جديدة] --- فرز القائمة حسب تاريخ الإنشاء (الأحدث أولاً)
      devices.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _allDevices = devices;
        _isLoading = false;
      });
      _filterDevices(); // تطبيق الفلاتر المبدئية بعد تحميل البيانات.
    } catch (e) {
      _handleLoadError(e); // معالجة أي خطأ يحدث أثناء التحميل.
    }
  }

  /// دالة التصفية المحورية التي يتم استدعاؤها عند أي تغيير في البحث أو الفلاتر.
  void _filterDevices() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDevices = _allDevices.where((device) {
        final matchesSearch = device.name.toLowerCase().contains(query) ||
            device.model.toLowerCase().contains(query) ||
            device.serialNumber.toLowerCase().contains(query) ||
            device.college.toLowerCase().contains(query) ||
            device.department.toLowerCase().contains(query);

        final matchesCollege =
            _selectedCollege == null || device.college == _selectedCollege;
        final matchesDepartment = _selectedDepartment == null ||
            device.department == _selectedDepartment;
        final matchesMaintenance = _selectedNeedsMaintenance == null ||
            device.needsMaintenance == _selectedNeedsMaintenance;

        return matchesSearch &&
            matchesCollege &&
            matchesDepartment &&
            matchesMaintenance;
      }).toList();
    });
  }

  /// دالة لعرض ورقة سفلية (Bottom Sheet) تحتوي على خيارات التصفية.
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return DeviceFilterBottomSheet(
              scrollController: scrollController,
              initialSelectedCollege: _selectedCollege,
              initialSelectedDepartment: _selectedDepartment,
              initialSelectedNeedsMaintenance: _selectedNeedsMaintenance,
              onApplyFilters: (college, department, needsMaintenance) {
                setState(() {
                  _selectedCollege = college;
                  _selectedDepartment = department;
                  _selectedNeedsMaintenance = needsMaintenance;
                });
                _filterDevices();
              },
            );
          },
        );
      },
    );
  }

  /// دالة للانتقال إلى شاشة عرض الجهاز وتحديث القائمة عند العودة.
  void _navigateToDeviceView(DeviceModel device) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ViewDeviceScreen(device: device)),
    ).then((_) => _loadDevices());
  }

  // ===========================================================================
  // 5. الدوال المساعدة والويدجتات الفرعية (Helpers & Sub-Widgets)
  // ===========================================================================

  void _handleLoadError(dynamic error) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    UIHelpers.showSnackBar(
        context: context,
        message: 'خطأ في تحميل الأجهزة: $error',
        type: SnackBarType.error);
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(_defaultPadding),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'البحث في الأجهزة',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildDevicesList(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CustomLoadingIndicator());
    }
    if (_filteredDevices.isEmpty) {
      return _buildEmptyView(theme);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(_defaultPadding),
      itemCount: _filteredDevices.length,
      itemBuilder: (context, index) =>
          _buildDeviceItem(theme, _filteredDevices[index]),
    );
  }

  Widget _buildEmptyView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.computer_outlined,
              size: _iconSize, color: theme.colorScheme.primary.withAlpha(128)),
          const SizedBox(height: _defaultPadding),
          Text('لا توجد أجهزة تطابق البحث',
              style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(178))),
          const SizedBox(height: 8),
          Text('جرّب تغيير فلاتر البحث أو أضف جهازًا جديدًا',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(128))),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(ThemeData theme, DeviceModel device) {
    return Card(
      margin: const EdgeInsets.only(bottom: _defaultPadding),
      child: ListTile(
        leading:
            device.imagePath != null && device.imagePath!.startsWith('http')
                ? CircleAvatar(
                    backgroundImage: NetworkImage(device.imagePath!),
                    onBackgroundImageError: (exception, stackTrace) {
                      debugPrint('Error loading device image: $exception');
                    },
                  )
                : const CircleAvatar(
                    child: Icon(Icons.computer),
                  ),
        title: Text(device.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الموديل: ${device.model}'),
            Text('الرقم التسلسلي: ${device.serialNumber}'),
            Text('المعمل: ${device.college} - ${device.department}'),
          ],
        ),
        trailing: Icon(
          device.needsMaintenance ? Icons.build_circle : Icons.check_circle,
          color: device.needsMaintenance ? Colors.orange : Colors.green,
        ),
        onTap: () => _navigateToDeviceView(device),
      ),
    );
  }
}

//------------------------------------------------------------------------------
// ويدجت منفصل للـ Bottom Sheet
//------------------------------------------------------------------------------

class DeviceFilterBottomSheet extends StatefulWidget {
  final ScrollController scrollController;
  final String? initialSelectedCollege;
  final String? initialSelectedDepartment;
  final bool? initialSelectedNeedsMaintenance;
  final Function(String?, String?, bool?) onApplyFilters;

  const DeviceFilterBottomSheet({
    super.key,
    required this.scrollController,
    this.initialSelectedCollege,
    this.initialSelectedDepartment,
    this.initialSelectedNeedsMaintenance,
    required this.onApplyFilters,
  });

  @override
  State<DeviceFilterBottomSheet> createState() =>
      _DeviceFilterBottomSheetState();
}

class _DeviceFilterBottomSheetState extends State<DeviceFilterBottomSheet> {
  String? _tempSelectedCollege;
  String? _tempSelectedDepartment;
  bool? _tempSelectedNeedsMaintenance;

  @override
  void initState() {
    super.initState();
    _tempSelectedCollege = widget.initialSelectedCollege;
    _tempSelectedDepartment = widget.initialSelectedDepartment;
    _tempSelectedNeedsMaintenance = widget.initialSelectedNeedsMaintenance;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<String?> colleges = [null, ...DeviceFormConstants.colleges];
    final List<String?> departments = [null];
    if (_tempSelectedCollege != null) {
      departments
          .addAll(DeviceFormConstants.departments[_tempSelectedCollege] ?? []);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: theme.canvasColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تصفية الأجهزة',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: widget.scrollController,
                  children: [
                    _buildFilterSection(
                      title: 'الكلية',
                      children: colleges.map((college) {
                        return RadioListTile<String?>(
                          title: Text(college ?? 'جميع الكليات'),
                          value: college,
                          groupValue: _tempSelectedCollege,
                          onChanged: (value) {
                            setState(() {
                              _tempSelectedCollege = value;
                              _tempSelectedDepartment = null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    if (_tempSelectedCollege != null)
                      _buildFilterSection(
                        title: 'القسم',
                        children: departments.map((department) {
                          return RadioListTile<String?>(
                            title: Text(department ?? 'جميع الأقسام'),
                            value: department,
                            groupValue: _tempSelectedDepartment,
                            onChanged: (value) {
                              setState(() {
                                _tempSelectedDepartment = value;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 10),
                    _buildFilterSection(
                      title: 'حالة الصيانة',
                      children: [
                        RadioListTile<bool?>(
                          title: const Text('الكل'),
                          value: null,
                          groupValue: _tempSelectedNeedsMaintenance,
                          onChanged: (value) {
                            setState(() {
                              _tempSelectedNeedsMaintenance = value;
                            });
                          },
                        ),
                        RadioListTile<bool?>(
                          title: const Text('يحتاج صيانة'),
                          value: true,
                          groupValue: _tempSelectedNeedsMaintenance,
                          onChanged: (value) {
                            setState(() {
                              _tempSelectedNeedsMaintenance = value;
                            });
                          },
                        ),
                        RadioListTile<bool?>(
                          title: const Text('لا يحتاج صيانة'),
                          value: false,
                          groupValue: _tempSelectedNeedsMaintenance,
                          onChanged: (value) {
                            setState(() {
                              _tempSelectedNeedsMaintenance = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _tempSelectedCollege = null;
                          _tempSelectedDepartment = null;
                          _tempSelectedNeedsMaintenance = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('مسح الفلاتر'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onApplyFilters(
                          _tempSelectedCollege,
                          _tempSelectedDepartment,
                          _tempSelectedNeedsMaintenance,
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('تطبيق الفلاتر'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...children,
        const Divider(),
      ],
    );
  }
}
