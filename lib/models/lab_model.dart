import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart'; // <-- 1. استيراد الحزمة الجديدة

//------------------------------------------------------------------------------

enum LabStatus {
  openWithDevices,
  openNoDevices,
  closed,
}

//------------------------------------------------------------------------------

/// نموذج بيانات (Data Model) يمثل "المعمل" داخل النظام.
/// يرث من Equatable لضمان المقارنة الصحيحة بين الكائنات.
class LabModel extends Equatable {
  // <-- 2. جعله يرث من Equatable
  // --- الخصائص الأساسية للمعمل ---
  final String id;
  final String labNumber;
  final String college;
  final String department;
  final String floorNumber;
  final String type;
  final LabStatus status;
  final String notes;
  final List<String> deviceIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imagePath;
  final String? locationUrl;
  final double? latitude;
  final double? longitude;
  final String? createdBy;
  final String? createdByName; // <-- 3. إضافة الحقل الجديد لتحسين الأداء

  //------------------------------------------------------------------------------

  const LabModel({
    required this.id,
    required this.labNumber,
    required this.college,
    required this.department,
    required this.floorNumber,
    required this.type,
    required this.status,
    required this.notes,
    this.deviceIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
    this.locationUrl,
    this.latitude,
    this.longitude,
    this.createdBy,
    this.createdByName, // <-- 4. إضافته للبناء
  });

  //------------------------------------------------------------------------------

  /// *** [مهم] *** تحديد الخصائص التي سيتم استخدامها للمقارنة بين كائنين.
  /// هنا، نعتبر أن معملين متساويين إذا كان لهما نفس الـ id.
  @override
  List<Object?> get props => [id];

  //------------------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'labNumber': labNumber,
      'college': college,
      'department': department,
      'floorNumber': floorNumber,
      'type': type,
      'status': status.name,
      'notes': notes,
      'deviceIds': deviceIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'imagePath': imagePath,
      'locationUrl': locationUrl,
      'latitude': latitude,
      'longitude': longitude,
      'createdBy': createdBy,
      'createdByName': createdByName, // <-- 5. إضافته للخريطة
    };
  }

  //------------------------------------------------------------------------------

  factory LabModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.now();
    }

    return LabModel(
      id: map['id'] ?? '',
      labNumber: map['labNumber'] ?? '',
      college: map['college'] ?? '',
      department: map['department'] ?? '',
      floorNumber: map['floorNumber'] ?? '',
      type: map['type'] ?? '',
      status: LabStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => LabStatus.closed,
      ),
      notes: map['notes'] ?? '',
      deviceIds: List<String>.from(map['deviceIds'] ?? []),
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
      imagePath: map['imagePath'],
      locationUrl: map['locationUrl'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      createdBy: map['createdBy'],
      createdByName: map['createdByName'], // <-- 6. إضافته هنا
    );
  }

  //------------------------------------------------------------------------------

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
    String? createdBy,
    String? createdByName, // <-- 7. إضافته هنا
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
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName, // <-- 8. إضافته هنا
    );
  }

  //------------------------------------------------------------------------------

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
