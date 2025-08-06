import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/ui_helpers.dart';
import '../models/user_account_model.dart';
import '../models/user_role_model.dart';
import '../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  static const String _adminEmail = 'admin@uqu.edu.sa';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    try {
      // 1. محاولة تسجيل الدخول باستخدام Firebase Authentication
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('فشل تسجيل الدخول: المستخدم غير موجود.');
      }

      // 2. جلب مستند المستخدم من Firestore
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
      final userDoc = await userDocRef.get();

      if (userDoc.exists) {
        // ======================= الحل الأمني يبدأ هنا =======================
        final userData = userDoc.data() as Map<String, dynamic>;
        final bool isActive = userData['isActive'] ??
            true; // القيمة الافتراضية true للحسابات القديمة

        if (!isActive) {
          // إذا كان الحساب غير نشط، قم بتسجيل الخروج فوراً
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            UIHelpers.showErrorSnackBar(
                context, 'تم تعطيل هذا الحساب. يرجى التواصل مع المسؤول.');
          }
          debugPrint("❌ تم منع تسجيل الدخول: الحساب معطل.");
          return; // منع المتابعة
        }
        // ======================== الحل الأمني ينتهي هنا ========================

        // إذا كان الحساب نشطاً، استمر في العملية كالمعتاد
        debugPrint("✅ تم تسجيل الدخول بنجاح.");
        if (mounted) {
          final userRoleString = userData['role'] as String? ?? 'guest';
          if (mounted) {
            UIHelpers.showSuccessSnackBar(context,
                "مرحباً بك: ${userRoleFromString(userRoleString).displayName}");
          }
        }
      } else {
        // هذا الجزء يعالج حالة عدم وجود مستند للمستخدم
        // (مهم بشكل خاص لأول تسجيل دخول للمدير)
        if (email.toLowerCase() == _adminEmail &&
            (await _firestoreCollectionIsEmpty('users'))) {
          final newAdminUser = UserAccountModel(
            uid: firebaseUser.uid,
            email: email,
            fullName: 'رئيس القسم',
            role: UserRole.admin.name,
            createdAt: DateTime.now(),
            points: 0,
            tasksCompleted: 0,
            devicesRegistered: 0,
          );
          await userDocRef.set(newAdminUser.toMap());
          debugPrint("✅ تم إنشاء مستند الرئيس الأول في Firestore تلقائيًا.");
          if (mounted) {
            if (mounted) {
              UIHelpers.showSuccessSnackBar(
                  context, "تم تسجيل الدخول رئيس القسم.");
            }
          }
        } else {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            UIHelpers.showErrorSnackBar(
                context, 'بيانات حسابك غير مكتملة. يرجى التواصل مع المسؤول.');
          }
          debugPrint(
              "❌ بيانات المستخدم غير موجودة في Firestore. تم تسجيل الخروج.");
          return;
        }
      }
      // AuthWrapper سيتولى التوجيه تلقائياً
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      if (mounted) {
        UIHelpers.showErrorSnackBar(
            context, "حدث خطأ غير متوقع: ${e.toString()}");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _firestoreCollectionIsEmpty(String collectionName) async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty;
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    String errorMessage;
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        errorMessage = "البريد الإلكتروني أو كلمة المرور غير صحيحة";
        break;
      case 'user-disabled':
        errorMessage = "تم تعطيل هذا الحساب. يرجى التواصل مع المسؤول.";
        break;
      case 'too-many-requests':
        errorMessage =
            "تم حظر الدخول مؤقتًا بسبب كثرة المحاولات الفاشلة. حاول لاحقًا.";
        break;
      default:
        errorMessage = "حدث خطأ: ${e.message}";
    }
    UIHelpers.showErrorSnackBar(context, errorMessage);
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال البريد الإلكتروني';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'يرجى إدخال كلمة المرور';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تسجيل الدخول")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset("assets/images/UQU_green_logo.png", height: 120),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: "البريد الإلكتروني"),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: "كلمة المرور",
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 40),
                _isLoading
                    ? const Center(child: CustomLoadingIndicator())
                    : ElevatedButton(
                        onPressed: _signIn,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("تسجيل الدخول"),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
