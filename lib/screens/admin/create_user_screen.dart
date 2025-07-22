import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/ui_helpers.dart'; // استيراد UIHelpers

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _employeeIdController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      UIHelpers.showErrorSnackBar(context, "خطأ: المدير غير مسجل دخوله.");
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. إنشاء حساب المستخدم الجديد في Firebase Authentication
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final newUser = userCredential.user;
      if (newUser != null) {
        // 2. حفظ بيانات المستخدم الجديد في Firestore
        // هذا يضمن وجود مستند المستخدم في Firestore فور إنشائه
        await _saveUserToFirestore(newUser.uid, adminUid);
        await newUser.updateDisplayName(_fullNameController.text.trim());

        // لا تقم بتسجيل خروج المستخدم الحالي (المدير) هنا.
        // يجب أن يبقى المدير مسجل الدخول بعد إنشاء حساب جديد.
        // await FirebaseAuth.instance.signOut(); // هذا السطر يجب أن يكون محذوفًا أو معلقًا

        if (mounted) {
          UIHelpers.showSuccessSnackBar(
              context, 'تم إنشاء حساب لـ "${_fullNameController.text}" بنجاح!');
          Navigator.of(context).pop(true); // العودة إلى الشاشة السابقة
        }
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      UIHelpers.showErrorSnackBar(
          context, 'حدث خطأ غير متوقع: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveUserToFirestore(String newUserUid, String adminUid) async {
    final userData = {
      'uid': newUserUid,
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'employeeId': _employeeIdController.text.trim(),
      'role': 'technician', // تعيين دور "فني" بشكل افتراضي
      'createdAt': Timestamp.now(),
      'createdBy': adminUid,
      'isActive': true,
      'points': 0,
      'tasksCompleted': 0,
      'devicesRegistered': 0,
    };
    await FirebaseFirestore.instance.collection('users').doc(newUserUid).set(
        userData); // استخدام set() بدلاً من update() لضمان الإنشاء إذا لم يكن موجوداً
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب فني جديد'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
}
