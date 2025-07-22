import 'package:flutter/material.dart';
import '../models/device_model.dart'; // نموذج بيانات الجهاز.
import 'package:uquts1/services/firebase_database_service.dart';
import '../utils/device_form_constants.dart'; // ثوابت وقوائم مستخدمة في الفورم.
import '../utils/ui_helpers.dart'; // دوال مساعدة لعرض عناصر واجهة المستخدم.
import 'add_device_screen.dart'; // شاشة إضافة/تعديل جهاز.
import 'view_device_screen.dart'; // الشاشة الجديدة لعرض الجهاز فقط.

//------------------------------------------------------------------------------

/// ويدجت شاشة قائمة الأجهزة، وهي StatefulWidget لإدارة الحالات الداخلية مثل البحث والتصفية.
class DevicesListScreen extends StatefulWidget {
  const DevicesListScreen({super.key});

  @override
  State<DevicesListScreen> createState() => _DevicesListScreenState();
}

//------------------------------------------------------------------------------

/// كلاس الحالة (State) الخاص بـ DevicesListScreen.
class _DevicesListScreenState extends State<DevicesListScreen> {
  // --- ثوابت لتنظيم الكود وتوحيد التصميم ---
  static const double _defaultPadding = 16.0;
  static const double _iconSize = 64.0;

  //------------------------------------------------------------------------------

  // --- متغيرات الحالة (State Variables) ---
  /// لتخزين القائمة الكاملة للأجهزة من قاعدة البيانات.
  List<DeviceModel> _allDevices = [];

  /// لتخزين القائمة المصفاة التي يتم عرضها للمستخدم بعد تطبيق البحث والفلاتر.
  List<DeviceModel> _filteredDevices = [];

  /// لتتبع حالة التحميل وعرض مؤشر التحميل.
  bool _isLoading = true;

  //------------------------------------------------------------------------------

  // --- متحكمات البحث والتصفية ---
  /// متحكم حقل البحث النصي.
  final TextEditingController _searchController = TextEditingController();

  /// متغيرات لتخزين قيم الفلاتر المختارة حاليًا.
  String? _selectedCollege;
  String? _selectedDepartment;
  bool?
      _selectedNeedsMaintenance; // null: الكل, true: يحتاج صيانة, false: لا يحتاج صيانة

  //------------------------------------------------------------------------------

  /// دالة initState: يتم استدعاؤها مرة واحدة عند إنشاء الويدجت.
  @override
  void initState() {
    super.initState();
    _loadDevices(); // تحميل قائمة الأجهزة عند بدء الشاشة.
    // إضافة مستمع لحقل البحث لتحديث القائمة تلقائيًا عند كل تغيير في النص.
    _searchController.addListener(_filterDevices);
  }

  //------------------------------------------------------------------------------

  /// دالة dispose: يتم استدعاؤها عند إزالة الويدجت لتحرير الموارد.
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  //------------------------------------------------------------------------------

  /// دالة غير متزامنة لتحميل القائمة الكاملة للأجهزة من قاعدة البيانات.
  Future<void> _loadDevices() async {
    try {
      setState(() => _isLoading = true);
      final devices = await FirebaseDatabaseService.getDevices();
      setState(() {
        _allDevices = devices;
        _isLoading = false;
      });
      _filterDevices(); // تطبيق الفلاتر المبدئية بعد تحميل البيانات.
    } catch (e) {
      _handleLoadError(e); // معالجة أي خطأ يحدث أثناء التحميل.
    }
  }

  //------------------------------------------------------------------------------

  /// دالة مخصصة لمعالجة الأخطاء التي قد تحدث أثناء تحميل البيانات.
  void _handleLoadError(dynamic error) {
    setState(() => _isLoading = false);
    UIHelpers.showSnackBar(
        context: context,
        message: 'خطأ في تحميل الأجهزة: $error',
        type: SnackBarType.error);
  }

  //------------------------------------------------------------------------------

  /// دالة التصفية المحورية التي يتم استدعاؤها عند أي تغيير في البحث أو الفلاتر.
  void _filterDevices() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDevices = _allDevices.where((device) {
        // شرط البحث النصي: يطابق اسم الجهاز، الموديل، الرقم التسلسلي، الكلية، أو القسم.
        final matchesSearch = device.name.toLowerCase().contains(query) ||
            device.model.toLowerCase().contains(query) ||
            device.serialNumber.toLowerCase().contains(query) ||
            device.college.toLowerCase().contains(query) ||
            device.department.toLowerCase().contains(query);

        // شرط فلتر الكلية: إذا لم يتم تحديد كلية، يتم قبول جميع الأجهزة.
        final matchesCollege =
            _selectedCollege == null || device.college == _selectedCollege;
        // شرط فلتر القسم.
        final matchesDepartment = _selectedDepartment == null ||
            device.department == _selectedDepartment;
        // شرط فلتر حالة الصيانة: إذا لم يتم تحديد حالة، يتم قبول جميع الأجهزة.
        final matchesMaintenance = _selectedNeedsMaintenance == null ||
            device.needsMaintenance == _selectedNeedsMaintenance;

        // إرجاع الأجهزة التي تحقق جميع الشروط المطبقة.
        return matchesSearch &&
            matchesCollege &&
            matchesDepartment &&
            matchesMaintenance;
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
        // استخدام DraggableScrollableSheet يسمح للمستخدم بسحب الورقة لتغيير ارتفاعها.
        return DraggableScrollableSheet(
          initialChildSize: 0.6, // الارتفاع الأولي.
          minChildSize: 0.3, // أصغر ارتفاع.
          maxChildSize: 0.9, // أكبر ارتفاع.
          expand: false, // مهم لكي لا تتجاوز حدود الشاشة.
          builder: (context, scrollController) {
            return DeviceFilterBottomSheet(
              scrollController: scrollController,
              initialSelectedCollege: _selectedCollege,
              initialSelectedDepartment: _selectedDepartment,
              initialSelectedNeedsMaintenance: _selectedNeedsMaintenance,
              onApplyFilters: (college, department, needsMaintenance) {
                // عند تطبيق الفلاتر، يتم تحديث متغيرات الحالة واستدعاء دالة التصفية.
                setState(() {
                  _selectedCollege = college;
                  _selectedDepartment = department;
                  _selectedNeedsMaintenance = needsMaintenance;
                });
                _filterDevices(); // تطبيق الفلاتر الجديدة.
              },
            );
          },
        );
      },
    );
  }

  //------------------------------------------------------------------------------

  /// دالة للانتقال إلى شاشة عرض الجهاز وتحديث القائمة عند العودة.
  void _navigateToDeviceView(DeviceModel device) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ViewDeviceScreen(
              device: device)), // <--- الانتقال إلى شاشة العرض الجديدة.
    ).then((_) => _loadDevices()); // تحديث القائمة بالكامل بعد العودة.
  }

  //------------------------------------------------------------------------------

  /// دالة بناء الواجهة الرئيسية للشاشة.
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
          _buildSearchBar(theme), // بناء حقل البحث.
          // جعل قائمة الأجهزة تمتد لملء المساحة المتبقية.
          Expanded(child: _buildDevicesList(theme)),
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
          hintText: 'البحث في الأجهزة',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    // _filterDevices() سيتم استدعاؤها تلقائيًا بواسطة المستمع.
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء قائمة الأجهزة، ويعمل كـ "آلة حالة" للواجهة.
  Widget _buildDevicesList(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredDevices.isEmpty) {
      // إذا كانت القائمة المصفاة فارغة، يتم عرض واجهة توضيحية.
      return _buildEmptyView(theme);
    }
    // إذا كانت هناك بيانات، يتم عرض القائمة.
    return ListView.builder(
      padding: const EdgeInsets.all(_defaultPadding),
      itemCount: _filteredDevices.length,
      itemBuilder: (context, index) =>
          _buildDeviceItem(theme, _filteredDevices[index]),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء واجهة المستخدم في حالة عدم وجود أجهزة تطابق البحث.
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

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء عنصر واحد (بطاقة) في قائمة الأجهزة.
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
        onTap: () =>
            _navigateToDeviceView(device), // <--- ينقل لـ ViewDeviceScreen
      ),
    );
  }
}

//------------------------------------------------------------------------------

/// ويدجت Bottom Sheet المخصصة لفلاتر الأجهزة.
/// تم فصلها في ويدجت خاص بها لتنظيم الكود وإدارة حالتها المؤقتة بشكل مستقل.
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

//------------------------------------------------------------------------------

/// كلاس الحالة الخاص بـ DeviceFilterBottomSheet.
class _DeviceFilterBottomSheetState extends State<DeviceFilterBottomSheet> {
  // متغيرات حالة مؤقتة لتخزين اختيارات المستخدم داخل الـ Bottom Sheet.
  String? _tempSelectedCollege;
  String? _tempSelectedDepartment;
  bool? _tempSelectedNeedsMaintenance;

  /// تهيئة الحالة المؤقتة بالقيم الحالية للفلاتر عند فتح الـ Bottom Sheet.
  @override
  void initState() {
    super.initState();
    _tempSelectedCollege = widget.initialSelectedCollege;
    _tempSelectedDepartment = widget.initialSelectedDepartment;
    _tempSelectedNeedsMaintenance = widget.initialSelectedNeedsMaintenance;
  }

  /// دالة بناء واجهة المستخدم الخاصة بالـ Bottom Sheet.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // تجهيز قوائم الفلاتر مع إضافة خيار "الكل" (الذي يمثله 'null').
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

              // قائمة قابلة للتمرير تحتوي على جميع خيارات الفلاتر.
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
                              _tempSelectedDepartment =
                                  null; // إعادة تعيين القسم عند تغيير الكلية
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // فلتر القسم (يظهر فقط عند اختيار كلية).
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

                    // فلتر حالة الصيانة.
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

              // أزرار التحكم في الفلاتر (تطبيق أو مسح).
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
                        Navigator.pop(context); // إغلاق الورقة السفلية.
                        // استدعاء الدالة الممررة من الشاشة الرئيسية لتطبيق الفلاتر.
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
              const SizedBox(height: 10), // هامش سفلي.
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
        const Divider(), // فاصل بين الأقسام.
      ],
    );
  }
}
