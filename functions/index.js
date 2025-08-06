// استيراد الدوال المطلوبة من الإصدار الثاني (v2)
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentDeleted } = require("firebase-functions/v2/firestore"); // استيراد onDocumentDeleted
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

// تهيئة حزمة الأدمن
admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

// تحديد المنطقة الجغرافية للخادم
setGlobalOptions({ region: "us-central1" });

/**
 * دالة لإنشاء مستخدم جديد مع دوره وبياناته في Firestore.
 * تتطلب صلاحيات إدارية (admin).
 */
exports.createUser = onCall(async (request) => {
  // التحقق من أن المستدعي هو أدمن
  if (request.auth?.token?.role !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "ليس لديك الصلاحية لتنفيذ هذه العملية."
    );
  }

  const { email, password, fullName, employeeId, role = 'technician' } = request.data;

  if (!email || !password || !fullName || !employeeId) {
    throw new HttpsError(
      "invalid-argument",
      "البيانات المرسلة غير مكتملة. يرجى تعبئة كل الحقول."
    );
  }

  try {
    // 1. إنشاء المستخدم في Authentication
    const userRecord = await auth.createUser({
      email: email,
      password: password,
      displayName: fullName,
    });

    // 2. تعيين الدور كـ Custom Claim
    await auth.setCustomUserClaims(userRecord.uid, { role: role });

    // 3. إنشاء مستند للمستخدم في Firestore
    const userDoc = {
      uid: userRecord.uid,
      email: email,
      fullName: fullName,
      employeeId: employeeId,
      role: role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      points: 0,
      tasksCompleted: 0,
      devicesRegistered: 0,
    };
    await db.collection("users").doc(userRecord.uid).set(userDoc);

    logger.info(`تم إنشاء المستخدم بنجاح: ${email} (UID: ${userRecord.uid})`);
    return { success: true, uid: userRecord.uid, message: "تم إنشاء المستخدم بنجاح." };

  } catch (error) {
    logger.error("خطأ في إنشاء المستخدم الجديد:", error);
    if (error.code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'البريد الإلكتروني هذا مستخدم بالفعل.');
    } else if (error.code === 'auth/weak-password') {
      throw new HttpsError('invalid-argument', 'كلمة المرور ضعيفة جدًا. يجب أن تكون 6 أحرف على الأقل.');
    }
    throw new HttpsError("internal", "حدث خطأ غير معروف أثناء إنشاء المستخدم.");
  }
});

/**
 * دالة لتحديث دور المستخدم (مثلاً، من فني إلى مشرف).
 * تتطلب صلاحيات إدارية (admin).
 */
exports.updateUserRole = onCall(async (request) => {
  if (request.auth?.token?.role !== "admin") {
    throw new HttpsError("permission-denied", "ليس لديك الصلاحية لتنفيذ هذه العملية.");
  }

  const { uid, newRole } = request.data;
  const validRoles = ["admin", "supervisor", "technician"];

  if (!uid || !newRole || !validRoles.includes(newRole)) {
    throw new HttpsError("invalid-argument", "البيانات المرسلة غير صحيحة.");
  }

  try {
    // 1. تحديث الدور في Custom Claims
    await auth.setCustomUserClaims(uid, { role: newRole });
    // 2. تحديث الدور في مستند Firestore
    await db.collection("users").doc(uid).update({ role: newRole });

    logger.info(`تم تحديث دور المستخدم ${uid} إلى ${newRole}`);
    return { success: true, message: "تم تحديث دور المستخدم بنجاح." };
  } catch (error) {
    logger.error(`خطأ في تحديث دور المستخدم ${uid}:`, error);
    throw new HttpsError("internal", "فشل تحديث دور المستخدم.");
  }
});

/**
 * دالة لتفعيل أو تعطيل حساب مستخدم.
 * تتطلب صلاحيات إدارية (admin).
 */
exports.toggleUserStatus = onCall(async (request) => {
  if (request.auth?.token?.role !== "admin") {
    throw new HttpsError("permission-denied", "ليس لديك الصلاحية لتنفيذ هذه العملية.");
  }

  const { uid, isActive } = request.data;

  if (!uid || typeof isActive !== 'boolean') {
    throw new HttpsError("invalid-argument", "البيانات المرسلة غير صحيحة.");
  }

  try {
    // 1. تحديث حالة الحساب في Auth (تعطيل/تفعيل)
    await auth.updateUser(uid, { disabled: !isActive });
    // 2. تحديث حالة الحساب في Firestore
    await db.collection("users").doc(uid).update({ isActive: isActive });

    logger.info(`تم تغيير حالة المستخدم ${uid} إلى ${isActive ? 'نشط' : 'معطل'}`);
    return { success: true, message: `تم ${isActive ? 'تفعيل' : 'تعطيل'} الحساب بنجاح.` };
  } catch (error) {
    logger.error(`خطأ في تغيير حالة المستخدم ${uid}:`, error);
    throw new HttpsError("internal", "فشل تغيير حالة الحساب.");
  }
});

/**
 * دالة تلقائية (trigger) لحذف بيانات المستخدم من Firestore
 * عند حذفه من نظام المصادقة.
 */
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  try {
    await db.collection("users").doc(uid).delete();
    logger.info(`تم حذف بيانات المستخدم ${uid} من Firestore بنجاح.`);
    return null;
  } catch (error) {
    logger.error(`خطأ في حذف بيانات المستخدم ${uid} من Firestore:`, error);
    return null;
  }
});
