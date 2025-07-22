import 'package:flutter/material.dart';
import '../models/lab_model.dart'; // نموذج بيانات المعمل.
// نموذج بيانات الجهاز.
import 'package:uquts1/services/firebase_database_service.dart';
import '../utils/device_form_constants.dart'; // ثوابت وقوائم مستخدمة في الفورم.
import '../utils/ui_helpers.dart'; // دوال مساعدة لعرض عناصر واجهة المستخدم.
import 'add_lab_screen.dart'; // شاشة إضافة معمل.
import 'lab_details_screen.dart'; // شاشة تفاصيل المعمل.

//------------------------------------------------------------------------------

/// ويدجت شاشة عرض المعامل، وهي StatefulWidget لإدارة الحالات الداخلية مثل التصفية والتحميل.
class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

//------------------------------------------------------------------------------

/// كلاس الحالة (State) الخاص بـ LabsScreen.
class _LabsScreenState extends State<LabsScreen> {
  // --- ثوابت لتنظيم الكود وتوحيد قيم التصميم ---
  static const double _defaultPadding = 16.0;
  static const double _iconSize = 64.0;

  //------------------------------------------------------------------------------

  // --- متغيرات الحالة (State Variables) ---
  String? _selectedFloor; // لتخزين قيمة فلتر الدور المحددة.
  String? _selectedCollege; // لتخزين قيمة فلتر الكلية المحددة.
  List<LabModel> _labs = []; // قائمة لتخزين المعامل التي يتم عرضها بعد التصفية.
  bool _isLoading = true; // لتتبع حالة التحميل.
  String? _error; // لتخزين رسالة الخطأ في حال حدوثه.

  //------------------------------------------------------------------------------

  // --- قوائم الخيارات المنسدلة للتصفية ---
  // يتم إضافة خيار "الكل" في بداية كل قائمة.
  final List<String> _floors = ['جميع الأدوار', ...DeviceFormConstants.floors];
  final List<String> _colleges = [
    'جميع الكليات',
    ...DeviceFormConstants.colleges
  ];

  //------------------------------------------------------------------------------

  /// دالة initState: يتم استدعاؤها مرة واحدة عند إنشاء الويدجت.
  @override
  void initState() {
    super.initState();
    // تعيين القيمة الافتراضية للفلاتر لتكون "الكل".
    _selectedFloor = _floors.first;
    _selectedCollege = _colleges.first;
    _loadLabs(); // تحميل قائمة المعامل عند بدء تشغيل الشاشة.
  }

  //------------------------------------------------------------------------------

  /// دالة غير متزامنة لتحميل قائمة المعامل بناءً على الفلاتر المحددة.
  Future<void> _loadLabs() async {
    try {
      setState(() => _isLoading = true);
      // جلب المعامل المصفاة من قاعدة البيانات.
      _labs = await _fetchFilteredLabs();
      setState(() {
        _isLoading = false;
        _error = null; // إعادة تعيين الخطأ عند النجاح.
      });
    } catch (e) {
      _handleLoadError(e); // التعامل مع أي خطأ يحدث أثناء التحميل.
    }
  }

  //------------------------------------------------------------------------------

  /// دالة مساعدة تحتوي على منطق جلب وتصفية المعامل من Firebase.
  Future<List<LabModel>> _fetchFilteredLabs() async {
    List<LabModel> labs;

    // جلب المعامل حسب الكلية إذا تم تحديد كلية معينة.
    if (_selectedCollege != null && _selectedCollege != _colleges.first) {
      labs = await FirebaseDatabaseService.getLabsByCollege(_selectedCollege!);
    } else {
      // وإلا، جلب جميع المعامل.
      labs = await FirebaseDatabaseService.getLabs();
    }

    // تصفية النتائج حسب الدور (تتم هذه العملية في الذاكرة بعد جلب البيانات).
    if (_selectedFloor != null && _selectedFloor != _floors.first) {
      labs = labs.where((lab) => lab.floorNumber == _selectedFloor).toList();
    }

    return labs;
  }

  //------------------------------------------------------------------------------

  /// دالة لمعالجة الأخطاء عند تحميل البيانات وعرض خيارات للمستخدم.
  void _handleLoadError(dynamic error) {
    setState(() {
      _error = error.toString();
      _isLoading = false;
    });

    // عرض ورقة سفلية بخيارات للمستخدم للتعامل مع الخطأ.
    UIHelpers.showBottomSheetOptions(
      context: context,
      title: 'خطأ في تحميل المعامل',
      options: [
        BottomSheetOption(
          title: 'إعادة المحاولة',
          icon: const Icon(Icons.refresh),
          onTap: _loadLabs,
        ),
        BottomSheetOption(
          title: 'تفاصيل الخطأ',
          icon: const Icon(Icons.error_outline),
          onTap: () => _showErrorDetails(),
        ),
      ],
    );
  }

  //------------------------------------------------------------------------------

  /// دالة لعرض تفاصيل الخطأ في ورقة سفلية.
  void _showErrorDetails() {
    UIHelpers.showBottomSheetOptions(
      context: context,
      title: 'تفاصيل الخطأ',
      options: [
        BottomSheetOption(
          title: _error ?? 'خطأ غير معروف',
          icon: const Icon(Icons.info_outline),
          onTap: () {}, // فقط لعرض النص.
        ),
      ],
    );
  }

  //------------------------------------------------------------------------------

  /// دالة للانتقال إلى شاشة تفاصيل المعمل.
  void _navigateToLabDetails(LabModel lab) {
    // التحقق من وجود رابط للموقع قبل الانتقال.
    if (lab.locationUrl == null || lab.locationUrl!.isEmpty) {
      UIHelpers.showSnackBar(
        context: context,
        message: 'لم يتم تحديد موقع للمعمل',
        type: SnackBarType.error,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LabDetailsScreen(lab: lab)),
    );
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
      ),
      body: Column(
        children: [
          _buildFilterSection(theme), // بناء قسم الفلاتر العلوي.
          // جعل قائمة المعامل تمتد لملء المساحة المتبقية.
          Expanded(child: _buildLabsList(theme)),
        ],
      ),
      // زر عائم لإضافة معمل جديد.
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddLabScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء قسم التصفية الذي يحتوي على القوائم المنسدلة.
  Widget _buildFilterSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(_defaultPadding),
      color: theme.colorScheme.primary,
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown(
              value: _selectedFloor,
              items: _floors,
              onChanged: (value) {
                setState(() => _selectedFloor = value);
                _loadLabs(); // إعادة تحميل المعامل عند تغيير الفلتر.
              },
              hint: 'الدور',
            ),
          ),
          const SizedBox(width: _defaultPadding),
          Expanded(
            child: _buildDropdown(
              value: _selectedCollege,
              items: _colleges,
              onChanged: (value) {
                setState(() => _selectedCollege = value);
                _loadLabs(); // إعادة تحميل المعامل عند تغيير الفلتر.
              },
              hint: 'الكلية',
            ),
          ),
        ],
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء قائمة المعامل، ويعمل كآلة حالة لعرض الواجهة المناسبة.
  Widget _buildLabsList(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorView(theme);
    }
    if (_labs.isEmpty) {
      return _buildEmptyView(theme);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(_defaultPadding),
      itemCount: _labs.length,
      itemBuilder: (context, index) => _buildLabItem(theme, _labs[index]),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء واجهة المستخدم في حالة حدوث خطأ.
  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: _iconSize, color: theme.colorScheme.error),
          const SizedBox(height: _defaultPadding),
          Text('حدث خطأ: $_error',
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: _defaultPadding),
          FilledButton.icon(
              onPressed: _loadLabs,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة')),
        ],
      ),
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
          Text('لا توجد معامل مسجلة',
              style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(179))),
          const SizedBox(height: 8),
          Text('اضغط على + لإضافة معمل جديد',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(179))),
        ],
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء عنصر واحد (بطاقة) في قائمة المعامل.
  Widget _buildLabItem(ThemeData theme, LabModel lab) {
    return Card(
      margin: const EdgeInsets.only(bottom: _defaultPadding),
      child: ListTile(
        title: Text('معمل ${lab.labNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(lab.college), Text(lab.department)],
        ),
        trailing: _buildLabStatusTrailing(lab),
        onTap: () => _navigateToLabDetails(lab),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء الجزء الخلفي من عنصر القائمة، الذي يعرض الدور والحالة.
  Widget _buildLabStatusTrailing(LabModel lab) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(lab.floorNumber),
        const SizedBox(width: 8),
        _buildStatusIcon(lab.status),
      ],
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

  //------------------------------------------------------------------------------

  /// دالة مساعدة قابلة لإعادة الاستخدام لإنشاء قائمة منسدلة منسقة.
  Widget _buildDropdown(
      {required String? value,
      required List<String> items,
      required void Function(String?)? onChanged,
      required String hint}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: hint,
        border: const OutlineInputBorder(),
        fillColor: Colors.white,
        filled: true,
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
