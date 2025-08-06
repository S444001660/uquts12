import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

//------------------------------------------------------------------------------

/// نموذج بيانات (Data Model) يمثل "الجهاز" داخل النظام.
/// يرث من Equatable لضمان المقارنة الصحيحة بين الكائنات.
class DeviceModel extends Equatable {
  // --- الخصائص الأساسية للجهاز ---
  final String id;
  final String name;
  final String college;
  final String department;
  final String model;
  final String serialNumber;
  final String processor;
  final String? ramSize; // <-- 1. تمت الإضافة هنا
  final String storageType;
  final String storageSize;

  // --- معلومات التخزين الإضافي ---
  final bool hasExtraStorage;
  final String? extraStorageType;
  final String? extraStorageSize;

  // --- خصائص أخرى ---
  final String osVersion;
  final String notes;
  final String labId;
  final String? universityBarcode;
  final String? assetSource;
  final String? assetCategory;
  final String? assetCode;
  final bool needsMaintenance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imagePath;
  final String? createdBy;
  final String? createdByName;

  //------------------------------------------------------------------------------

  const DeviceModel({
    required this.id,
    required this.name,
    required this.college,
    this.department = '',
    required this.model,
    required this.serialNumber,
    required this.processor,
    this.ramSize, // <-- 2. تمت الإضافة هنا
    required this.storageType,
    required this.storageSize,
    this.hasExtraStorage = false,
    this.extraStorageType,
    this.extraStorageSize,
    required this.osVersion,
    this.notes = '',
    this.labId = '',
    this.universityBarcode,
    this.assetSource,
    this.assetCategory,
    this.assetCode,
    this.needsMaintenance = false,
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
    this.createdBy,
    this.createdByName,
  });

  //------------------------------------------------------------------------------

  @override
  List<Object?> get props => [id];

  //------------------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'college': college,
      'department': department,
      'model': model,
      'serialNumber': serialNumber,
      'processor': processor,
      'ramSize': ramSize, // <-- 3. تمت الإضافة هنا
      'storageType': storageType,
      'storageSize': storageSize,
      'hasExtraStorage': hasExtraStorage,
      'extraStorageType': extraStorageType,
      'extraStorageSize': extraStorageSize,
      'osVersion': osVersion,
      'notes': notes,
      'labId': labId,
      'universityBarcode': universityBarcode,
      'assetSource': assetSource,
      'assetCategory': assetCategory,
      'assetCode': assetCode,
      'needsMaintenance': needsMaintenance,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'imagePath': imagePath,
      'createdBy': createdBy,
      'createdByName': createdByName,
    };
  }

  //------------------------------------------------------------------------------

  factory DeviceModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      return DateTime.now();
    }

    return DeviceModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      college: map['college'] ?? '',
      department: map['department'] ?? '',
      model: map['model'] ?? '',
      serialNumber: map['serialNumber'] ?? '',
      processor: map['processor'] ?? '',
      ramSize: map['ramSize'], // <-- 4. تمت الإضافة هنا
      storageType: map['storageType'] ?? '',
      storageSize: map['storageSize'] ?? '',
      hasExtraStorage: map['hasExtraStorage'] ?? false,
      extraStorageType: map['extraStorageType'],
      extraStorageSize: map['extraStorageSize'],
      osVersion: map['osVersion'] ?? '',
      notes: map['notes'] ?? '',
      labId: map['labId'] ?? '',
      universityBarcode: map['universityBarcode'],
      assetSource: map['assetSource'],
      assetCategory: map['assetCategory'],
      assetCode: map['assetCode'],
      needsMaintenance: map['needsMaintenance'] ?? false,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
      imagePath: map['imagePath'],
      createdBy: map['createdBy'],
      createdByName: map['createdByName'],
    );
  }

  //------------------------------------------------------------------------------

  DeviceModel copyWith({
    String? id,
    String? name,
    String? college,
    String? department,
    String? model,
    String? serialNumber,
    String? processor,
    String? ramSize, // <-- 5. تمت الإضافة هنا
    String? storageType,
    String? storageSize,
    bool? hasExtraStorage,
    String? extraStorageType,
    String? extraStorageSize,
    String? osVersion,
    String? notes,
    String? labId,
    String? universityBarcode,
    String? assetSource,
    String? assetCategory,
    String? assetCode,
    bool? needsMaintenance,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imagePath,
    String? createdBy,
    String? createdByName,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      college: college ?? this.college,
      department: department ?? this.department,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      processor: processor ?? this.processor,
      ramSize: ramSize ?? this.ramSize, // <-- 6. تمت الإضافة هنا
      storageType: storageType ?? this.storageType,
      storageSize: storageSize ?? this.storageSize,
      hasExtraStorage: hasExtraStorage ?? this.hasExtraStorage,
      extraStorageType: extraStorageType ?? this.extraStorageType,
      extraStorageSize: extraStorageSize ?? this.extraStorageSize,
      osVersion: osVersion ?? this.osVersion,
      notes: notes ?? this.notes,
      labId: labId ?? this.labId,
      universityBarcode: universityBarcode ?? this.universityBarcode,
      assetSource: assetSource ?? this.assetSource,
      assetCategory: assetCategory ?? this.assetCategory,
      assetCode: assetCode ?? this.assetCode,
      needsMaintenance: needsMaintenance ?? this.needsMaintenance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePath: imagePath ?? this.imagePath,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
    );
  }
}
