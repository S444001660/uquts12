import 'package:flutter/material.dart';
// لاستخدام debugPrint
// لتنسيق التاريخ والوقت

import '../models/device_model.dart'; // نموذج بيانات الجهاز.
import '../models/lab_model.dart'; // نموذج بيانات المعمل (لاستخدام LabStatus).
import 'package:uquts1/services/firebase_database_service.dart';
import '../utils/ui_helpers.dart'; // دوال مساعدة لعرض عناصر واجهة المستخدم.
import 'add_device_screen.dart'; // شاشة إضافة/تعديل جهاز.

//------------------------------------------------------------------------------

/// ويدجت شاشة عرض تفاصيل الجهاز، وهي StatefulWidget لإدارة الحالات الداخلية.
/// هذه الشاشة مخصصة للعرض فقط، مع زر للانتقال إلى شاشة التعديل.
class ViewDeviceScreen extends StatefulWidget {
  final DeviceModel device;

  const ViewDeviceScreen({
    super.key,
    required this.device,
  });

  @override
  State<ViewDeviceScreen> createState() => _ViewDeviceScreenState();
}

//------------------------------------------------------------------------------

/// كلاس الحالة (State) الخاص بـ ViewDeviceScreen.
class _ViewDeviceScreenState extends State<ViewDeviceScreen> {
  // --- متغيرات الحالة (State Variables) ---
  late DeviceModel
      _currentDevice; // لتخزين بيانات الجهاز الحالية، ويمكن تحديثها.
  LabModel? _associatedLab; // لتخزين تفاصيل المعمل المرتبط بالجهاز.
  bool _isLoading = true; // لتتبع حالة التحميل.

  //------------------------------------------------------------------------------

  /// دالة initState: يتم استدعاؤها مرة واحدة عند إنشاء الويدجت.
  @override
  void initState() {
    super.initState();
    _currentDevice = widget.device; // تهيئة متغير الحالة بالبيانات الممررة.
    debugPrint('ViewDeviceScreen: Initial device ID: ${widget.device.id}');
    debugPrint(
        'ViewDeviceScreen: Initial device imagePath: ${widget.device.imagePath}');
    _loadDeviceAndLabDetails(); // تحميل تفاصيل الجهاز والمعمل.
  }

  //------------------------------------------------------------------------------

  /// دالة غير متزامنة لتحميل أحدث تفاصيل الجهاز والمعمل المرتبط به.
  /// هذا يضمن أن البيانات المعروضة هي الأحدث دائمًا.
  Future<void> _loadDeviceAndLabDetails() async {
    setState(() => _isLoading = true);
    try {
      // جلب أحدث بيانات الجهاز من قاعدة البيانات (للتأكد من التحديثات).
      final updatedDevice =
          await FirebaseDatabaseService.getDeviceById(_currentDevice.id);
      if (updatedDevice != null && mounted) {
        _currentDevice = updatedDevice;
        debugPrint(
            'ViewDeviceScreen: Updated device imagePath after reload: ${_currentDevice.imagePath}');
      } else {
        debugPrint(
            'ViewDeviceScreen: Device not found on reload or widget not mounted.');
      }

      // جلب تفاصيل المعمل المرتبط بالجهاز.
      if (_currentDevice.labId.isNotEmpty) {
        _associatedLab =
            await FirebaseDatabaseService.getLabById(_currentDevice.labId);
        debugPrint(
            'ViewDeviceScreen: Associated Lab: ${_associatedLab?.labNumber}');
      } else {
        debugPrint('ViewDeviceScreen: No lab ID for this device.');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading device or lab details in ViewDeviceScreen: $e');
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'خطأ في تحميل التفاصيل: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  //------------------------------------------------------------------------------

  /// الدالة الأساسية لبناء واجهة المستخدم (UI) للشاشة بأكملها.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // تحقق من صلاحية رابط الصورة قبل بناء الواجهة لتجنب الأخطاء.
    final bool hasValidImageUrl = _currentDevice.imagePath != null &&
        _currentDevice.imagePath!.startsWith('http');
    debugPrint(
        'ViewDeviceScreen: hasValidImageUrl: $hasValidImageUrl for path: ${_currentDevice.imagePath}');

    return Scaffold(
      appBar: AppBar(
        title: Text('عرض الجهاز: ${_currentDevice.name}'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          // زر التعديل: ينقلك مباشرة إلى شاشة AddDeviceScreen للتعديل الفعلي.
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'تعديل الجهاز',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddDeviceScreen(device: _currentDevice),
                ),
              ).then((_) {
                // تحديث البيانات عند العودة من شاشة التعديل لضمان عرض أحدث المعلومات.
                _loadDeviceAndLabDetails();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // قسم صورة الجهاز (يظهر فقط إذا كان هناك imagePath صالح)
                  if (hasValidImageUrl) // <--- الشرط هنا
                    Column(
                      children: [
                        _buildImageSection(theme),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // بطاقة معلومات الجهاز الأساسية
                  _buildMainInfoCard(theme),
                  const SizedBox(height: 16),

                  // بطاقة تفاصيل المعمل (إذا كان المعمل مرتبطاً)
                  if (_associatedLab != null) ...[
                    _buildLabInfoCard(theme),
                    const SizedBox(height: 16),
                  ],

                  // بطاقة مواصفات الجهاز
                  _buildSpecificationsCard(theme),
                  const SizedBox(height: 16),

                  // بطاقة الملاحظات (تظهر فقط إذا كانت هناك ملاحظات)
                  if (_currentDevice.notes.isNotEmpty) _buildNotesCard(theme),
                ],
              ),
            ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء قسم عرض صورة الجهاز.
  Widget _buildImageSection(ThemeData theme) {
    debugPrint(
        'ViewDeviceScreen: Building image section for URL: ${_currentDevice.imagePath}');
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(128)),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () {
            UIHelpers.showImageDialog(
              context: context,
              imageUrl: _currentDevice.imagePath!,
              title: 'صورة الجهاز: ${_currentDevice.name}',
            );
          },
          child: Image.network(
            _currentDevice.imagePath!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint(
                  'ViewDeviceScreen: Error loading image from network: $error');
              return Center(
                child: Icon(Icons.broken_image,
                    size: 50, color: theme.colorScheme.error),
              );
            },
          ),
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء بطاقة المعلومات الأساسية للجهاز.
  Widget _buildMainInfoCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('معلومات الجهاز الأساسية', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.devices, 'الاسم', _currentDevice.name),
            _buildDetailRow(
                Icons.model_training, 'الموديل', _currentDevice.model),
            _buildDetailRow(
                Icons.numbers, 'الرقم التسلسلي', _currentDevice.serialNumber),
            _buildDetailRow(
              _currentDevice.needsMaintenance
                  ? Icons.build_circle
                  : Icons.check_circle,
              'حالة الصيانة',
              _currentDevice.needsMaintenance
                  ? 'يحتاج إلى صيانة'
                  : 'يعمل بشكل طبيعي',
              color: _currentDevice.needsMaintenance
                  ? Colors.orange
                  : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء بطاقة تفاصيل المعمل المرتبط بالجهاز.
  Widget _buildLabInfoCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('معلومات المعمل', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_associatedLab != null) ...[
              _buildDetailRow(Icons.school, 'الكلية', _associatedLab!.college),
              _buildDetailRow(
                  Icons.account_tree, 'القسم', _associatedLab!.department),
              _buildDetailRow(
                  Icons.meeting_room, 'رقم المعمل', _associatedLab!.labNumber),
            ] else ...[
              Text('لا تتوفر معلومات المعمل',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء بطاقة مواصفات الجهاز الفنية.
  Widget _buildSpecificationsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المواصفات الفنية', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.memory, 'المعالج', _currentDevice.processor),
            _buildDetailRow(
                Icons.sd_storage, 'نوع التخزين', _currentDevice.storageType),
            _buildDetailRow(
                Icons.storage, 'حجم التخزين', _currentDevice.storageSize),
            if (_currentDevice.hasExtraStorage) ...[
              _buildDetailRow(Icons.sd_storage, 'تخزين إضافي (النوع)',
                  _currentDevice.extraStorageType ?? 'غير محدد'),
              _buildDetailRow(Icons.storage, 'تخزين إضافي (الحجم)',
                  _currentDevice.extraStorageSize ?? 'غير محدد'),
            ],
            _buildDetailRow(Icons.laptop_mac, 'إصدار نظام التشغيل',
                _currentDevice.osVersion),
          ],
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// ويدجت مساعد لبناء بطاقة الملاحظات.
  Widget _buildNotesCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ملاحظات', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(_currentDevice.notes),
          ],
        ),
      ),
    );
  }

  //------------------------------------------------------------------------------

  /// دالة مساعدة قابلة لإعادة الاستخدام لبناء صف تفصيلي منسق.
  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey[700]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color),
              softWrap: true, // للسماح للنص بالالتفاف إذا كان طويلاً.
            ),
          ),
        ],
      ),
    );
  }
}
