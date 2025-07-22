// استيراد المكتبات الضرورية
import 'dart:io'; // للتعامل مع الملفات (مثل صورة المعمل).
import 'package:flutter/material.dart'; // مكتبة فلاتر الأساسية لبناء واجهة المستخدم.
import 'package:uuid/uuid.dart'; // لتوليد معرفات فريدة (IDs).
import 'package:image_picker/image_picker.dart'; // لاختيار الصور من الكاميرا أو المعرض.

// --- ملاحظة: تأكد من أن هذه الاستيرادات تتوافق مع هيكل مشروعك ---
import '../models/lab_model.dart'; // استيراد نموذج بيانات المعمل.
import '../services/firebase_database_service.dart'; // خدمات قاعدة البيانات
import '../utils/ui_helpers.dart'; // دوال مساعدة لعرض عناصر واجهة المستخدم (مثل SnackBar).
import '../utils/validation_utils.dart'; // دوال للتحقق من صحة مدخلات الفورم.
import '../utils/image_utils.dart'; // دوال مساعدة للتعامل مع الصور.
import '../utils/device_form_constants.dart'; // ثوابت وقوائم مستخدمة في الفورم.
import 'add_device_screen.dart'; // شاشة إضافة/تعديل جهاز.
// -----------------------------------------------------------------

/// ويدجت شاشة إضافة أو تعديل معمل، وهي StatefulWidget لأن حالتها تتغير.
class AddLabScreen extends StatefulWidget {
  /// متغير لتمرير بيانات معمل موجود مسبقًا في حال التعديل.
  /// يكون 'null' عند إضافة معمل جديد.
  final LabModel? lab;

  const AddLabScreen({super.key, this.lab});

  @override
  State<AddLabScreen> createState() => _AddLabScreenState();
}

//------------------------------------------------------------------------------

/// كلاس الحالة (State) الخاص بـ AddLabScreen.
class _AddLabScreenState extends State<AddLabScreen> {
  // --- ثوابت لتنظيم الكود ---
  // تستخدم لتوحيد المسافات وأبعاد العناصر في الواجهة.
  static const double _defaultSpacing = 16.0;
  static const int _maxImageSizeBytes = 5 * 1024 * 1024; // 5 MB

  //------------------------------------------------------------------------------

  // --- مفاتيح ومتحكمات الفورم ---
  // مفتاح للتحكم في حالة الفورم والتحقق من صحته.
  final _formKey = GlobalKey<FormState>();
  // متحكمات لربط حقول النص بالـ State.
  late final TextEditingController _labNumberController;
  late final TextEditingController _notesController;

  //------------------------------------------------------------------------------

  // --- متغيرات الحالة (State) ---
  // لتخزين القيم التي يختارها المستخدم أو التي تتغير في الواجهة.
  String? _selectedCollege;
  String? _selectedDepartment;
  String? _selectedFloor;
  String? _selectedType;
  LabStatus _labStatus = LabStatus.openWithDevices;
  bool _isLoading = false;
  File? _capturedImage;
  String? _existingImageUrl;

  //------------------------------------------------------------------------------

  /// دالة تُستدعى مرة واحدة عند بناء الويدجت لأول مرة.
  /// تستخدم لتهيئة المتحكمات وتحميل البيانات الأولية.
  @override
  void initState() {
    super.initState();
    // تهيئة المتحكمات هنا وتعبئتها بالبيانات الموجودة في حالة التعديل.
    _labNumberController = TextEditingController(text: widget.lab?.labNumber);
    _notesController = TextEditingController(text: widget.lab?.notes);
    _loadExistingLabData();
  }

  //------------------------------------------------------------------------------

  /// دالة تُستدعى عند إزالة الويدجت، لتحرير الموارد ومنع تسرب الذاكرة.
  @override
  void dispose() {
    _labNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  //------------------------------------------------------------------------------

  /// دالة لملء متغيرات الحالة ببيانات معمل موجود مسبقًا (في وضع التعديل).
  void _loadExistingLabData() {
    final lab = widget.lab;
    if (lab == null) return; // إذا كنا في وضع الإضافة، لا تفعل شيئًا.

    // تعبئة متغيرات الحالة بالبيانات القادمة من كائن المعمل.
    _selectedFloor = lab.floorNumber;
    _labStatus = lab.status;
    _selectedCollege = lab.college;
    // التحقق من أن القسم لا يزال موجودًا في القائمة المحدثة قبل تحديده.
    if (DeviceFormConstants.departments[lab.college]
            ?.contains(lab.department) ??
        false) {
      _selectedDepartment = lab.department;
    }
    _selectedType = lab.type;
    _existingImageUrl = lab.imagePath;
  }

  //------------------------------------------------------------------------------

  /// دالة غير متزامنة لالتقاط صورة باستخدام الكاميرا مع التحقق من حجمها.
  Future<void> _pickImage() async {
    try {
      final pickedImage = await ImageUtils.pickImage(
        context: context,
        source: ImageSource.camera,
        maxSizeInBytes: _maxImageSizeBytes,
      );

      if (pickedImage != null) {
        setState(() {
          _capturedImage = pickedImage; // تخزين الصورة الملتقطة حديثًا.
          _existingImageUrl = null; // حذف مرجع الصورة القديمة.
        });
      }
    } catch (e) {
      // عرض رسالة خطأ في حالة فشل التقاط الصورة أو تجاوز الحجم.
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

  //------------------------------------------------------------------------------

  /// دالة الحفظ الأساسية التي تحتوي على منطق التحقق والحفظ، لإعادة استخدامها.
  Future<LabModel?> _performSave() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      UIHelpers.showSnackBar(
        context: context,
        message: 'يرجى التحقق من صحة البيانات',
        type: SnackBarType.error,
      );
      return null;
    }

    // شرط يلزم المستخدم بالتقاط صورة إذا كان المعمل مغلقًا أو به مشكلة.
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

    try {
      final labId = widget.lab?.id ?? const Uuid().v4();
      final now = DateTime.now();
      String? finalImagePath;

      // منطق تحديد مسار الصورة النهائي.
      if (_capturedImage != null) {
        // إذا التقط المستخدم صورة جديدة، يتم رفعها.
        finalImagePath =
            await FirebaseDatabaseService.uploadImageToFirebaseStorage(
                _capturedImage!, 'lab_images/$labId');
      } else if (_existingImageUrl != null &&
          (_labStatus != LabStatus.openWithDevices)) {
        // إذا كانت هناك صورة قديمة والمعمل ليس في الحالة الطبيعية، يتم الاحتفاظ بها.
        finalImagePath = _existingImageUrl;
      }

      // بناء كائن المعمل الجديد بالبيانات المحدثة.
      final newLab = LabModel(
        id: labId,
        labNumber: _labNumberController.text.trim(),
        college: _selectedCollege!,
        department: _selectedDepartment!,
        floorNumber: _selectedFloor!,
        type: _selectedType!,
        status: _labStatus,
        notes: _notesController.text.trim(),
        locationUrl: widget.lab?.locationUrl,
        imagePath: finalImagePath,
        createdAt: widget.lab?.createdAt ?? now,
        updatedAt: now,
        deviceIds: widget.lab?.deviceIds ?? [],
      );

      // حفظ المعمل في قاعدة البيانات وإرجاع الكائن المحفوظ.
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

  //------------------------------------------------------------------------------

  /// دالة مرتبطة بزر الحفظ العادي، تحفظ البيانات ثم تعود للشاشة السابقة.
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

  //------------------------------------------------------------------------------

  /// دالة مرتبطة بزر "حفظ وإضافة جهاز"، تحفظ المعمل ثم تنتقل مباشرة لشاشة إضافة جهاز.
  Future<void> _saveLabAndAddDevice() async {
    final newLab = await _performSave();
    if (newLab != null && mounted) {
      UIHelpers.showSnackBar(
          context: context,
          message: 'تم حفظ المعمل بنجاح، سيتم نقلك لإضافة جهاز...',
          type: SnackBarType.success);

      // استبدال الشاشة الحالية بشاشة إضافة جهاز لتجربة مستخدم أفضل.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AddDeviceScreen(labId: newLab.id),
        ),
      );
    }
  }

  //------------------------------------------------------------------------------

  /// الدالة الأساسية لبناء واجهة المستخدم (UI) للشاشة بأكملها.
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.lab != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل معمل' : 'إضافة معمل'),
          actions: [
            // عرض أيقونة حذف الصورة فقط إذا كانت هناك صورة.
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
            ? const Center(child: CircularProgressIndicator())
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
                          // إذا تم تغيير الحالة إلى "مفتوح مع أجهزة"، يتم حذف الصورة تلقائيًا.
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
                          _selectedDepartment =
                              null; // إعادة تعيين القسم عند تغيير الكلية.
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
                    const SizedBox(height: _defaultSpacing),
                    _ActionButtons(
                      isEditing: isEditing,
                      labStatus: _labStatus,
                      onSave: _saveLabAndPop,
                      onSaveAndAddDevice: _saveLabAndAddDevice,
                      onAddDeviceToLab: () {
                        // الانتقال لشاشة إضافة جهاز لنفس المعمل (في وضع التعديل).
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
}

// --- ويدجتات محسّنة ومفصولة لتحسين الأداء ---

/// ويدجت مخصص لحقول النص لتقليل التكرار وتوحيد الشكل.
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

//------------------------------------------------------------------------------

/// ويدجت مخصص لقائمة حالة المعمل لعرضها بشكل منظم.
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

//------------------------------------------------------------------------------

/// ويدجت مخصص لقائمة الكليات.
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

//------------------------------------------------------------------------------

/// ويدجت مخصص لقائمة الأقسام التي تعتمد على الكلية المختارة.
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
    // جلب قائمة الأقسام بناءً على الكلية المختارة.
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

//------------------------------------------------------------------------------

/// ويدجت مخصص لقائمة الأدوار.
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

//------------------------------------------------------------------------------

/// ويدجت مخصص لقائمة أنواع المعامل (أو الأماكن).
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

//------------------------------------------------------------------------------

/// ويدجت مسؤول عن عرض الصورة الملتقطة أو الموجودة وزر التقاط الصورة.
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
    // تحديد مصدر الصورة (ملف محلي أو رابط من الإنترنت).
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

//------------------------------------------------------------------------------

/// ويدجت مسؤول عن عرض الأزرار السفلية بناءً على سياق الشاشة (إضافة أو تعديل).
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
    // إذا كانت الشاشة في وضع التعديل.
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
          // عرض زر "إضافة جهاز" فقط إذا لم يكن المعمل مغلقًا.
          if (labStatus != LabStatus.closed) ...[
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onAddDeviceToLab,
                icon: const Icon(Icons.add_to_queue),
                label: const Text('إضافة جهاز'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: theme.colorScheme.onSecondary,
                ),
              ),
            ),
          ],
        ],
      );
    } else {
      // إذا كانت الشاشة في وضع الإضافة.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50)),
            child: const Text('إضافة المعمل'),
          ),
          // عرض زر "إضافة معمل مع جهاز" فقط إذا لم يكن المعمل مغلقًا.
          if (labStatus != LabStatus.closed) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onSaveAndAddDevice,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
              child: const Text('إضافة معمل مع الجهاز'),
            ),
          ],
        ],
      );
    }
  }
}
