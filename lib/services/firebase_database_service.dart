// استيراد المكتبات الضرورية
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

// --- تأكد من أن هذه المسارات صحيحة في مشروعك ---
import '../models/lab_model.dart';
import '../models/device_model.dart';
import '../models/user_account_model.dart';
import '../services/task_progress_service.dart'; // استيراد خدمة تتبع المهام

//------------------------------------------------------------------------------

/// كلاس خدمي (Service Class) للتعامل مع عمليات قاعدة بيانات Firebase Firestore و Storage.
/// يوفر دوال ثابتة (static) لتنفيذ عمليات CRUD (إنشاء، قراءة، تحديث، حذف) للمعامل والأجهزة.
class FirebaseDatabaseService {
  // --- تهيئة خدمات Firebase ---
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===========================================================================
  //                           عمليات حسابات المستخدمين (User Accounts)
  // ===========================================================================

  /// إضافة بيانات مستخدم جديد إلى مجموعة 'users' في Firestore.
  static Future<void> addUser(UserAccountModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      debugPrint('تمت إضافة بيانات المستخدم ${user.fullName} إلى Firestore');
    } catch (e) {
      debugPrint('خطأ في إضافة المستخدم إلى Firestore: $e');
      rethrow;
    }
  }

  /// جلب بيانات مستخدم واحد من Firestore باستخدام معرفه (uid).
  static Future<UserAccountModel?> getUserById(String uid) async {
    try {
      final DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserAccountModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('خطأ في جلب المستخدم بواسطة ID من Firestore: $e');
      return null;
    }
  }

  /// التحقق من دور المستخدم (هل هو أدمن؟) بطريقة آمنة.
  static Future<bool> isAdmin(String uid) async {
    try {
      final user = await getUserById(uid);
      return user?.role == 'admin';
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  //                           عمليات المعامل (Labs)
  // ===========================================================================

  /// إضافة معمل جديد أو تحديث بيانات معمل موجود.
  static Future<void> addOrUpdateLab(LabModel lab) async {
    try {
      // التحقق من صحة البيانات الأساسية قبل إرسالها
      if (lab.id.isEmpty ||
          lab.labNumber.isEmpty ||
          lab.college.isEmpty ||
          lab.department.isEmpty) {
        throw Exception('بيانات المعمل الأساسية غير صالحة أو مفقودة.');
      }

      final Map<String, dynamic> labData = lab.toMap();

      // رفع الصورة فقط إذا كان المسار محليًا وليس رابط URL
      if (lab.imagePath != null &&
          lab.imagePath!.isNotEmpty &&
          !lab.imagePath!.startsWith('http')) {
        final imageUrl = await uploadImageToFirebaseStorage(
            File(lab.imagePath!), 'lab_images/${lab.id}');
        labData['imagePath'] = imageUrl;
      }

      await _firestore
          .collection('labs')
          .doc(lab.id)
          .set(labData, SetOptions(merge: true));
      debugPrint('تم إضافة/تحديث المعمل بنجاح: ${lab.labNumber}');
    } catch (e) {
      debugPrint('خطأ في إضافة/تحديث المعمل: $e');
      rethrow;
    }
  }

  /// حذف معمل وجميع البيانات المرتبطة به.
  static Future<void> deleteLab(String labId) async {
    try {
      // حذف وثيقة المعمل
      await _firestore.collection('labs').doc(labId).delete();

      // تحديث الأجهزة المرتبطة بالمعمل لإزالة الارتباط
      final devicesSnapshot = await _firestore
          .collection('devices')
          .where('labId', isEqualTo: labId)
          .get();
      final batch = _firestore.batch();
      for (var doc in devicesSnapshot.docs) {
        batch.update(doc.reference, {'labId': null});
      }
      await batch.commit();

      // حذف صورة المعمل من Storage
      await _deleteImageFromFirebaseStorage('lab_images/$labId');
      debugPrint('تم حذف المعمل بنجاح: $labId');
    } catch (e) {
      debugPrint('خطأ في حذف المعمل: $e');
      rethrow;
    }
  }

  /// تحديث حالة المعمل تلقائيًا بناءً على عدد الأجهزة فيه.
  static Future<void> updateLabStatus(String labId) async {
    try {
      final devicesSnapshot = await _firestore
          .collection('devices')
          .where('labId', isEqualTo: labId)
          .get();
      final deviceCount = devicesSnapshot.docs.length;

      final newStatus = deviceCount > 0
          ? LabStatus.openWithDevices.name
          : LabStatus.openNoDevices.name;

      await _firestore.collection('labs').doc(labId).update({
        'status': newStatus,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      debugPrint('تم تحديث حالة المعمل $labId إلى $newStatus');
    } catch (e) {
      debugPrint('خطأ في تحديث حالة المعمل: $e');
      rethrow;
    }
  }

  /// جلب قائمة بجميع المعامل من قاعدة البيانات.
  static Future<List<LabModel>> getLabs() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('labs').get();
      return snapshot.docs
          .map((doc) => LabModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('خطأ في جلب المعامل: $e');
      return [];
    }
  }

  /// جلب قائمة المعامل التي تنتمي إلى كلية معينة.
  static Future<List<LabModel>> getLabsByCollege(String college) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('labs')
          .where('college', isEqualTo: college)
          .get();
      return snapshot.docs
          .map((doc) => LabModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('خطأ في جلب المعامل حسب الكلية: $e');
      return [];
    }
  }

  /// جلب بيانات معمل واحد باستخدام معرفه (ID).
  static Future<LabModel?> getLabById(String labId) async {
    try {
      final DocumentSnapshot doc =
          await _firestore.collection('labs').doc(labId).get();
      if (doc.exists && doc.data() != null) {
        return LabModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('خطأ في جلب المعمل بواسطة ID: $e');
      return null;
    }
  }

  /// التحقق مما إذا كان رقم المعمل موجودًا مسبقًا.
  static Future<bool> isLabNumberExists(String labNumber,
      {String? excludeId}) async {
    try {
      Query query = _firestore
          .collection('labs')
          .where('labNumber', isEqualTo: labNumber);

      // في حالة التعديل، استثني المعمل الحالي من البحث
      if (excludeId != null) {
        query = query.where(FieldPath.documentId, isNotEqualTo: excludeId);
      }

      final snapshot = await query.limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('خطأ في التحقق من وجود رقم المعمل: $e');
      return false; // نفترض عدم وجوده في حالة الخطأ لتجنب منع المستخدم
    }
  }

  // ===========================================================================
  //                           عمليات الأجهزة (Devices)
  // ===========================================================================

  /// إضافة جهاز جديد أو تحديث بيانات جهاز موجود.
  static Future<void> addOrUpdateDevice(DeviceModel device) async {
    try {
      final Map<String, dynamic> deviceData = device.toMap();
      final currentUser = _auth.currentUser;
      final isNewDevice = device.createdAt.isAtSameMomentAs(device.updatedAt);

      if (device.imagePath != null &&
          device.imagePath!.isNotEmpty &&
          !device.imagePath!.startsWith('http')) {
        final imageUrl = await uploadImageToFirebaseStorage(
            File(device.imagePath!), 'device_images/${device.id}');
        deviceData['imagePath'] = imageUrl;
      }

      await _firestore
          .collection('devices')
          .doc(device.id)
          .set(deviceData, SetOptions(merge: true));

      if (device.labId.isNotEmpty) {
        await updateLabStatus(device.labId);
      }

      if (isNewDevice && currentUser != null) {
        await updateUserStatsOnDeviceAdd(currentUser.uid);
      }

      debugPrint('تم إضافة/تحديث الجهاز بنجاح: ${device.name}');
    } catch (e) {
      debugPrint('خطأ في إضافة/تحديث الجهاز: $e');
      rethrow;
    }
  }

  /// تحديث إحصائيات المستخدم عند إضافة جهاز جديد.
  static Future<void> updateUserStatsOnDeviceAdd(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'devicesRegistered': FieldValue.increment(1),
        'lastDeviceRegistered': Timestamp.now(),
      });

      await TaskProgressService.updateDeviceRegistrationProgress(userId);

      debugPrint('تم تحديث إحصائيات المستخدم وتقدم المهام');
    } catch (e) {
      debugPrint('خطأ في تحديث إحصائيات المستخدم: $e');
    }
  }

  /// حذف جهاز وتحديث حالة المعمل المرتبط به.
  static Future<void> deleteDevice(String deviceId) async {
    try {
      final deviceDoc =
          await _firestore.collection('devices').doc(deviceId).get();
      String? labId;
      String? imagePath;
      if (deviceDoc.exists && deviceDoc.data() != null) {
        final data = deviceDoc.data() as Map<String, dynamic>;
        labId = data['labId'];
        imagePath = data['imagePath'];
      }

      await _firestore.collection('devices').doc(deviceId).delete();

      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          final storageRef = _storage.refFromURL(imagePath);
          await storageRef.delete();
        } catch (e) {
          debugPrint(
              'خطأ في حذف صورة الجهاز من Storage (قد لا تكون موجودة): $e');
        }
      }

      if (labId != null && labId.isNotEmpty) {
        await updateLabStatus(labId);
      }
      debugPrint('تم حذف الجهاز بنجاح: $deviceId');
    } catch (e) {
      debugPrint('خطأ في حذف الجهاز: $e');
      rethrow;
    }
  }

  /// جلب بيانات جهاز واحد باستخدام معرفه (ID).
  static Future<DeviceModel?> getDeviceById(String deviceId) async {
    try {
      final DocumentSnapshot doc =
          await _firestore.collection('devices').doc(deviceId).get();
      if (doc.exists && doc.data() != null) {
        return DeviceModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('خطأ في جلب الجهاز بواسطة ID: $e');
      return null;
    }
  }

  /// جلب قائمة بجميع الأجهزة من قاعدة البيانات.
  static Future<List<DeviceModel>> getDevices() async {
    try {
      final QuerySnapshot snapshot =
          await _firestore.collection('devices').get();
      return snapshot.docs
          .map((doc) => DeviceModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('خطأ في جلب الأجهزة: $e');
      return [];
    }
  }

  /// جلب قائمة الأجهزة الموجودة في معمل معين.
  static Future<List<DeviceModel>> getDevicesForLab(String labId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('devices')
          .where('labId', isEqualTo: labId)
          .get();
      return snapshot.docs
          .map((doc) => DeviceModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('خطأ في جلب الأجهزة للمعمل: $e');
      return [];
    }
  }

  /// التحقق من وجود الرقم التسلسلي مسبقًا في قاعدة البيانات.
  static Future<bool> serialNumberExists(String serialNumber,
      {String? excludeId}) async {
    try {
      Query query = _firestore
          .collection('devices')
          .where('serialNumber', isEqualTo: serialNumber);
      if (excludeId != null) {
        query = query.where('id', isNotEqualTo: excludeId);
      }
      final QuerySnapshot snapshot = await query.get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('خطأ في التحقق من وجود الرقم التسلسلي: $e');
      return false;
    }
  }

  /// جلب جهاز باستخدام الباركود الجامعي أو رمز الأصل.
  static Future<DeviceModel?> getDeviceByBarcode(
      String barcode, String assetCode) async {
    try {
      if (barcode.isNotEmpty) {
        final QuerySnapshot barcodeSnapshot = await _firestore
            .collection('devices')
            .where('universityBarcode', isEqualTo: barcode)
            .limit(1)
            .get();
        if (barcodeSnapshot.docs.isNotEmpty) {
          return DeviceModel.fromMap(
              barcodeSnapshot.docs.first.data() as Map<String, dynamic>);
        }
      }

      if (assetCode.isNotEmpty) {
        final QuerySnapshot assetCodeSnapshot = await _firestore
            .collection('devices')
            .where('assetCode', isEqualTo: assetCode)
            .limit(1)
            .get();
        if (assetCodeSnapshot.docs.isNotEmpty) {
          return DeviceModel.fromMap(
              assetCodeSnapshot.docs.first.data() as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('خطأ في جلب الجهاز بواسطة الباركود/Asset Code: $e');
      return null;
    }
  }

  // ===========================================================================
  //                           دوال مساعدة (Helpers)
  // ===========================================================================

  /// دالة عامة لرفع ملف صورة إلى Firebase Storage.
  static Future<String?> uploadImageToFirebaseStorage(
      File imageFile, String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('تم رفع الصورة بنجاح: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('خطأ في رفع الصورة إلى Storage: $e');
      return null;
    }
  }

  /// دالة مساعدة خاصة لحذف صورة من Firebase Storage.
  static Future<void> _deleteImageFromFirebaseStorage(
      String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      await ref.delete();
      debugPrint('تم حذف الصورة من Storage: $storagePath');
    } catch (e) {
      debugPrint('خطأ في حذف الصورة من Storage (قد لا تكون موجودة): $e');
    }
  }

  /// دالة مساعدة لتوليد معرف فريد عالميًا (UUID).
  static String generateUniqueId() {
    return const Uuid().v4();
  }
}
