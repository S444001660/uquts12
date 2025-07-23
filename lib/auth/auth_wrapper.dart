import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/home_screen.dart'; // تأكد من أن اسم الكلاس داخل هذا الملف هو UpdatedHomeScreen
import '../auth/login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.hasData && authSnapshot.data != null) {
          final User firebaseUser = authSnapshot.data!;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(firebaseUser.uid)
                .snapshots(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                final userData =
                    userDocSnapshot.data!.data() as Map<String, dynamic>;

                // ======================= تم تصحيح الخطأ المنطقي هنا =======================
                // القيمة الافتراضية true: إذا لم يوجد الحقل، اعتبر المستخدم نشطاً
                final bool isActive = userData['isActive'] ?? true;
                // =======================================================================

                if (isActive) {
                  return const UpdatedHomeScreen();
                }
              }

              // إذا كان المستخدم غير نشط، أو المستند غير موجود، قم بطرده
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseAuth.instance.signOut();
              });

              return const LoginScreen();
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}
