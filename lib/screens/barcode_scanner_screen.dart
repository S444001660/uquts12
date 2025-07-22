import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // مكتبة لمسح الباركود باستخدام الكاميرا.
// لتوليد معرفات فريدة (IDs).
import 'dart:developer'
    as developer; // لتسجيل الأخطاء والرسائل التشخيصية المتقدمة.

import '../models/device_model.dart'; // نموذج بيانات الجهاز.
import '../models/lab_model.dart'; // نموذج بيانات المعمل.
import 'package:uquts1/services/firebase_database_service.dart';
import '../screens/view_device_screen.dart'; // الشاشة الجديدة لعرض الجهاز فقط.
import '../screens/add_device_screen.dart'; // شاشة إضافة/تعديل جهاز.
import '../utils/ui_helpers.dart'; // دوال مساعدة لعرض عناصر واجهة المستخدم.
import '../utils/barcode_utils.dart'; // دوال مساعدة لتحليل بيانات الباركود.
// دوال التحقق من صحة المدخلات.
// ثوابت وقوائم مستخدمة في الفورم.

//------------------------------------------------------------------------------

// ويدجت شاشة ماسح الباركود، وهي StatefulWidget لأن حالتها تتغير.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  BarcodeScannerScreenState createState() => BarcodeScannerScreenState();
}

//------------------------------------------------------------------------------

// كلاس الحالة (State) الخاص بـ BarcodeScannerScreen.
class BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // متحكم (Controller) للتحكم في ماسح الباركود (الكاميرا).
  // تم تعطيل التشغيل التلقائي (autoStart: false) للتحكم الكامل في بدء وإيقاف الماسح.
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal, // سرعة اكتشاف الباركود.
    facing: CameraFacing.back, // استخدام الكاميرا الخلفية افتراضيًا.
    autoStart: false, // <--- مهم جداً: تعطيل التشغيل التلقائي
  );

  //------------------------------------------------------------------------------

  // متغيرات الحالة (State)
  List<LabModel> _availableLabs = []; // قائمة لتخزين المعامل المتاحة.
  bool _isLoading = false; // لتتبع حالة تحميل المعامل.

  //------------------------------------------------------------------------------

  /// دالة تُستدعى مرة واحدة عند بناء الويدجت لأول مرة.
  @override
  void initState() {
    super.initState();
    _loadLabs(); // تحميل قائمة المعامل عند بدء الشاشة.
    _startScanner(); // بدء الماسح الضوئي يدوياً بشكل صريح.
    developer.log(
        'BarcodeScannerScreen: Scanner initialized and explicitly starting in initState.');
  }

  //------------------------------------------------------------------------------

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

  //------------------------------------------------------------------------------

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

  //------------------------------------------------------------------------------

  /// دالة تُستدعى عند إزالة الويدجت، لتحرير الموارد ومنع تسرب الذاكرة.
  @override
  void dispose() {
    _stopScanner(); // التأكد من إيقاف الماسح عند إغلاق الشاشة.
    _scannerController.dispose(); // التخلص من متحكم الكاميرا.
    developer.log('BarcodeScannerScreen: Scanner disposed in dispose.');
    super.dispose();
  }

  //------------------------------------------------------------------------------

  /// دالة غير متزامنة لتحميل قائمة المعامل من قاعدة البيانات.
  /// هذه القائمة ضرورية في حالة تسجيل جهاز جديد لتحديد معمله.
  Future<void> _loadLabs() async {
    setState(() => _isLoading = true);
    try {
      final labs = await FirebaseDatabaseService.getLabs();
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

  //------------------------------------------------------------------------------

  /// دالة لمعالجة الباركود بعد اكتشافه بواسطة الكاميرا.
  Future<void> _handleBarcodeScan(BarcodeCapture capture) async {
    if (capture.barcodes.isEmpty) {
      developer.log('BarcodeScannerScreen: No barcode detected.');
      return;
    }

    _stopScanner(); // إيقاف الماسح مؤقتاً لمنع المسح المتكرر.
    developer
        .log('BarcodeScannerScreen: Scanner stopped due to barcode detection.');

    final barcode = capture.barcodes.first;
    developer
        .log('BarcodeScannerScreen: Barcode detected: ${barcode.rawValue}');

    // تحليل بيانات الباركود باستخدام دالة مساعدة.
    final barcodeData = BarcodeUtils.parseUniversityBarcode(barcode);

    // التحقق مما إذا كان الجهاز موجوداً بالفعل في قاعدة البيانات.
    final existingDevice = await _checkDeviceExists(barcodeData);

    if (existingDevice != null) {
      // إذا كان الجهاز موجوداً، يتم عرض نافذة حوارية.
      _showExistingDeviceDialog(existingDevice);
    } else {
      // إذا لم يكن موجوداً، يتم الانتقال لشاشة تسجيل جهاز جديد.
      _navigateToNewDeviceRegistration(barcodeData);
    }
  }

  //------------------------------------------------------------------------------

  /// دالة للتحقق من وجود الجهاز في قاعدة البيانات بناءً على بيانات الباركود.
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

  //------------------------------------------------------------------------------

  /// دالة لعرض نافذة منبثقة للمستخدم تخبره بأن الجهاز موجود بالفعل.
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
                    // بعد العودة من شاشة عرض التفاصيل، يتم إعادة تشغيل الماسح.
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
      // هذا الجزء يتم استدعاؤه أيضاً إذا تم إغلاق الحوار بطريقة أخرى (مثل زر الرجوع).
      developer.log(
          'BarcodeScannerScreen: Existing device dialog dismissed (external dismissal or pop), restarting scanner.');
      _startScanner(); // إعادة تشغيل الماسح الضوئي.
    });
  }

  //------------------------------------------------------------------------------

  /// دالة للانتقال إلى شاشة تسجيل جهاز جديد، مع تمرير بيانات الباركود.
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

    // الانتقال لشاشة إضافة جهاز وتمرير بيانات الباركود لملء الحقول تلقائياً.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDeviceScreen(scannedBarcodeData: barcodeData),
      ),
    ).then((_) {
      // عند العودة من شاشة إضافة الجهاز، أعد تشغيل الماسح الضوئي.
      developer.log(
          'BarcodeScannerScreen: Returned from AddDeviceScreen (new device), restarting scanner.');
      _startScanner();
    });
  }

  //------------------------------------------------------------------------------

  /// الدالة الأساسية لبناء واجهة المستخدم (UI) للشاشة بأكملها.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح الباركود'),
        actions: [
          // زر للتحكم في فلاش الكاميرا.
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.grey),
            onPressed: () {
              _scannerController.toggleTorch();
              developer.log('BarcodeScannerScreen: Torch toggled.');
            },
          ),
          // زر للتبديل بين الكاميرا الأمامية والخلفية.
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
}
