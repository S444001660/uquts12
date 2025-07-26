// استيراد المكتبات الضرورية
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:developer' as developer;

import '../models/device_model.dart';
import '../models/lab_model.dart';
import '../services/firebase_database_service.dart';
import '../screens/view_device_screen.dart';
import '../screens/add_device_screen.dart';
import '../utils/ui_helpers.dart';
import '../utils/barcode_utils.dart';

//------------------------------------------------------------------------------

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  BarcodeScannerScreenState createState() => BarcodeScannerScreenState();
}

//------------------------------------------------------------------------------

class BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // ===========================================================================
  // 1. تعريفات الحالة والمتحكمات (State & Controllers)
  // ===========================================================================

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    autoStart: false, // تعطيل التشغيل التلقائي للتحكم الكامل
  );

  List<LabModel> _availableLabs = [];
  bool _isLoading = false;

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle) - (أساسي)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadLabs();
    _startScanner(); // بدء الماسح يدوياً بشكل صريح
    developer.log('BarcodeScannerScreen: Scanner initialized and starting.');
  }

  @override
  void dispose() {
    _stopScanner(); // التأكد من إيقاف الماسح عند إغلاق الشاشة
    _scannerController.dispose();
    developer.log('BarcodeScannerScreen: Scanner disposed.');
    super.dispose();
  }

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method) - (أساسي)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح الباركود'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.grey),
            onPressed: () {
              _scannerController.toggleTorch();
              developer.log('BarcodeScannerScreen: Torch toggled.');
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_rear),
            onPressed: () {
              _scannerController.switchCamera();
              developer.log('BarcodeScannerScreen: Camera switched.');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : MobileScanner(
              controller: _scannerController,
              onDetect: _handleBarcodeScan,
            ),
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي (Core Business Logic) - (أساسي)
  // ===========================================================================

  /// دالة لمعالجة الباركود بعد اكتشافه بواسطة الكاميرا.
  Future<void> _handleBarcodeScan(BarcodeCapture capture) async {
    if (capture.barcodes.isEmpty) {
      developer.log('BarcodeScannerScreen: No barcode detected.');
      return;
    }

    _stopScanner(); // إيقاف الماسح مؤقتاً لمنع المسح المتكرر
    developer
        .log('BarcodeScannerScreen: Scanner stopped due to barcode detection.');

    final barcode = capture.barcodes.first;
    developer
        .log('BarcodeScannerScreen: Barcode detected: ${barcode.rawValue}');

    final barcodeData = BarcodeUtils.parseUniversityBarcode(barcode);
    final existingDevice = await _checkDeviceExists(barcodeData);

    if (!mounted) return; // تحقق إضافي للأمان

    if (existingDevice != null) {
      _showExistingDeviceDialog(existingDevice);
    } else {
      _navigateToNewDeviceRegistration(barcodeData);
    }
  }

  // ===========================================================================
  // 5. الدوال المساعدة (Helper Functions) - (يمكن فصلها)
  // ===========================================================================

  /// دالة لبدء الماسح الضوئي (الكاميرا) بشكل آمن.
  void _startScanner() {
    Future.microtask(() async {
      if (!mounted) {
        developer.log(
            'BarcodeScannerScreen: _startScanner called but widget is not mounted.');
        return;
      }
      try {
        await _scannerController.start();
        developer.log('BarcodeScannerScreen: Scanner started successfully.');
      } catch (e) {
        developer.log('BarcodeScannerScreen: Error starting scanner: $e');
        if (mounted) {
          UIHelpers.showErrorSnackBar(context, 'خطأ في بدء الماسح الضوئي: $e');
        }
      }
    });
  }

  /// دالة لإيقاف الماسح الضوئي (الكاميرا) بشكل آمن.
  void _stopScanner() {
    Future.microtask(() async {
      if (!mounted) {
        developer.log(
            'BarcodeScannerScreen: _stopScanner called but widget is not mounted.');
        return;
      }
      try {
        await _scannerController.stop();
        developer.log('BarcodeScannerScreen: Scanner stopped successfully.');
      } catch (e) {
        developer.log('BarcodeScannerScreen: Error stopping scanner: $e');
        if (mounted) {
          UIHelpers.showErrorSnackBar(
              context, 'خطأ في إيقاف الماسح الضوئي: $e');
        }
      }
    });
  }

  /// دالة لتحميل قائمة المعامل من قاعدة البيانات.
  Future<void> _loadLabs() async {
    setState(() => _isLoading = true);
    try {
      final labs = await FirebaseDatabaseService.getLabs();
      if (!mounted) return;
      setState(() {
        _availableLabs = labs;
        _isLoading = false;
      });
      developer.log(
          'BarcodeScannerScreen: Labs loaded successfully. Count: ${labs.length}');
    } catch (e) {
      developer.log('Error loading labs',
          name: 'BarcodeScannerScreen',
          level: 1000, // مستوى الخطورة (SEVERE).
          error: e,
          stackTrace: StackTrace.current);

      if (mounted) {
        UIHelpers.showSnackBar(
          context: context,
          message: 'خطأ في تحميل المعامل: ${e.toString()}',
          type: SnackBarType.error,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// دالة للتحقق من وجود الجهاز في قاعدة البيانات.
  Future<DeviceModel?> _checkDeviceExists(
      Map<String, String?> barcodeData) async {
    try {
      developer.log(
          'BarcodeScannerScreen: Checking if device exists for barcode/assetCode: ${barcodeData['barcode'] ?? ''} / ${barcodeData['assetCode'] ?? ''}');
      final device = await FirebaseDatabaseService.getDeviceByBarcode(
        barcodeData['barcode'] ?? '',
        barcodeData['assetCode'] ?? '',
      );
      if (device != null) {
        developer.log('BarcodeScannerScreen: Device found: ${device.name}');
      } else {
        developer.log('BarcodeScannerScreen: Device not found.');
      }
      return device;
    } catch (e) {
      developer.log('Error checking device existence',
          name: 'BarcodeScannerScreen',
          level: 1000,
          error: e,
          stackTrace: StackTrace.current);
      return null;
    }
  }

  /// دالة لعرض نافذة حوارية للجهاز الموجود.
  void _showExistingDeviceDialog(DeviceModel device) {
    developer.log(
        'BarcodeScannerScreen: Showing existing device dialog for ${device.name}.');
    showDialog(
      context: context,
      barrierDismissible: false, // لا يمكن إغلاقه بالنقر خارجاً.
      builder: (context) {
        return AlertDialog(
          title: const Text('جهاز موجود بالفعل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تم العثور على الجهاز: ${device.name}',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  developer.log(
                      'BarcodeScannerScreen: "View Device Details" button pressed for existing device.');
                  Navigator.pop(context); // إغلاق AlertDialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewDeviceScreen(device: device),
                    ),
                  ).then((_) {
                    developer.log(
                        'BarcodeScannerScreen: Returned from ViewDeviceScreen, restarting scanner.');
                    _startScanner();
                  });
                },
                child: const Text('عرض تفاصيل الجهاز'),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      developer.log(
          'BarcodeScannerScreen: Existing device dialog dismissed (external dismissal or pop), restarting scanner.');
      _startScanner(); // إعادة تشغيل الماسح الضوئي.
    });
  }

  /// دالة للانتقال إلى شاشة تسجيل جهاز جديد.
  void _navigateToNewDeviceRegistration(Map<String, String?> barcodeData) {
    developer.log(
        'BarcodeScannerScreen: Navigating to AddDeviceScreen for new device registration.');
    if (_availableLabs.isEmpty) {
      UIHelpers.showSnackBar(
        context: context,
        message: 'لا توجد معامل متاحة للتسجيل',
        type: SnackBarType.error,
      );
      _startScanner(); // أعد تشغيل الماسح الضوئي إذا لم تكن هناك معامل.
      developer
          .log('BarcodeScannerScreen: No labs available, restarting scanner.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDeviceScreen(scannedBarcodeData: barcodeData),
      ),
    ).then((_) {
      developer.log(
          'BarcodeScannerScreen: Returned from AddDeviceScreen (new device), restarting scanner.');
      _startScanner();
    });
  }
}
