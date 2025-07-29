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
import '../utils/custom_loading_indicator.dart'; // تأكد من أن المسار صحيح

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
    autoStart: false, // التحكم اليدوي هو الأفضل هنا
  );

  List<LabModel> _availableLabs = [];
  bool _isLoading = false;
  bool _isProcessing = false; // <-- [تمت الإضافة] القفل لمنع المسح المتكرر

  // ===========================================================================
  // 2. دورة حياة الويدجت (Widget Lifecycle)
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadLabs();
    // نبدأ الماسح مرة واحدة فقط عند تهيئة الشاشة
    _startScanner();
    developer.log('BarcodeScannerScreen: Scanner initialized and starting.');
  }

  @override
  void dispose() {
    // لا حاجة لاستدعاء _stopScanner هنا لأن dispose يقوم بذلك
    _scannerController.dispose();
    developer.log('BarcodeScannerScreen: Scanner disposed.');
    super.dispose();
  }

  // ===========================================================================
  // 3. دالة بناء واجهة المستخدم (UI Build Method)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح الباركود'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _scannerController.torchState,
            builder: (context, state, child) {
              return IconButton(
                color: state == TorchState.on ? Colors.amber : Colors.white,
                icon: Icon(
                    state == TorchState.on ? Icons.flash_on : Icons.flash_off),
                onPressed: () => _scannerController.toggleTorch(),
              );
            },
          ),
          ValueListenableBuilder(
            valueListenable: _scannerController.cameraFacingState,
            builder: (context, state, child) {
              return IconButton(
                icon: Icon(state == CameraFacing.front
                    ? Icons.camera_front
                    : Icons.camera_rear),
                onPressed: () => _scannerController.switchCamera(),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CustomLoadingIndicator())
          : Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleBarcodeScan,
                ),
                // إطار مرئي للمساعدة في توجيه الكاميرا
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Colors.green.withAlpha(179), width: 4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
    );
  }

  // ===========================================================================
  // 4. منطق العمل الرئيسي (Core Business Logic)
  // ===========================================================================

  /// *** [تم التصحيح] *** دالة لمعالجة الباركود مع استخدام قفل لمنع التكرار.
  Future<void> _handleBarcodeScan(BarcodeCapture capture) async {
    // إذا كنا نعالج باركود بالفعل، أو لم يتم اكتشاف أي شيء، تجاهل
    if (_isProcessing || capture.barcodes.isEmpty) {
      return;
    }

    // 1. تفعيل القفل فورًا وإيقاف الماسح لمنع أي استدعاءات أخرى
    setState(() => _isProcessing = true);
    await _scannerController.stop();
    developer.log(
        'BarcodeScannerScreen: Barcode detected, processing locked and scanner stopped.');

    final barcode = capture.barcodes.first;
    developer.log(
        'BarcodeScannerScreen: Barcode detected value: ${barcode.rawValue}');

    final barcodeData = BarcodeUtils.parseUniversityBarcode(barcode);
    final existingDevice = await _checkDeviceExists(barcodeData);

    if (!mounted) return;

    if (existingDevice != null) {
      await _showExistingDeviceDialog(existingDevice);
    } else {
      await _navigateToNewDeviceRegistration(barcodeData);
    }

    // 2. بعد الانتهاء من كل شيء، أعد تشغيل الماسح وحرر القفل
    developer
        .log('BarcodeScannerScreen: Process finished, restarting scanner.');
    _startScanner();
  }

  // ===========================================================================
  // 5. الدوال المساعدة (Helper Functions)
  // ===========================================================================

  void _startScanner() {
    if (!mounted) return;
    try {
      // إعادة تعيين القفل قبل البدء
      setState(() => _isProcessing = false);
      _scannerController.start();
      developer.log('BarcodeScannerScreen: Scanner started successfully.');
    } catch (e) {
      developer.log('BarcodeScannerScreen: Error starting scanner: $e');
      if (mounted) {
        UIHelpers.showErrorSnackBar(context, 'خطأ في بدء الماسح الضوئي: $e');
      }
    }
  }

  // لم نعد بحاجة لهذه الدالة بشكل منفصل
  // void _stopScanner() { ... }

  Future<void> _loadLabs() async {
    setState(() => _isLoading = true);
    try {
      final labs = await FirebaseDatabaseService.getLabs();
      if (!mounted) return;
      setState(() {
        _availableLabs = labs;
        _isLoading = false;
      });
    } catch (e) {
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

  Future<DeviceModel?> _checkDeviceExists(
      Map<String, String?> barcodeData) async {
    try {
      final device = await FirebaseDatabaseService.getDeviceByBarcode(
        barcodeData['barcode'] ?? '',
        barcodeData['assetCode'] ?? '',
      );
      return device;
    } catch (e) {
      developer.log('Error checking device existence', error: e);
      return null;
    }
  }

  Future<void> _showExistingDeviceDialog(DeviceModel device) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('جهاز موجود بالفعل'),
          content: Text('تم العثور على الجهاز: ${device.name}'),
          actions: [
            TextButton(
              child: const Text('متابعة المسح'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('عرض التفاصيل'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewDeviceScreen(device: device),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToNewDeviceRegistration(
      Map<String, String?> barcodeData) async {
    if (_availableLabs.isEmpty) {
      UIHelpers.showSnackBar(
        context: context,
        message: 'لا توجد معامل متاحة للتسجيل',
        type: SnackBarType.error,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDeviceScreen(scannedBarcodeData: barcodeData),
      ),
    );
  }
}
