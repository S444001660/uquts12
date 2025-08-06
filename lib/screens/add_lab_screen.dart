// استيراد المكتبات الضرورية
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- استيراد الملفات الأخرى اللازمة ---
import '../models/lab_model.dart';
import '../services/firebase_database_service.dart';
import '../utils/ui_helpers.dart';
import '../utils/validation_utils.dart';
import '../utils/image_utils.dart';
import '../utils/device_form_constants.dart';
import 'add_device_screen.dart';
import '../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

// -----------------------------------------------------------------

class AddLabScreen extends StatefulWidget {
  final LabModel? lab;
  const AddLabScreen({super.key, this.lab});

  @override
  State<AddLabScreen> createState() => _AddLabScreenState();
}

//------------------------------------------------------------------------------

class _AddLabScreenState extends State<AddLabScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  static const double _defaultSpacing = 16.0;
  static const int _maxImageSizeBytes = 5 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labNumberController;
  late final TextEditingController _notesController;

  String? _selectedCollege;
  String? _selectedDepartment;
  String? _selectedFloor;
  String? _selectedType;
  LabStatus _labStatus = LabStatus.openWithDevices;
  bool _isLoading = false;
  File? _capturedImage;
  String? _existingImageUrl;

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _labNumberController = TextEditingController(text: widget.lab?.labNumber);
    _notesController = TextEditingController(text: widget.lab?.notes);
    _loadExistingLabData();
  }

  @override
  void dispose() {
    _labNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 3. منطق العمل الرئيسي (Core Business Logic)
  // ===========================================================================

  Future<LabModel?> _performSave() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      UIHelpers.showSnackBar(
          context: context,
          message: 'يرجى التحقق من صحة البيانات',
          type: SnackBarType.error);
      return null;
    }

    if ((_labStatus == LabStatus.openNoDevices ||
            _labStatus == LabStatus.closed) &&
        _capturedImage == null &&
        _existingImageUrl == null) {
      UIHelpers.showSnackBar(
          context: context,
          message: 'يرجى التقاط صورة للحالة الحالية للمعمل',
          type: SnackBarType.error);
      return null;
    }

    setState(() => _isLoading = true);

    final labNumber = _labNumberController.text.trim();

    try {
      final exists = await _isLabNumberExists(labNumber);
      if (exists) {
        if (mounted) {
          UIHelpers.showSnackBar(
              context: context,
              message: 'رقم المعمل موجود مسبقًا، يرجى اختيار رقم مختلف',
              type: SnackBarType.error);
        }
        return null;
      }

      final labId =
          widget.lab?.id ?? FirebaseDatabaseService.generateUniqueId();
      final now = DateTime.now();
      String? finalImagePath;
      final currentUser = FirebaseAuth.instance.currentUser;
      final isNewLab = widget.lab == null;

      String? currentUserName;
      if (isNewLab && currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        currentUserName = userDoc.data()?['fullName'];
      }

      if (_capturedImage != null) {
        finalImagePath =
            await FirebaseDatabaseService.uploadImageToFirebaseStorage(
                _capturedImage!, 'lab_images/$labId');
      } else if (_existingImageUrl != null &&
          (_labStatus != LabStatus.openWithDevices)) {
        finalImagePath = _existingImageUrl;
      }

      final newLab = LabModel(
        id: labId,
        labNumber: labNumber,
        college: _selectedCollege!,
        department: _selectedDepartment!,
        floorNumber: _selectedFloor!,
        type: _selectedType!,
        status: _labStatus,
        notes: _notesController.text.trim(),
        imagePath: finalImagePath,
        createdAt: widget.lab?.createdAt ?? now,
        updatedAt: now,
        deviceIds: widget.lab?.deviceIds ?? [],
        createdBy: isNewLab ? currentUser?.uid : widget.lab?.createdBy,
        createdByName: isNewLab ? currentUserName : widget.lab?.createdByName,
        locationUrl: widget.lab?.locationUrl,
      );

      await FirebaseDatabaseService.addOrUpdateLab(newLab);
      return newLab;
    } catch (e) {
      if (mounted) {
        UIHelpers.showSnackBar(
            context: context,
            message: 'خطأ في حفظ المعمل: $e',
            type: SnackBarType.error);
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveLabAndPop() async {
    final newLab = await _performSave();
    if (newLab != null && mounted) {
      UIHelpers.showSnackBar(
          context: context,
          message: 'تم حفظ المعمل بنجاح',
          type: SnackBarType.success);
      Navigator.pop(context, newLab);
    }
  }

  Future<void> _saveLabAndAddDevice() async {
    final newLab = await _performSave();
    if (newLab != null && mounted) {
      UIHelpers.showSnackBar(
          context: context,
          message: 'تم حفظ المعمل بنجاح، سيتم نقلك لإضافة جهاز...',
          type: SnackBarType.success);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AddDeviceScreen(labId: newLab.id),
        ),
      );
    }
  }

  // ===========================================================================
  // 4. دالة بناء واجهة المستخدم (UI Build Method)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    // يتم تعريف المتغير هنا لتحديد ما إذا كانت الشاشة في وضع التعديل أم الإضافة
    final isEditing = widget.lab != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          // <-- تم الاستفادة من المتغير هنا لتحديد عنوان الصفحة
          title: Text(isEditing ? 'تعديل معمل' : 'إضافة معمل'),
          actions: [
            if (_capturedImage != null || _existingImageUrl != null)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => setState(() {
                  _capturedImage = null;
                  _existingImageUrl = null;
                }),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CustomLoadingIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(_defaultSpacing),
                  children: [
                    _LabStatusDropdown(
                      initialValue: _labStatus,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _labStatus = value;
                          if (_labStatus == LabStatus.openWithDevices) {
                            _capturedImage = null;
                            _existingImageUrl = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: _defaultSpacing),
                    _CollegeDropdown(
                      selectedValue: _selectedCollege,
                      onChanged: (value) {
                        if (value == null || value == _selectedCollege) return;
                        setState(() {
                          _selectedCollege = value;
                          _selectedDepartment = null;
                        });
                      },
                    ),
                    const SizedBox(height: _defaultSpacing),
                    _DepartmentDropdown(
                      college: _selectedCollege,
                      selectedValue: _selectedDepartment,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedDepartment = value);
                      },
                    ),
                    const SizedBox(height: _defaultSpacing),
                    _CustomTextField(
                      controller: _labNumberController,
                      labelText: 'رقم المعمل',
                      validator: ValidationUtils.validateName,
                    ),
                    const SizedBox(height: _defaultSpacing),
                    _FloorDropdown(
                      selectedValue: _selectedFloor,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedFloor = value);
                      },
                    ),
                    const SizedBox(height: _defaultSpacing),
                    _LabTypeDropdown(
                      selectedValue: _selectedType,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedType = value);
                      },
                    ),
                    const SizedBox(height: _defaultSpacing),
                    _CustomTextField(
                      controller: _notesController,
                      labelText: 'ملاحظات',
                      maxLines: 3,
                    ),
                    const SizedBox(height: _defaultSpacing),
                    _ImageCaptureSection(
                      capturedImage: _capturedImage,
                      existingImageUrl: _existingImageUrl,
                      onPickImage: _pickImage,
                    ),
                    const SizedBox(height: 42),
                    _ActionButtons(
                      // <-- تم الاستفادة من المتغير هنا لتمريره إلى ويدجت الأزرار
                      isEditing: isEditing,
                      labStatus: _labStatus,
                      onSave: _saveLabAndPop,
                      onSaveAndAddDevice: _saveLabAndAddDevice,
                      onAddDeviceToLab: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AddDeviceScreen(labId: widget.lab!.id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ===========================================================================
  // 5. الدوال المساعدة (Helper Functions)
  // ===========================================================================

  void _loadExistingLabData() {
    final lab = widget.lab;
    if (lab == null) return;

    setState(() {
      _selectedFloor = lab.floorNumber;
      _labStatus = lab.status;
      _selectedCollege = lab.college;
      if (DeviceFormConstants.departments[lab.college]
              ?.contains(lab.department) ??
          false) {
        _selectedDepartment = lab.department;
      }
      _selectedType = lab.type;
      _existingImageUrl = lab.imagePath;
    });
  }

  Future<void> _pickImage() async {
    try {
      final pickedImage = await ImageUtils.pickImage(
        context: context,
        source: ImageSource.camera,
        maxSizeInBytes: _maxImageSizeBytes,
      );

      if (pickedImage != null) {
        setState(() {
          _capturedImage = pickedImage;
          _existingImageUrl = null;
        });
      }
    } catch (e) {
      if (mounted) {
        UIHelpers.showSnackBar(
          context: context,
          message: e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : 'خطأ في اختيار الصورة',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<bool> _isLabNumberExists(String labNumber) async {
    final isEditing = widget.lab != null;
    if (isEditing && labNumber == widget.lab!.labNumber) {
      return false;
    }
    return await FirebaseDatabaseService.isLabNumberExists(labNumber,
        excludeId: isEditing ? widget.lab!.id : null);
  }
}

// ===========================================================================
// 6. الويدجتات الفرعية المنفصلة (Separated Sub-Widgets)
// ===========================================================================

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? Function(String?)? validator;
  final int maxLines;

  const _CustomTextField({
    required this.controller,
    required this.labelText,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: labelText,
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: validator,
    );
  }
}

class _LabStatusDropdown extends StatelessWidget {
  final LabStatus initialValue;
  final ValueChanged<LabStatus?> onChanged;

  const _LabStatusDropdown(
      {required this.initialValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<LabStatus>(
      value: initialValue,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'حالة المعمل',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: const [
        DropdownMenuItem(
          value: LabStatus.openWithDevices,
          child: Row(children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('مفتوح مع أجهزة')
          ]),
        ),
        DropdownMenuItem(
          value: LabStatus.openNoDevices,
          child: Row(children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('يوجد مشكلة')
          ]),
        ),
        DropdownMenuItem(
          value: LabStatus.closed,
          child: Row(children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('مغلق')
          ]),
        ),
      ],
    );
  }
}

class _CollegeDropdown extends StatelessWidget {
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const _CollegeDropdown({this.selectedValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedValue,
      onChanged: onChanged,
      validator: (v) => ValidationUtils.validateDropdown(v,
          errorMessage: 'الرجاء اختيار الكلية'),
      decoration: InputDecoration(
        labelText: 'الكلية',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: DeviceFormConstants.colleges
          .map((college) =>
              DropdownMenuItem(value: college, child: Text(college)))
          .toList(),
    );
  }
}

class _DepartmentDropdown extends StatelessWidget {
  final String? college;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const _DepartmentDropdown({
    this.college,
    this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final departmentList =
        (college != null ? DeviceFormConstants.departments[college] : null) ??
            [];

    return DropdownButtonFormField<String>(
      value: selectedValue,
      onChanged: onChanged,
      validator: (v) => ValidationUtils.validateDropdown(v,
          errorMessage: 'الرجاء اختيار القسم'),
      decoration: InputDecoration(
        labelText: 'القسم',
        hintText: college == null ? 'الرجاء اختيار الكلية أولاً' : 'اختر القسم',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: departmentList.map((String department) {
        return DropdownMenuItem<String>(
          value: department,
          child: Text(department),
        );
      }).toList(),
    );
  }
}

class _FloorDropdown extends StatelessWidget {
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const _FloorDropdown({this.selectedValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedValue,
      onChanged: onChanged,
      validator: (v) => ValidationUtils.validateDropdown(v,
          errorMessage: 'الرجاء اختيار الدور'),
      decoration: InputDecoration(
        labelText: 'الدور',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: DeviceFormConstants.floors
          .map((floor) => DropdownMenuItem(value: floor, child: Text(floor)))
          .toList(),
    );
  }
}

class _LabTypeDropdown extends StatelessWidget {
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const _LabTypeDropdown({this.selectedValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedValue,
      onChanged: onChanged,
      validator: (v) => ValidationUtils.validateDropdown(v,
          errorMessage: 'الرجاء اختيار نوع المكان'),
      decoration: InputDecoration(
        labelText: 'نوع المكان',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: DeviceFormConstants.labTypes
          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
          .toList(),
    );
  }
}

class _ImageCaptureSection extends StatelessWidget {
  final File? capturedImage;
  final String? existingImageUrl;
  final VoidCallback onPickImage;

  const _ImageCaptureSection({
    this.capturedImage,
    this.existingImageUrl,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (capturedImage != null) {
      imageProvider = FileImage(capturedImage!);
    } else if (existingImageUrl != null &&
        existingImageUrl!.startsWith('http')) {
      imageProvider = NetworkImage(existingImageUrl!);
    }

    final hasImage = imageProvider != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: imageProvider,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onPickImage,
          icon: const Icon(Icons.camera_alt),
          label: Text(hasImage ? 'تغيير الصورة' : 'التقاط صورة'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }
}

/// *** [تم التحديث] *** ويدجت مسؤول عن عرض الأزرار السفلية مع استخدام الثيم.
class _ActionButtons extends StatelessWidget {
  final bool isEditing;
  final LabStatus labStatus;
  final VoidCallback onSave;
  final VoidCallback onSaveAndAddDevice;
  final VoidCallback onAddDeviceToLab;

  const _ActionButtons({
    required this.isEditing,
    required this.labStatus,
    required this.onSave,
    required this.onSaveAndAddDevice,
    required this.onAddDeviceToLab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isEditing) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
              child: const Text('حفظ التغييرات'),
            ),
          ),
          if (labStatus != LabStatus.closed) ...[
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onAddDeviceToLab,
                icon: const Icon(Icons.add_to_queue),
                label: const Text('إضافة جهاز'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50)),
            child: const Text('إضافة المعمل'),
          ),
          if (labStatus != LabStatus.closed) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onSaveAndAddDevice,
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                  minimumSize: const Size(double.infinity, 50)),
              child: const Text('إضافة معمل مع الجهاز'),
            ),
          ],
        ],
      );
    }
  }
}
