// auth_wrapper.dart (لا تغييرات جوهرية)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/home_screen.dart';
import '../auth/login_screen.dart';
import '../models/user_account_model.dart';
import '../utils/ui_helpers.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('AuthWrapper: Stream error: ${snapshot.error}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            UIHelpers.showErrorSnackBar(
                context, 'خطأ في المصادقة: ${snapshot.error}');
          });
          return const LoginScreen();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final User firebaseUser = snapshot.data!;
          debugPrint('AuthWrapper: User is logged in: ${firebaseUser.uid}');

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(firebaseUser.uid)
                .snapshots(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.hasError) {
                debugPrint(
                    'AuthWrapper: User document stream error: ${userDocSnapshot.error}');
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  UIHelpers.showErrorSnackBar(context,
                      'خطأ في جلب بيانات المستخدم: ${userDocSnapshot.error}');
                });
                FirebaseAuth.instance
                    .signOut(); // سجل الخروج في حال وجود خطأ في جلب المستند
                return const LoginScreen();
              }

              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                final userData =
                    userDocSnapshot.data!.data() as Map<String, dynamic>;
                final UserAccountModel currentUser =
                    UserAccountModel.fromMap(userData);
                debugPrint(
                    'AuthWrapper: User data found in Firestore for ${currentUser.fullName}');
                return const UpdatedHomeScreen();
              } else {
                debugPrint(
                    'AuthWrapper: User document NOT found in Firestore for UID: ${firebaseUser.uid}');
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  UIHelpers.showErrorSnackBar(context,
                      'لم يتم العثور على بياناتك في قاعدة البيانات. يرجى التواصل مع المسؤول.');
                });
                // سجل الخروج هنا لفرض عودة المستخدم لصفحة الدخول
                // إذا كان موجودًا في Firebase Auth ولكن بدون مستند في Firestore
                FirebaseAuth.instance.signOut();
                return const LoginScreen();
              }
            },
          );
        } else {
          debugPrint(
              'AuthWrapper: User is NOT logged in. Navigating to LoginScreen.');
          return const LoginScreen();
        }
      },
    );
  }
}
