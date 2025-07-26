import 'package:flutter/material.dart';
import '../models/lab_model.dart';
import '../models/device_model.dart';
import '../services/firebase_database_service.dart';
import '../utils/device_form_constants.dart';
import '../utils/ui_helpers.dart';
import 'add_lab_screen.dart';
import 'lab_details_screen.dart';

//------------------------------------------------------------------------------

class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});

  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

//------------------------------------------------------------------------------

class _LabsScreenState extends State<LabsScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  static const double _defaultPadding = 16.0;
  static const double _iconSize = 64.0;

  String? _selectedFloor;
  String? _selectedCollege;
  List<LabModel> _labs = [];
  bool _isLoading = true;
  String? _error;

  final List<String> _floors = ['جميع الأدوار', ...DeviceFormConstants.floors];
  final List<String> _colleges = [
    'جميع الكليات',
    ...DeviceFormConstants.colleges
  ];

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle) - (أساسي)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _selectedFloor = _floors.first;
    _selectedCollege = _colleges.first;
    _loadLabs();
  }

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method) - (أساسي)
  // ===========================================================================

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
          _buildFilterSection(theme),
          Expanded(child: _buildLabsList(theme)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddLabScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي والتنقل (Core Logic & Navigation) - (أساسي)
  // ===========================================================================

  /// دالة غير متزامنة لتحميل قائمة المعامل بناءً على الفلاتر المحددة.
  Future<void> _loadLabs() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      _labs = await _fetchFilteredLabs();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        _handleLoadError(e);
      }
    }
  }

  /// دالة للانتقال إلى شاشة تفاصيل المعمل.
  void _navigateToLabDetails(LabModel lab) {
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

  // ===========================================================================
  // 5. الدوال المساعدة والويدجتات الفرعية (Helpers & Sub-Widgets)
  // ===========================================================================

  /// دالة مساعدة تحتوي على منطق جلب وتصفية المعامل من Firebase.
  Future<List<LabModel>> _fetchFilteredLabs() async {
    List<LabModel> labs;

    if (_selectedCollege != null && _selectedCollege != _colleges.first) {
      labs = await FirebaseDatabaseService.getLabsByCollege(_selectedCollege!);
    } else {
      labs = await FirebaseDatabaseService.getLabs();
    }

    if (_selectedFloor != null && _selectedFloor != _floors.first) {
      labs = labs.where((lab) => lab.floorNumber == _selectedFloor).toList();
    }

    return labs;
  }

  /// دالة لمعالجة الأخطاء عند تحميل البيانات وعرض خيارات للمستخدم.
  void _handleLoadError(dynamic error) {
    setState(() {
      _error = error.toString();
      _isLoading = false;
    });

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

  /// دالة لعرض تفاصيل الخطأ في ورقة سفلية.
  void _showErrorDetails() {
    UIHelpers.showBottomSheetOptions(
      context: context,
      title: 'تفاصيل الخطأ',
      options: [
        BottomSheetOption(
          title: _error ?? 'خطأ غير معروف',
          icon: const Icon(Icons.info_outline),
          onTap: () {},
        ),
      ],
    );
  }

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
                _loadLabs();
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
                _loadLabs();
              },
              hint: 'الكلية',
            ),
          ),
        ],
      ),
    );
  }

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
