// استيراد الدوال المطلوبة من الإصدار الثاني (v2)
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

// تهيئة حزمة الأدمن
admin.initializeApp();

// تحديد المنطقة الجغرافية للخادم
setGlobalOptions({ region: "us-central1" });

/**
 * دالة سحابية لإنشاء مستخدم جديد (بالصيغة الصحيحة v2)
 * هذه الدالة تُستدعى من جانب العميل (تطبيق Flutter) لإنشاء حسابات مستخدمين جديدة.
 * تتطلب صلاحيات إدارية (admin role) للمستخدم الذي يستدعيها.
 */
exports.createUser = onCall(async (request) => {
  // التحقق من أن الشخص الذي استدعى هذه الدالة هو أدمن
  // (يفترض أن الدور "admin" يتم تعيينه كـ Custom Claim للمستخدمين المديرين)
  if (request.auth?.token?.role !== "admin") {
    // استخدام HttpsError مباشرة لإرجاع خطأ مفهوم للعميل
    throw new HttpsError(
      "permission-denied", // نوع الخطأ
      "ليس لديك الصلاحية لتنفيذ هذه العملية." // رسالة الخطأ للمستخدم
    );
  }

  // استخراج البيانات القادمة من التطبيق
  const email = request.data.email;
  const password = request.data.password;
  const displayName = request.data.displayName;
  // يمكنك إضافة حقول أخرى مثل employeeId هنا إذا أردت إرسالها من التطبيق

  // التحقق من أن كل البيانات المطلوبة موجودة
  if (!email || !password || !displayName) {
    throw new HttpsError(
      "invalid-argument", // نوع الخطأ
      "البيانات المرسلة غير مكتملة. يرجى تعبئة كل الحقول." // رسالة الخطأ للمستخدم
    );
  }

  try {
    // 1. إنشاء المستخدم في نظام المصادقة (Authentication)
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
    });

    // 2. تعيين دور "technician" للمستخدم الجديد كـ Custom Claim
    // هذا الدور سيُستخدم للتحقق من الصلاحيات في قواعد Firestore والتطبيق.
    await admin.auth().setCustomUserClaims(userRecord.uid, { role: "technician" });

    // 3. إنشاء مستند للمستخدم في قاعدة بيانات Firestore
    // هذا المستند سيحتوي على بيانات إضافية للمستخدم (مثل النقاط، المهام، إلخ)
    const userDoc = {
      uid: userRecord.uid,
      email: email,
      fullName: displayName,
      role: "technician", // تخزين الدور في Firestore أيضاً
      createdAt: admin.firestore.FieldValue.serverTimestamp(), // وقت إنشاء الخادم
      isActive: true, // المستخدم نشط افتراضياً
      points: 0, // نقاط افتراضية
      tasksCompleted: 0, // مهام مكتملة افتراضية
      devicesRegistered: 0, // أجهزة مسجلة افتراضية
      // يمكنك إضافة employeeId هنا إذا تم إرساله من التطبيق
      // employeeId: request.data.employeeId || null,
    };
    await admin.firestore().collection("users").doc(userRecord.uid).set(userDoc);

    console.log(`تم إنشاء المستخدم بنجاح: ${email} (UID: ${userRecord.uid})`);
    // إرجاع استجابة نجاح إلى العميل
    return { success: true, uid: userRecord.uid, message: "تم إنشاء المستخدم بنجاح." };

  } catch (error) {
    console.error("خطأ في إنشاء المستخدم الجديد:", error);
    // التحقق من أنواع أخطاء Firebase Auth المحددة لإرجاع رسائل أفضل
    if (error.code === 'auth/email-already-in-use') {
      throw new HttpsError('already-exists', 'البريد الإلكتروني هذا مستخدم بالفعل.');
    } else if (error.code === 'auth/weak-password') {
      throw new HttpsError('invalid-argument', 'كلمة المرور ضعيفة جدًا.');
    }
    // إرجاع رسالة الخطأ العامة إلى التطبيق
    throw new HttpsError("internal", error.message);
  }
});
