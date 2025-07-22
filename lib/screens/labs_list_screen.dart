import 'package:flutter/material.dart';
import '../models/lab_model.dart'; // نموذج بيانات المعمل.
import '../models/device_model.dart'; // نموذج بيانات الجهاز.
import 'package:uquts1/services/firebase_database_service.dart';
import '../utils/device_form_constants.dart'; // ثوابت وقوائم مستخدمة في الفورم.
import '../utils/ui_helpers.dart'; // دوال مساعدة لعرض عناصر واجهة المستخدم.
import 'add_lab_screen.dart'; // شاشة إضافة معمل.
import 'lab_details_screen.dart'; // شاشة تفاصيل المعمل.

//------------------------------------------------------------------------------

/// ويدجت شاشة قائمة المعامل، وهي StatefulWidget لإدارة الحالات الداخلية مثل البحث والتصفية.
class LabsListScreen extends StatefulWidget {
  const LabsListScreen({super.key});

  @override
  State<LabsListScreen> createState() => _LabsListScreenState();
}

//------------------------------------------------------------------------------

/// كلاس الحالة (State) الخاص بـ LabsListScreen.
class _LabsListScreenState extends State<LabsListScreen> {
  // --- ثوابت لتنظيم الكود وتوحيد التصميم ---
  static const double _defaultPadding = 16.0;
  static const double _iconSize = 64.0;

  //------------------------------------------------------------------------------

  // --- متغيرات الحالة (State Variables) ---
  /// لتخزين القائمة الكاملة للمعامل من قاعدة البيانات.
  List<LabModel> _allLabs = [];

  /// لتخزين القائمة المصفاة التي يتم عرضها للمستخدم.
  List<LabModel> _filteredLabs = [];

  /// لتتبع حالة التحميل.
  bool _isLoading = true;

  /// متغير لتتبع عدد الأجهزة في كل معمل لتحسين الأداء.
  Map<String, int> _labDeviceCounts = {};

  //------------------------------------------------------------------------------

  // --- متحكمات البحث والتصفية ---
  final TextEditingController _searchController = TextEditingController();
  LabStatus? _selectedStatus;
  String? _selectedCollege;
  String? _selectedFloor;

  //------------------------------------------------------------------------------

  /// دالة initState: يتم استدعاؤها مرة واحدة عند إنشاء الويدجت.
  @override
  void initState() {
    super.initState();
    // تعيين القيمة الافتراضية للفلاتر (null يعني "الكل").
    _selectedCollege = null;
    _selectedFloor = null;
    _selectedStatus = null;

    _loadLabs(); // تحميل قائمة المعامل.
    // إضافة مستمع لحقل البحث لتحديث القائمة تلقائيًا.
    _searchController.addListener(_filterLabs);
  }

  //------------------------------------------------------------------------------

  /// دالة dispose: يتم استدعاؤها عند إزالة الويدجت لتحرير الموارد.
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  //------------------------------------------------------------------------------

  /// دالة غير متزامنة لتحميل بيانات المعامل وعدد الأجهزة المرتبطة بها.
  Future<void> _loadLabs() async {
    try {
      setState(() => _isLoading = true);

      // جلب البيانات من قاعدة البيانات.
      final labs = await FirebaseDatabaseService.getLabs();
      final devices = await FirebaseDatabaseService.getDevices();

      // حساب عدد الأجهزة لكل معمل مرة واحدة لتحسين الأداء.
      final labDeviceCounts = _calculateLabDeviceCounts(devices);

      setState(() {
        _allLabs = labs;
        _labDeviceCounts = labDeviceCounts;
        _isLoading = false;
      });
      _filterLabs(); // تطبيق الفلاتر بعد تحميل البيانات
    } catch (e) {
      _handleLoadError(e);
    }
  }

  //------------------------------------------------------------------------------

  /// دالة مساعدة لحساب عدد الأجهزة لكل معمل وتخزينها في خريطة.
  Map<String, int> _calculateLabDeviceCounts(List<DeviceModel> devices) {
    final labDeviceCounts = <String, int>{};
    for (var device in devices) {
      if (device.labId.isNotEmpty) {
        labDeviceCounts[device.labId] =
            (labDeviceCounts[device.labId] ?? 0) + 1;
      }
    }
    return labDeviceCounts;
  }

  //------------------------------------------------------------------------------

  /// دالة لمعالجة الأخطاء عند تحميل البيانات.
  void _handleLoadError(dynamic error) {
    setState(() => _isLoading = false);
    UIHelpers.showSnackBar(
        context: context,
        message: 'خطأ في تحميل المعامل: $error',
        type: SnackBarType.error);
  }

  //------------------------------------------------------------------------------

  /// دالة التصفية المحورية التي يتم استدعاؤها عند أي تغيير في البحث أو الفلاتر.
  void _filterLabs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredLabs = _allLabs.where((lab) {
        // شرط البحث النصي: يطابق رقم المعمل، الكلية، أو القسم.
        final matchesSearch = lab.labNumber.toLowerCase().contains(query) ||
            lab.college.toLowerCase().contains(query) ||
            lab.department.toLowerCase().contains(query);

        // شرط فلتر الكلية.
        final matchesCollege =
            _selectedCollege == null || lab.college == _selectedCollege;
        // شرط فلتر الدور.
        final matchesFloor =
            _selectedFloor == null || lab.floorNumber == _selectedFloor;
        // شرط فلتر الحالة.
        final matchesStatus =
            _selectedStatus == null || lab.status == _selectedStatus;

        // إرجاع المعامل التي تحقق جميع الشروط.
        return matchesSearch && matchesCollege && matchesFloor && matchesStatus;
      }).toList();
    });
  }

  //------------------------------------------------------------------------------

  /// دالة لعرض ورقة سفلية (Bottom Sheet) تحتوي على خيارات التصفية.
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // للسماح للورقة بأخذ ارتفاع متغير.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, // الارتفاع الأولي.
          minChildSize: 0.3, // أصغر ارتفاع.
          maxChildSize: 0.9, // أكبر ارتفاع.
          expand: false, // مهم لكي لا تتجاوز حدود الشاشة
          builder: (context, scrollController) {
            return FilterBottomSheet(
              scrollController: scrollController,
              initialSelectedCollege: _selectedCollege,
              initialSelectedFloor: _selectedFloor,
              initialSelectedStatus: _selectedStatus,
              onApplyFilters: (college, floor, status) {
                setState(() {
                  _selectedCollege = college;
                  _selectedFloor = floor;
                  _selectedStatus = status;
                });
                _filterLabs(); // تطبيق الفلاتر الجديدة
              },
            );
          },
        );
      },
    );
  }

  //------------------------------------------------------------------------------

  /// دالة للانتقال إلى شاشة تفاصيل المعمل.
  void _navigateToLabDetails(LabModel lab) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LabDetailsScreen(lab: lab)),
      // استخدام .then() لتحديث القائمة تلقائيًا بعد العودة من شاشة التفاصيل.
    ).then((_) => _loadLabs());
  }

  //------------------------------------------------------------------------------

  /// دالة بناء الواجهة الرئيسية للشاشة.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('المعامل'),
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
                        builder: (context) => const AddLabScreen()))
                .then((_) => _loadLabs()),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(theme), // بناء حقل البحث.
          // جعل قائمة المعامل تمتد لملء المساحة المتبقية.
          Expanded(child: _buildLabsList(theme)),
        ],
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء حقل البحث.
  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(_defaultPadding),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'البحث في المعامل',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    // _filterLabs() سيتم استدعاؤها تلقائيًا بواسطة المستمع.
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء قائمة المعامل، ويعمل كآلة حالة.
  Widget _buildLabsList(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredLabs.isEmpty) {
      return _buildEmptyView(theme);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(_defaultPadding),
      itemCount: _filteredLabs.length,
      itemBuilder: (context, index) =>
          _buildLabItem(theme, _filteredLabs[index]),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء واجهة المستخدم في حالة عدم وجود معامل.
  Widget _buildEmptyView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined,
              size: _iconSize, color: theme.colorScheme.primary.withAlpha(128)),
          const SizedBox(height: _defaultPadding),
          Text('لا توجد معامل تطابق البحث',
              style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(178))),
          const SizedBox(height: 8),
          Text('جرّب تغيير فلاتر البحث أو أضف معملاً جديدًا',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(128))),
        ],
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء عنصر واحد (بطاقة) في قائمة المعامل.
  Widget _buildLabItem(ThemeData theme, LabModel lab) {
    final deviceCount = _labDeviceCounts[lab.id] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: _defaultPadding),
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('معمل ${lab.labNumber}'),
            _buildDeviceCountBadge(theme, deviceCount), // شارة عدد الأجهزة.
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(lab.college), Text(lab.department)],
        ),
        trailing: _buildStatusIcon(lab.status), // أيقونة الحالة.
        onTap: () => _navigateToLabDetails(lab),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء شارة منسقة لعرض عدد الأجهزة.
  Widget _buildDeviceCountBadge(ThemeData theme, int deviceCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: deviceCount > 0
            ? theme.colorScheme.primary.withAlpha(26)
            : theme.colorScheme.error.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'عدد الأجهزة: $deviceCount',
        style: theme.textTheme.bodySmall?.copyWith(
          color: deviceCount > 0
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء أيقونة الحالة مع اللون المناسب.
  Widget _buildStatusIcon(LabStatus status) {
    IconData icon;
    Color color;
    switch (status) {
      case LabStatus.openWithDevices:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case LabStatus.openNoDevices:
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case LabStatus.closed:
        icon = Icons.cancel;
        color = Colors.red;
        break;
    }
    return Icon(icon, color: color);
  }
}

//------------------------------------------------------------------------------

/// ويدجت Bottom Sheet المخصصة للفلاتر.
class FilterBottomSheet extends StatefulWidget {
  final ScrollController scrollController;
  final String? initialSelectedCollege;
  final String? initialSelectedFloor;
  final LabStatus? initialSelectedStatus;
  final Function(String?, String?, LabStatus?) onApplyFilters;

  const FilterBottomSheet({
    super.key,
    required this.scrollController,
    this.initialSelectedCollege,
    this.initialSelectedFloor,
    this.initialSelectedStatus,
    required this.onApplyFilters,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

//------------------------------------------------------------------------------

/// كلاس الحالة الخاص بـ FilterBottomSheet.
class _FilterBottomSheetState extends State<FilterBottomSheet> {
  // متغيرات حالة مؤقتة لتخزين اختيارات المستخدم داخل الـ Bottom Sheet.
  String? _tempSelectedCollege;
  String? _tempSelectedFloor;
  LabStatus? _tempSelectedStatus;

  /// تهيئة الحالة المؤقتة بالقيم الحالية للفلاتر.
  @override
  void initState() {
    super.initState();
    _tempSelectedCollege = widget.initialSelectedCollege;
    _tempSelectedFloor = widget.initialSelectedFloor;
    _tempSelectedStatus = widget.initialSelectedStatus;
  }

  /// دالة بناء واجهة المستخدم الخاصة بالـ Bottom Sheet.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // تجهيز قوائم الفلاتر مع إضافة خيار "الكل" (الذي يمثله 'null').
    final List<String?> colleges = [null, ...DeviceFormConstants.colleges];
    final List<String?> floors = [null, ...DeviceFormConstants.floors];
    final List<LabStatus?> statuses = [null, ...LabStatus.values];

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
                'تصفية المعامل',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  controller: widget.scrollController,
                  children: [
                    // فلتر الكلية
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
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // فلتر الدور
                    _buildFilterSection(
                      title: 'الدور',
                      children: floors.map((floor) {
                        return RadioListTile<String?>(
                          title: Text(floor ?? 'جميع الأدوار'),
                          value: floor,
                          groupValue: _tempSelectedFloor,
                          onChanged: (value) {
                            setState(() {
                              _tempSelectedFloor = value;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // فلتر الحالة
                    _buildFilterSection(
                      title: 'الحالة',
                      children: statuses.map((status) {
                        return RadioListTile<LabStatus?>(
                          title: Text(
                              status == null ? 'الكل' : status.displayName),
                          value: status,
                          groupValue: _tempSelectedStatus,
                          onChanged: (value) {
                            setState(() {
                              _tempSelectedStatus = value;
                            });
                          },
                        );
                      }).toList(),
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
                          _tempSelectedFloor = null;
                          _tempSelectedStatus = null;
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
                        Navigator.pop(context); // إغلاق الورقة السفلية
                        widget.onApplyFilters(
                          _tempSelectedCollege,
                          _tempSelectedFloor,
                          _tempSelectedStatus,
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
              const SizedBox(height: 10), // هامش سفلي
            ],
          ),
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// دالة مساعدة لبناء قسم فلتر واحد (عنوان ومجموعة خيارات).
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
        const Divider(), // فاصل بين الأقسام
      ],
    );
  }
}
