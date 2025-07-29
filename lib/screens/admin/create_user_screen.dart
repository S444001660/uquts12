import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _employeeIdController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle) - (أساسي)
  // ===========================================================================

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method) - (أساسي)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب فني جديد'),
      ),
      body: _isLoading
          ? const Center(child: CustomLoadingIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration:
                        const InputDecoration(labelText: 'الاسم الكامل'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'الاسم الكامل مطلوب'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _employeeIdController,
                    decoration:
                        const InputDecoration(labelText: 'الرقم الوظيفي'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'الرقم الوظيفي مطلوب'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration:
                        const InputDecoration(labelText: 'البريد الإلكتروني'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'البريد الإلكتروني مطلوب';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'صيغة البريد الإلكتروني غير صحيحة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'كلمة المرور مطلوبة';
                      }
                      if (value.length < 6) {
                        return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'كلمة المرور غير متطابقة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _createUser,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('إنشاء الحساب'),
                  ),
                ],
              ),
            ),
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي (Core Business Logic) - (أساسي)
  // ===========================================================================

  /// دالة لإنشاء حساب مستخدم جديد باستخدام تطبيق Firebase ثانوي معزول.
  Future<void> _createUser() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) {
      UIHelpers.showErrorSnackBar(context, "خطأ: المدير غير مسجل دخوله.");
      setState(() => _isLoading = false);
      return;
    }

    String secondaryAppName =
        'userCreation-${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? secondaryApp;

    try {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: Firebase.app().options,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instanceFor(app: secondaryApp)
              .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final newUser = userCredential.user;
      if (newUser != null) {
        await _saveUserToFirestore(newUser.uid, admin.uid);

        if (mounted) {
          UIHelpers.showSuccessSnackBar(
              context, 'تم إنشاء حساب لـ "${_fullNameController.text}" بنجاح!');
          Navigator.of(context).pop(true);
        }
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      if (mounted) {
        UIHelpers.showErrorSnackBar(
          context,
          'حدث خطأ غير متوقع: ${e.toString()}',
        );
      }
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ===========================================================================
  // 5. الدوال المساعدة (Helper Functions) - (يمكن فصلها)
  // ===========================================================================

  /// دالة لحفظ بيانات المستخدم الجديد في Firestore.
  Future<void> _saveUserToFirestore(String newUserUid, String adminUid) async {
    final userData = {
      'uid': newUserUid,
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'employeeId': _employeeIdController.text.trim(),
      'role': 'technician',
      'createdAt': Timestamp.now(),
      'createdBy': adminUid,
      'isActive': true,
      'points': 0,
      'tasksCompleted': 0,
      'devicesRegistered': 0,
    };
    await FirebaseFirestore.instance
        .collection('users')
        .doc(newUserUid)
        .set(userData);
  }

  /// دالة لترجمة أخطاء Firebase Auth إلى رسائل مفهومة للمستخدم.
  void _handleFirebaseAuthError(FirebaseAuthException e) {
    String errorMessage = 'حدث خطأ غير متوقع';
    if (e.code == 'weak-password') {
      errorMessage = 'كلمة المرور ضعيفة جدًا.';
    } else if (e.code == 'email-already-in-use') {
      errorMessage = 'هذا البريد الإلكتروني مستخدم بالفعل.';
    } else if (e.code == 'invalid-email') {
      errorMessage = 'صيغة البريد الإلكتروني غير صحيحة.';
    }
    UIHelpers.showErrorSnackBar(context, errorMessage);
  }
}
