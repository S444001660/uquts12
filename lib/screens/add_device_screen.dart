// استيراد المكتبات الضرورية
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';
import '../models/lab_model.dart';
import '../services/firebase_database_service.dart';
import '../services/task_progress_service.dart';
import '../utils/ui_helpers.dart';
import '../utils/validation_utils.dart';
import '../utils/image_utils.dart';
import '../utils/device_form_constants.dart';
import '../services/permissions_service.dart';
import '../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

//------------------------------------------------------------------------------

class AddDeviceScreen extends StatefulWidget {
  final DeviceModel? device;
  final String? labId;
  final Map<String, String?>? scannedBarcodeData;

  const AddDeviceScreen({
    super.key,
    this.device,
    this.labId,
    this.scannedBarcodeData,
  });

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

//------------------------------------------------------------------------------

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _notesController = TextEditingController();
  final _modelController = TextEditingController();
  final _processorController = TextEditingController();
  final _ramSizeController = TextEditingController();
  final _storageTypeController = TextEditingController();
  final _storageSizeController = TextEditingController();
  final _osVersionController = TextEditingController();
  final _extraStorageTypeController = TextEditingController();
  final _extraStorageSizeController = TextEditingController();
  final _universityBarcodeController = TextEditingController();
  final _assetSourceController = TextEditingController();
  final _assetCategoryController = TextEditingController();
  final _assetCodeController = TextEditingController();

  String? _selectedCollege;
  String? _selectedDepartment;
  String? _selectedLab;
  String? _selectedRamSize;
  bool _needsMaintenance = false;
  bool _hasExtraStorage = false;
  File? _capturedImage;
  String? _existingImageUrl;
  List<LabModel> _availableLabs = [];
  bool _isLoading = false;
  String? _error;
  LabModel? _currentSelectedLabDetails;
  bool _canDeleteDevice = false;

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serialNumberController.dispose();
    _notesController.dispose();
    _modelController.dispose();
    _processorController.dispose();
    _ramSizeController.dispose();
    _storageTypeController.dispose();
    _storageSizeController.dispose();
    _osVersionController.dispose();
    _extraStorageTypeController.dispose();
    _extraStorageSizeController.dispose();
    _universityBarcodeController.dispose();
    _assetSourceController.dispose();
    _assetCategoryController.dispose();
    _assetCodeController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 3. منطق العمل الرئيسي (Core Business Logic)
  // ===========================================================================

  Future<DeviceModel?> _performSave() async {
    try {
      if (!(_formKey.currentState?.validate() ?? false)) {
        throw 'يرجى التحقق من صحة البيانات المدخلة';
      }
      setState(() => _isLoading = true);

      final String? finalImageUrl = await _handleImageUpload();
      final now = DateTime.now();
      final isNewDevice = widget.device == null;
      final deviceId =
          widget.device?.id ?? FirebaseDatabaseService.generateUniqueId();
      final currentUser = FirebaseAuth.instance.currentUser;

      String? currentUserName;
      if (isNewDevice && currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        currentUserName = userDoc.data()?['fullName'];
      }
      final deviceToSave = DeviceModel(
        id: deviceId,
        name: _nameController.text.trim(),
        college: _selectedCollege ?? '',
        department: _selectedDepartment ?? '',
        serialNumber: _serialNumberController.text.trim(),
        model: _modelController.text.trim(),
        processor: _processorController.text.trim(),
        ramSize: _ramSizeController.text.trim(),
        storageType: _storageTypeController.text.trim(),
        storageSize: _storageSizeController.text.trim(),
        hasExtraStorage: _hasExtraStorage,
        extraStorageType:
            _hasExtraStorage ? _extraStorageTypeController.text.trim() : null,
        extraStorageSize:
            _hasExtraStorage ? _extraStorageSizeController.text.trim() : null,
        osVersion: _osVersionController.text.trim(),
        notes: _notesController.text.trim(),
        needsMaintenance: _needsMaintenance,
        labId: _selectedLab ?? widget.labId ?? '',
        universityBarcode: _universityBarcodeController.text.trim().isNotEmpty
            ? _universityBarcodeController.text.trim()
            : null,
        assetSource: _assetSourceController.text.trim().isNotEmpty
            ? _assetSourceController.text.trim()
            : null,
        assetCategory: _assetCategoryController.text.trim().isNotEmpty
            ? _assetCategoryController.text.trim()
            : null,
        assetCode: _assetCodeController.text.trim().isNotEmpty
            ? _assetCodeController.text.trim()
            : null,
        createdAt: widget.device?.createdAt ?? now,
        updatedAt: now,
        imagePath: finalImageUrl,
        createdBy: isNewDevice ? currentUser?.uid : widget.device?.createdBy,
        createdByName:
            isNewDevice ? currentUserName : widget.device?.createdByName,
      );

      await FirebaseDatabaseService.addOrUpdateDevice(deviceToSave);

      if (isNewDevice && currentUser != null) {
        await TaskProgressService.updateDeviceRegistrationProgress(
            currentUser.uid);
      }

      return deviceToSave;
    } catch (e) {
      if (mounted) {
        UIHelpers.showSnackBar(
            context: context,
            message: 'خطأ في حفظ الجهاز: $e',
            type: SnackBarType.error);
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveAndPop() async {
    final savedDevice = await _performSave();
    if (savedDevice != null && mounted) {
      UIHelpers.showSnackBar(
          context: context,
          message: 'تم حفظ الجهاز بنجاح',
          type: SnackBarType.success);
      Navigator.pop(context, savedDevice);
    }
  }

  Future<void> _saveAndAddAnother() async {
    final savedDevice = await _performSave();
    if (savedDevice != null && mounted) {
      UIHelpers.showSnackBar(
          context: context,
          message: 'تم حفظ "${savedDevice.name}". يمكنك إضافة جهاز آخر.',
          type: SnackBarType.success);
      _resetFormForNextDevice();
    }
  }

  Future<void> _deleteDevice() async {
    if (widget.device == null) return;
    final confirmDelete = await UIHelpers.showConfirmationDialog(
        context: context,
        title: 'حذف الجهاز',
        content: 'هل أنت متأكد من حذف هذا الجهاز؟',
        confirmText: 'حذف',
        cancelText: 'إلغاء',
        confirmColor: Colors.red);
    if (confirmDelete == true) {
      setState(() => _isLoading = true);
      try {
        await FirebaseDatabaseService.deleteDevice(widget.device!.id);
        if (!mounted) return;
        UIHelpers.showSnackBar(
            context: context,
            message: 'تم حذف الجهاز بنجاح',
            type: SnackBarType.success);
        Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          UIHelpers.showSnackBar(
              context: context,
              message: 'خطأ في حذف الجهاز: $e',
              type: SnackBarType.error);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // ===========================================================================
  // 4. دالة بناء واجهة المستخدم (UI Build Method)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.device != null;
    final isLabSelected = _selectedLab != null;
    final shouldShowBarcodeSection = (widget.scannedBarcodeData != null &&
            !isEditing) ||
        (isEditing && (widget.device!.universityBarcode?.isNotEmpty == true));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل جهاز' : 'إضافة جهاز'),
          actions: [
            if (isEditing && _canDeleteDevice)
              IconButton(
                  onPressed: _deleteDevice,
                  icon: const Icon(Icons.delete),
                  tooltip: 'حذف الجهاز'),
          ],
        ),
        body: _isLoading
            ? const Center(child: CustomLoadingIndicator())
            : _error != null
                ? Center(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('حدث خطأ: $_error',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                          onPressed: _loadInitialData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة')),
                    ],
                  ))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: _buildFormContent(theme, isEditing, isLabSelected,
                          shouldShowBarcodeSection),
                    ),
                  ),
      ),
    );
  }

  // ===========================================================================
  // 5. الدوال المساعدة والويدجتات الفرعية (Helpers & Sub-Widgets)
  // ===========================================================================

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final labs = await FirebaseDatabaseService.getLabs();
      if (!mounted) return;
      setState(() {
        _availableLabs = labs
            .where((lab) =>
                lab.id.isNotEmpty &&
                lab.labNumber.isNotEmpty &&
                lab.college.isNotEmpty)
            .toList();
      });
      if (widget.device != null) {
        _loadDeviceData(widget.device!);
      } else if (widget.scannedBarcodeData != null) {
        _loadScannedBarcodeData(widget.scannedBarcodeData!);
      }
      if (widget.labId != null) {
        await _loadLabDetails(widget.labId!);
      }
    } catch (e) {
      if (mounted) _error = 'خطأ في تحميل البيانات: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPermissions() async {
    final canDelete = await PermissionsService.hasPermission('delete_device');
    if (mounted) setState(() => _canDeleteDevice = canDelete);
  }

  void _loadDeviceData(DeviceModel device) {
    _nameController.text = device.name;
    _serialNumberController.text = device.serialNumber;
    _modelController.text = device.model;
    _processorController.text = device.processor;
    _ramSizeController.text = device.ramSize ?? '';
    _storageTypeController.text = device.storageType;
    _storageSizeController.text = device.storageSize;
    _osVersionController.text = device.osVersion;
    _notesController.text = device.notes;
    _selectedCollege = device.college;
    _selectedDepartment = device.department;
    _needsMaintenance = device.needsMaintenance;
    _hasExtraStorage = device.hasExtraStorage;
    _universityBarcodeController.text = device.universityBarcode ?? '';
    _assetSourceController.text = device.assetSource ?? '';
    _assetCategoryController.text = device.assetCategory ?? '';
    _assetCodeController.text = device.assetCode ?? '';
    _extraStorageTypeController.text = device.extraStorageType ?? '';
    _extraStorageSizeController.text = device.extraStorageSize ?? '';
    _existingImageUrl = device.imagePath;
    if (_availableLabs.any((lab) => lab.id == device.labId)) {
      _selectedLab = device.labId;
      _currentSelectedLabDetails =
          _availableLabs.firstWhere((lab) => lab.id == device.labId);
    }
    _selectedRamSize = device.ramSize;
  }

  void _loadScannedBarcodeData(Map<String, String?> barcodeData) {
    _universityBarcodeController.text = barcodeData['barcode'] ?? '';
    _assetCodeController.text = barcodeData['assetCode'] ?? '';
    _serialNumberController.text = barcodeData['serialNumber'] ?? '';
    _assetSourceController.text = barcodeData['assetSource'] ?? '';
    _assetCategoryController.text = barcodeData['assetCategory'] ?? '';
  }

  Future<void> _loadLabDetails(String labId) async {
    try {
      final lab = await FirebaseDatabaseService.getLabById(labId);
      if (lab != null && mounted) {
        setState(() {
          _selectedLab = lab.id;
          _selectedCollege = lab.college;
          _selectedDepartment = lab.department;
          _currentSelectedLabDetails = lab;
        });
      }
    } catch (e) {
      if (mounted) {
        UIHelpers.showSnackBar(
            context: context,
            message: 'خطأ في تحميل تفاصيل المعمل: $e',
            type: SnackBarType.error);
      }
    }
  }

  void _onLabSelected(LabModel? lab) {
    setState(() {
      _selectedLab = lab?.id;
      _selectedCollege = lab?.college;
      _selectedDepartment = lab?.department;
      _currentSelectedLabDetails = lab;
    });
  }

  Future<void> _pickImage() async {
    final pickedImage = await ImageUtils.pickImage(
        context: context, source: ImageSource.camera);
    if (pickedImage != null) {
      setState(() {
        _capturedImage = pickedImage;
        _existingImageUrl = null;
      });
    }
  }

  Future<void> _validateInputs() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      throw 'يرجى التحقق من صحة البيانات المدخلة';
    }
    if (_needsMaintenance &&
        _capturedImage == null &&
        _existingImageUrl == null) {
      throw 'يجب التقاط صورة عند تحديد "يحتاج إلى صيانة".';
    }
    final serialNumber = _serialNumberController.text.trim();
    if (!_needsMaintenance && serialNumber.isNotEmpty) {
      final serialExists = await FirebaseDatabaseService.serialNumberExists(
          serialNumber,
          excludeId: widget.device?.id);
      if (serialExists) {
        throw 'الرقم التسلسلي موجود بالفعل لجهاز آخر.';
      }
    }
  }

  Future<String?> _handleImageUpload() async {
    if (_capturedImage == null) {
      return _needsMaintenance ? _existingImageUrl : null;
    }
    final storagePath =
        'device_images/${widget.device?.id ?? FirebaseDatabaseService.generateUniqueId()}';
    return await FirebaseDatabaseService.uploadImageToFirebaseStorage(
        _capturedImage!, storagePath);
  }

  void _resetFormForNextDevice() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _serialNumberController.clear();
    _notesController.clear();
    _modelController.clear();
    _processorController.clear();
    _ramSizeController.clear();
    _storageTypeController.clear();
    _storageSizeController.clear();
    _osVersionController.clear();
    _extraStorageTypeController.clear();
    _extraStorageSizeController.clear();
    _universityBarcodeController.clear();
    _assetSourceController.clear();
    _assetCategoryController.clear();
    _assetCodeController.clear();
    setState(() {
      _needsMaintenance = false;
      _hasExtraStorage = false;
      _capturedImage = null;
      _existingImageUrl = null;
      _selectedRamSize = null;
    });
  }

  Widget _buildDetailRow(
      {required IconData icon, required String label, required String value}) {
    return Row(children: [
      Icon(icon, color: Colors.grey[700]),
      const SizedBox(width: 12),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
      Expanded(child: Text(value)),
    ]);
  }

  Widget _buildLabDetailsCard(LabModel lab) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildDetailRow(
          icon: Icons.school_outlined, label: 'الكلية', value: lab.college),
      const SizedBox(height: 8),
      _buildDetailRow(
          icon: Icons.account_tree_outlined,
          label: 'القسم',
          value: lab.department),
      const SizedBox(height: 8),
      _buildDetailRow(
          icon: Icons.layers_outlined,
          label: 'رقم المعمل',
          value: lab.labNumber),
      const SizedBox(height: 8),
      _buildDetailRow(
          icon: Icons.category_outlined, label: 'النوع', value: lab.type),
      const SizedBox(height: 8),
      _buildDetailRow(
          icon: Icons.info_outline,
          label: 'الحالة',
          value: lab.getStatusText()),
    ]);
  }

  /// *** [تم الإكمال] *** ويدجت يحتوي على جميع حقول الفورم.
  Widget _buildFormContent(ThemeData theme, bool isEditing, bool isLabSelected,
      bool shouldShowBarcodeSection) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<LabModel>(
          decoration: InputDecoration(
              labelText: 'اختيار المعمل',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          value: _currentSelectedLabDetails,
          items: _availableLabs
              .map((lab) => DropdownMenuItem<LabModel>(
                  value: lab, child: Text('${lab.labNumber} - ${lab.college}')))
              .toList(),
          onChanged: _onLabSelected,
          validator: (value) => ValidationUtils.validateDropdown(value?.id,
              errorMessage: 'الرجاء اختيار المعمل'),
        ),
        const SizedBox(height: 16),
        if (isLabSelected) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تفاصيل المعمل',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_currentSelectedLabDetails != null)
                      _buildLabDetailsCard(_currentSelectedLabDetails!),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (shouldShowBarcodeSection)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(children: [
              Text('بيانات الباركود',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ]),
          ),
        SwitchListTile(
          title: const Text('يحتاج إلى صيانة'),
          subtitle: Text(
            _needsMaintenance
                ? 'الجهاز في حالة صيانة'
                : 'الجهاز يعمل بشكل طبيعي',
            style: TextStyle(
                color: _needsMaintenance ? Colors.orange : Colors.green),
          ),
          value: _needsMaintenance,
          onChanged: (value) {
            setState(() => _needsMaintenance = value);
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _formKey.currentState?.validate());
          },
          activeColor: Colors.orange,
        ),
        const SizedBox(height: 16),
        if (_needsMaintenance) ...[
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.camera_alt),
            label: Text(_capturedImage == null && _existingImageUrl == null
                ? 'التقاط صورة الصيانة'
                : 'تغيير الصورة'),
          ),
          const SizedBox(height: 12),
          if (_capturedImage != null || _existingImageUrl != null)
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _capturedImage != null
                    ? Image.file(_capturedImage!,
                        height: 200, width: double.infinity, fit: BoxFit.cover)
                    : Image.network(_existingImageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) =>
                            loadingProgress == null
                                ? child
                                : const Center(
                                    child: CustomLoadingIndicator()),
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                                child: Icon(Icons.broken_image, size: 50))),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.zoom_out_map, color: Colors.white),
                    onPressed: () {
                      if (_capturedImage != null) {
                        UIHelpers.showImageDialog(
                            context: context, imageFile: _capturedImage!);
                      } else if (_existingImageUrl != null) {
                        UIHelpers.showImageDialog(
                            context: context, imageUrl: _existingImageUrl!);
                      }
                    },
                  ),
                ),
              ),
            ]),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
              labelText: 'اسم الجهاز',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          validator: (value) {
            if (_needsMaintenance) return null;
            return ValidationUtils.validateName(value);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _serialNumberController,
          decoration: InputDecoration(
              labelText: 'الرقم التسلسلي (10 أرقام)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (value) {
            if (_needsMaintenance) return null;
            if (value == null || value.isEmpty) {
              return 'الرقم التسلسلي مطلوب.';
            }
            if (value.length != 10) {
              return 'يجب أن يتكون الرقم التسلسلي من 10 أرقام.';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
              labelText: 'الموديل',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          value:
              _modelController.text.isNotEmpty ? _modelController.text : null,
          items: DeviceFormConstants.models
              .map(
                  (model) => DropdownMenuItem(value: model, child: Text(model)))
              .toList(),
          onChanged: (value) => _modelController.text = value ?? '',
          validator: (value) {
            if (_needsMaintenance) return null;
            return ValidationUtils.validateDropdown(value,
                errorMessage: 'الرجاء اختيار الموديل');
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
              labelText: 'المعالج',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          value: _processorController.text.isNotEmpty
              ? _processorController.text
              : null,
          items: DeviceFormConstants.processors
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) => _processorController.text = value ?? '',
          validator: (value) {
            if (_needsMaintenance) return null;
            return ValidationUtils.validateDropdown(value,
                errorMessage: 'المعالج مطلوب');
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
              labelText: 'حجم الرام',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          value: _selectedRamSize,
          items: DeviceFormConstants.ramSizes
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedRamSize = value;
              _ramSizeController.text = value ?? '';
            });
          },
          validator: (value) {
            if (_needsMaintenance) return null;
            return ValidationUtils.validateDropdown(value,
                errorMessage: 'حجم الرام مطلوب');
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
              labelText: 'نوع التخزين',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          value: _storageTypeController.text.isNotEmpty
              ? _storageTypeController.text
              : null,
          items: DeviceFormConstants.storageTypes
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) => _storageTypeController.text = value ?? '',
          validator: (value) {
            if (_needsMaintenance) return null;
            return ValidationUtils.validateDropdown(value,
                errorMessage: 'نوع التخزين مطلوب');
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
              labelText: 'حجم التخزين',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          value: _storageSizeController.text.isNotEmpty
              ? _storageSizeController.text
              : null,
          items: DeviceFormConstants.storageSizes
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) => _storageSizeController.text = value ?? '',
          validator: (value) {
            if (_needsMaintenance) return null;
            return ValidationUtils.validateDropdown(value,
                errorMessage: 'حجم التخزين مطلوب');
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
              labelText: 'نظام التشغيل',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          value: _osVersionController.text.isNotEmpty
              ? _osVersionController.text
              : null,
          items: DeviceFormConstants.osVersions
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) => _osVersionController.text = value ?? '',
          validator: (value) {
            if (_needsMaintenance) return null;
            return ValidationUtils.validateDropdown(value,
                errorMessage: 'نظام التشغيل مطلوب');
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('يوجد تخزين إضافي'),
          value: _hasExtraStorage,
          onChanged: (value) => setState(() => _hasExtraStorage = value),
        ),
        if (_hasExtraStorage) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
                labelText: 'نوع التخزين الإضافي',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))),
            value: _extraStorageTypeController.text.isNotEmpty
                ? _extraStorageTypeController.text
                : null,
            items: DeviceFormConstants.storageTypes
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) =>
                _extraStorageTypeController.text = value ?? '',
            validator: (value) {
              if (_needsMaintenance || !_hasExtraStorage) return null;
              return ValidationUtils.validateDropdown(value,
                  errorMessage: 'نوع التخزين الإضافي مطلوب');
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
                labelText: 'حجم التخزين الإضافي',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))),
            value: _extraStorageSizeController.text.isNotEmpty
                ? _extraStorageSizeController.text
                : null,
            items: DeviceFormConstants.storageSizes
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) =>
                _extraStorageSizeController.text = value ?? '',
            validator: (value) {
              if (_needsMaintenance || !_hasExtraStorage) return null;
              return ValidationUtils.validateDropdown(value,
                  errorMessage: 'حجم التخزين الإضافي مطلوب');
            },
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
              labelText: 'ملاحظات',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          minLines: 3,
          maxLines: 5,
          validator: (value) {
            if (_needsMaintenance && (value == null || value.trim().isEmpty)) {
              return 'حقل الملاحظات إجباري في حالة الصيانة.';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        if (isEditing)
          FilledButton.icon(
            onPressed: _isLoading ? null : _saveAndPop,
            icon: const Icon(Icons.save),
            label: const Text('حفظ التعديلات'),
          )
        else
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _saveAndPop,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ وخروج'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _isLoading ? null : _saveAndAddAnother,
                  icon: const Icon(Icons.add),
                  label: const Text('حفظ وإضافة آخر'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
