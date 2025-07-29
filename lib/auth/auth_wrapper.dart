import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/home_screen.dart'; // تأكد من أن اسم الكلاس داخل هذا الملف هو UpdatedHomeScreen
import '../auth/login_screen.dart';
import '../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

/// هذا الويدجت هو المسؤول عن مراقبة حالة تسجيل الدخول للمستخدم وتوجيهه.
/// يستمع إلى التغييرات في حالة المصادقة (authStateChanges).
/// إذا كان المستخدم مسجلاً دخوله، فإنه يستمع إلى بياناته في Firestore للتحقق مما إذا كان حسابه نشطًا.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // أثناء انتظار بيانات المصادقة، اعرض مؤشر تحميل
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CustomLoadingIndicator()),
          );
        }

        // إذا كان المستخدم قد سجل دخوله (بياناته موجودة)
        if (authSnapshot.hasData && authSnapshot.data != null) {
          final User firebaseUser = authSnapshot.data!;

          // الآن، استمع إلى مستند المستخدم في Firestore
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(firebaseUser.uid)
                .snapshots(),
            builder: (context, userDocSnapshot) {
              // أثناء انتظار بيانات Firestore، اعرض مؤشر تحميل
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CustomLoadingIndicator()),
                );
              }

              // إذا كانت بيانات المستخدم موجودة في Firestore
              if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                final userData =
                    userDocSnapshot.data!.data() as Map<String, dynamic>;

                // تحقق مما إذا كان الحساب نشطًا. القيمة الافتراضية 'true' للحسابات القديمة
                final bool isActive = userData['isActive'] ?? true;

                // إذا كان الحساب نشطًا، وجهه إلى الشاشة الرئيسية
                if (isActive) {
                  return const UpdatedHomeScreen();
                }
              }

              // إذا كان الحساب غير نشط، أو مستند Firestore غير موجود،
              // قم بتسجيل خروج المستخدم فورًا وأعده إلى شاشة تسجيل الدخول.
              // استخدام addPostFrameCallback يضمن أن عملية تسجيل الخروج تحدث بعد اكتمال بناء الواجهة.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseAuth.instance.signOut();
              });

              return const LoginScreen();
            },
          );
        }

        // إذا لم يكن المستخدم مسجلاً دخوله، اعرض شاشة تسجيل الدخول
        return const LoginScreen();
      },
    );
  }
}
