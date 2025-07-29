// استيراد المكتبات الضرورية
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/device_model.dart';
import '../models/lab_model.dart';
import '../services/firebase_database_service.dart';
import '../services/permissions_service.dart';
import 'add_device_screen.dart';
import 'add_lab_screen.dart';
import '../utils/ui_helpers.dart';
import 'view_device_screen.dart';
import '../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

//------------------------------------------------------------------------------

/// كلاس مساعد لتنظيم بيانات مواقع الكليات
class CollegeLocationInfo {
  final String mapUrl;
  final String imageAsset;

  const CollegeLocationInfo({required this.mapUrl, required this.imageAsset});
}

//------------------------------------------------------------------------------

class LabDetailsScreen extends StatefulWidget {
  final LabModel lab;

  const LabDetailsScreen({
    super.key,
    required this.lab,
  });

  @override
  State<LabDetailsScreen> createState() => _LabDetailsScreenState();
}

//------------------------------------------------------------------------------

class _LabDetailsScreenState extends State<LabDetailsScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  late LabModel _currentLab;
  bool _isLoading = true;
  List<DeviceModel> _devices = [];
  bool _canDelete = false;

  /// --- [تم التحديث] ---
  /// خريطة جديدة تحتوي على روابط الخرائط ومسارات الصور لكل كلية.
  final Map<String, CollegeLocationInfo> _collegeLocationData = {
    'كلية الهندسة': const CollegeLocationInfo(
      mapUrl: 'https://maps.app.goo.gl/4PfbWDc36XAdfRnM7',
      imageAsset: 'assets/images/college_engineering.jpg',
    ),
    'كلية الطب': const CollegeLocationInfo(
      mapUrl: 'https://maps.app.goo.gl/mSET1C88At97o6s46',
      imageAsset: 'assets/images/college_medicine.jpg',
    ),
    'كلية الحاسب الآلي': const CollegeLocationInfo(
      mapUrl: 'https://maps.app.goo.gl/yfHBYYpfLaoWu1qd8',
      imageAsset: 'assets/images/college_computer.jpg',
    ),
    'كلية العلوم': const CollegeLocationInfo(
      mapUrl: 'https://maps.app.goo.gl/iVGvJTV6e1Vquxqt6',
      imageAsset: 'assets/images/college_science.jpg',
    ),
    'كلية الإدارة والاقتصاد': const CollegeLocationInfo(
      mapUrl: 'https://maps.app.goo.gl/7ysTpqfdpZPPQTAn8',
      imageAsset: 'assets/images/college_management.jpg',
    ),
  };

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _currentLab = widget.lab;
    _initializeScreen();
  }

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل المعمل ${_currentLab.labNumber}'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddLabScreen(lab: _currentLab),
                ),
              ).then((_) {
                _loadLabDetails();
                _loadDevices();
              });
            },
          ),
          if (_canDelete)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'حذف المعمل',
              onPressed: _deleteLab,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLabImage(theme),
              const SizedBox(height: 16),
              _buildLabInfoCard(theme),
              const SizedBox(height: 16),
              _buildLocationCard(theme), // <-- تم استبدال الزر بالبطاقة الجديدة
              const SizedBox(height: 16),
              _buildDevicesCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي (Core Business Logic)
  // ===========================================================================

  Future<void> _initializeScreen() async {
    await _checkPermissions();
    await _loadLabDetails();
    await _loadDevices();
  }

  Future<void> _checkPermissions() async {
    final canDelete = await PermissionsService.hasPermission('delete_lab');
    if (mounted) {
      setState(() {
        _canDelete = canDelete;
      });
    }
  }

  Future<void> _loadLabDetails() async {
    try {
      final updatedLab =
          await FirebaseDatabaseService.getLabById(_currentLab.id);
      if (updatedLab != null && mounted) {
        setState(() {
          _currentLab = updatedLab;
        });
      }
    } catch (e) {
      debugPrint('خطأ في تحديث تفاصيل المعمل: $e');
    }
  }

  Future<void> _loadDevices() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final labDevices =
          await FirebaseDatabaseService.getDevicesForLab(_currentLab.id);

      if (mounted) {
        setState(() {
          _devices = labDevices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UIHelpers.showErrorSnackBar(context, 'خطأ في تحميل الأجهزة: $e');
      }
    }
  }

  /// --- [تم التحديث] --- فتح رابط الموقع بناءً على المنطق الجديد
  Future<void> _openLocationInMaps() async {
    final collegeInfo = _collegeLocationData[_currentLab.college];
    final locationUrl = _currentLab.locationUrl ?? collegeInfo?.mapUrl;

    if (locationUrl == null || locationUrl.isEmpty) {
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'موقع المعمل غير متوفر');
      }
      return;
    }

    final Uri url = Uri.parse(locationUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'تعذر فتح الموقع');
      }
    }
  }

  Future<void> _deleteLab() async {
    final confirm = await UIHelpers.showConfirmationDialog(
      context: context,
      title: 'تأكيد الحذف',
      content:
          'هل أنت متأكد من حذف معمل "${_currentLab.labNumber}"؟ سيتم إلغاء ربط جميع الأجهزة به.',
      confirmText: 'حذف',
      confirmColor: Colors.red,
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        await FirebaseDatabaseService.deleteLab(_currentLab.id);
        if (mounted) {
          Navigator.pop(context, true);
          UIHelpers.showSuccessSnackBar(context, 'تم حذف المعمل بنجاح');
        }
      } catch (e) {
        if (mounted) {
          UIHelpers.showErrorSnackBar(context, 'خطأ في حذف المعمل: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // ===========================================================================
  // 5. دوال بناء مكونات الواجهة المساعدة (UI Helper Widgets)
  // ===========================================================================

  Widget _buildLabImage(ThemeData theme) {
    if (_currentLab.imagePath != null &&
        _currentLab.imagePath!.startsWith('http')) {
      return GestureDetector(
        onTap: () {
          UIHelpers.showImageDialog(
            context: context,
            imageUrl: _currentLab.imagePath!,
          );
        },
        child: Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _currentLab.imagePath!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CustomLoadingIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(Icons.broken_image,
                      size: 50, color: theme.colorScheme.error),
                );
              },
            ),
          ),
        ),
      );
    } else {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.image_not_supported, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Text('لم يتم إضافة صورة للمعمل',
                  style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }
  }

  /// *** [تم التحديث] *** إضافة حقل "نوع المكان".
  Widget _buildLabInfoCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('معلومات المعمل', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildDetailRow(
                icon: Icons.numbers,
                label: 'رقم المعمل',
                value: _currentLab.labNumber),
            const SizedBox(height: 8),
            _buildDetailRow(
                icon: Icons.school_outlined,
                label: 'الكلية',
                value: _currentLab.college),
            const SizedBox(height: 8),
            _buildDetailRow(
                icon: Icons.account_tree_outlined,
                label: 'القسم',
                value: _currentLab.department),
            const SizedBox(height: 8),
            _buildDetailRow(
                icon: Icons.layers_outlined,
                label: 'الدور',
                value: _currentLab.floorNumber),
            const SizedBox(height: 8),
            // --- [الإضافة الجديدة هنا] ---
            _buildDetailRow(
                icon: Icons.category_outlined,
                label: 'نوع المكان',
                value: _currentLab.type),
            const SizedBox(height: 8),
            // --- [نهاية الإضافة] ---
            _buildDetailRow(
              icon: _currentLab.status.icon,
              label: 'الحالة',
              value: _currentLab.status.displayName,
              color: _currentLab.status.color,
            ),
            const SizedBox(height: 8),
            if (_currentLab.notes.isNotEmpty)
              _buildDetailRow(
                  icon: Icons.notes_outlined,
                  label: 'ملاحظات',
                  value: _currentLab.notes),
          ],
        ),
      ),
    );
  }

  /// --- [ويدجت جديد] --- لعرض بطاقة الموقع التفاعلية.
  Widget _buildLocationCard(ThemeData theme) {
    if (_currentLab.locationUrl != null &&
        _currentLab.locationUrl!.isNotEmpty) {
      return ElevatedButton.icon(
        onPressed: _openLocationInMaps,
        icon: const Icon(Icons.map_outlined),
        label: const Text('فتح موقع المعمل المحدد في الخرائط'),
        style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50)),
      );
    }

    final collegeInfo = _collegeLocationData[_currentLab.college];
    if (collegeInfo != null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: InkWell(
          onTap: _openLocationInMaps,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                collegeInfo.imageAsset,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 180,
                    child: Center(child: Icon(Icons.broken_image)),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'عرض موقع ${_currentLab.college} في الخرائط',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDevicesCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الأجهزة', style: theme.textTheme.titleLarge),
                if (_currentLab.status != LabStatus.closed)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddDeviceScreen(labId: _currentLab.id),
                        ),
                      ).then((_) => _loadDevices());
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentLab.status != LabStatus.closed)
              _isLoading
                  ? const Center(child: CustomLoadingIndicator())
                  : _devices.isEmpty
                      ? Center(
                          child: Column(
                            children: [
                              Icon(Icons.computer_outlined,
                                  size: 64,
                                  color:
                                      theme.colorScheme.primary.withAlpha(128)),
                              const SizedBox(height: 16),
                              Text('لا توجد أجهزة مسجلة',
                                  style: theme.textTheme.titleMedium),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: device.imagePath != null &&
                                        device.imagePath!.startsWith('http')
                                    ? CircleAvatar(
                                        backgroundImage:
                                            NetworkImage(device.imagePath!),
                                      )
                                    : const CircleAvatar(
                                        child: Icon(Icons.computer),
                                      ),
                                title: Text(device.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(device.model),
                                    Text(device.serialNumber),
                                  ],
                                ),
                                trailing: Icon(
                                  device.needsMaintenance
                                      ? Icons.build_circle
                                      : Icons.check_circle,
                                  color: device.needsMaintenance
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            ViewDeviceScreen(device: device)),
                                  ).then((_) => _loadDevices());
                                },
                              ),
                            );
                          },
                        )
            else
              Center(
                child: Column(
                  children: [
                    Icon(Icons.lock_outlined,
                        size: 64,
                        color: theme.colorScheme.error.withAlpha(128)),
                    const SizedBox(height: 16),
                    Text('المعمل مغلق',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.error)),
                    Text('لا يمكن إضافة أو عرض الأجهزة',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error.withAlpha(179))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      {required IconData icon,
      required String label,
      required String value,
      Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.grey[700]),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value, style: TextStyle(color: color))),
      ],
    );
  }
}

//------------------------------------------------------------------------------

/// امتداد (Extension) على `LabStatus` لإضافة خصائص مساعدة.
extension LabStatusExtension on LabStatus {
  String get displayName {
    switch (this) {
      case LabStatus.openWithDevices:
        return 'مفتوح مع أجهزة';
      case LabStatus.openNoDevices:
        return 'يوجد مشكلة';
      case LabStatus.closed:
        return 'مغلق';
    }
  }

  IconData get icon {
    switch (this) {
      case LabStatus.openWithDevices:
        return Icons.check_circle;
      case LabStatus.openNoDevices:
        return Icons.warning;
      case LabStatus.closed:
        return Icons.cancel;
    }
  }

  Color get color {
    switch (this) {
      case LabStatus.openWithDevices:
        return Colors.green;
      case LabStatus.openNoDevices:
        return Colors.orange;
      case LabStatus.closed:
        return Colors.red;
    }
  }
}
