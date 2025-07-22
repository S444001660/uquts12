import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // لاستخدام IconData و Color

//------------------------------------------------------------------------------

/// تعداد (Enum) لتمثيل حالة المعمل بشكل واضح ومقروء.
enum LabStatus {
  openWithDevices, // أخضر: المعمل مفتوح وبه أجهزة
  openNoDevices, // برتقالي: المعمل مفتوح ولكن لا يحتوي على أجهزة
  closed, // أحمر: المعمل مغلق
}

//------------------------------------------------------------------------------

/// نموذج بيانات (Data Model) يمثل "المعمل" داخل النظام.
/// هذا الكلاس هو المخطط الهندسي (Blueprint) الذي يحدد خصائص ووظائف أي معمل.
class LabModel {
  // --- الخصائص الأساسية للمعمل ---
  /// معرف فريد للمعمل (UUID).
  final String id;

  /// رقم المعمل (مثل: A1، B12).
  final String labNumber;

  /// اسم الكلية التي يتبع لها المعمل.
  final String college;

  /// اسم القسم التابع للمعمل.
  final String department;

  /// رقم الدور الموجود فيه المعمل.
  final String floorNumber;

  /// نوع المعمل (مثل: حاسب، فيزياء، شبكات...).
  final String type;

  /// الحالة الحالية للمعمل (مفتوح/مغلق).
  final LabStatus status;

  /// ملاحظات إدارية أو فنية على المعمل.
  final String notes;

  /// قائمة معرفات الأجهزة المرتبطة بهذا المعمل.
  final List<String> deviceIds;

  /// وقت إنشاء السجل.
  final DateTime createdAt;

  /// وقت آخر تعديل.
  final DateTime updatedAt;

  /// مسار صورة المعمل (اختياري)، يمكن أن يكون URL من Firebase Storage.
  final String? imagePath;

  /// رابط لموقع المعمل (Google Maps).
  final String? locationUrl;

  /// إحداثيات الموقع - خط العرض.
  final double? latitude;

  /// إحداثيات الموقع - خط الطول.
  final double? longitude;

  //------------------------------------------------------------------------------

  /// البناء (Constructor) لإنشاء كائن جديد من نوع LabModel.
  const LabModel({
    required this.id,
    required this.labNumber,
    required this.college,
    required this.department,
    required this.floorNumber,
    required this.type,
    required this.status,
    required this.notes,
    this.deviceIds = const [], // تعيين قيمة افتراضية فارغة للقائمة
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
    this.locationUrl,
    this.latitude,
    this.longitude,
  });

  //------------------------------------------------------------------------------

  /// دالة لتحويل كائن LabModel إلى خريطة (Map) من نوع <String, dynamic>.
  /// هذه الصيغة مناسبة لتخزين البيانات في قاعدة بيانات Firestore.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'labNumber': labNumber,
      'college': college,
      'department': department,
      'floorNumber': floorNumber,
      'type': type,
      'status': status.name, // تخزين اسم الـ enum كـ String لسهولة القراءة
      'notes': notes,
      'deviceIds': deviceIds,
      'createdAt':
          Timestamp.fromDate(createdAt), // تحويل DateTime إلى Timestamp
      'updatedAt':
          Timestamp.fromDate(updatedAt), // تحويل DateTime إلى Timestamp
      'imagePath': imagePath,
      'locationUrl': locationUrl,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  //------------------------------------------------------------------------------

  /// دالة مصنع (Factory Constructor) لبناء كائن LabModel من خريطة (Map).
  /// تُستخدم عند قراءة البيانات من Firestore وتحويلها إلى كائن Dart.
  factory LabModel.fromMap(Map<String, dynamic> map) {
    // دالة مساعدة داخلية لتحويل أنواع مختلفة من بيانات التاريخ إلى DateTime.
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now(); // قيمة احتياطية إذا كان النوع غير معروف.
    }

    return LabModel(
      id: map['id'] as String,
      labNumber: map['labNumber'] as String,
      college: map['college'] as String,
      department: map['department'] as String,
      floorNumber: map['floorNumber'] as String,
      type:
          map['type'] as String? ?? '', // تأكد من التعامل مع القيمة الافتراضية
      status: LabStatus.values.firstWhere(
        (e) => e.name == map['status'], // مقارنة باسم الـ enum
        orElse: () => LabStatus.closed, // الحالة الافتراضية: مغلق
      ),
      notes: map['notes'] as String? ?? '',
      deviceIds: List<String>.from(map['deviceIds'] ?? []),
      createdAt: parseDateTime(map['createdAt']), // استخدام الدالة المساعدة.
      updatedAt: parseDateTime(map['updatedAt']), // استخدام الدالة المساعدة.
      imagePath: map['imagePath'] as String?,
      locationUrl: map['locationUrl'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
    );
  }

  //------------------------------------------------------------------------------

  /// دالة لإنشاء نسخة جديدة من الكائن مع إمكانية تغيير بعض القيم.
  /// مفيدة للحفاظ على البيانات غير القابلة للتغيير (immutability).
  LabModel copyWith({
    String? id,
    String? labNumber,
    String? college,
    String? department,
    String? floorNumber,
    String? type,
    LabStatus? status,
    String? notes,
    List<String>? deviceIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imagePath,
    String? locationUrl,
    double? latitude,
    double? longitude,
  }) {
    return LabModel(
      id: id ?? this.id,
      labNumber: labNumber ?? this.labNumber,
      college: college ?? this.college,
      department: department ?? this.department,
      floorNumber: floorNumber ?? this.floorNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      deviceIds: deviceIds ?? this.deviceIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePath: imagePath ?? this.imagePath,
      locationUrl: locationUrl ?? this.locationUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  //------------------------------------------------------------------------------

  /// دالة Getter لترجع لون الحالة لعرضه في الواجهة.
  Color getStatusColor(BuildContext context) {
    switch (status) {
      case LabStatus.openWithDevices:
        return Colors.green;
      case LabStatus.openNoDevices:
        return Colors.orange;
      case LabStatus.closed:
        return Colors.red;
    }
  }

  //------------------------------------------------------------------------------

  /// دالة Getter لترجع نص الحالة باللغة العربية.
  String getStatusText() {
    switch (status) {
      case LabStatus.openWithDevices:
        return 'مفتوح - يحتوي على أجهزة';
      case LabStatus.openNoDevices:
        return 'مفتوح - لا توجد أجهزة';
      case LabStatus.closed:
        return 'مغلق';
    }
  }
}
