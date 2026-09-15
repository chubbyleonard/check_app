import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => CheckProvider()..loadSavedData(),
      child: const CheckGeneratorApp(),
    ),
  );
}

class CheckGeneratorApp extends StatelessWidget {
  const CheckGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USA Bank Check Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F4C81)),
        useMaterial3: true,
      ),
      home: const CheckEditorScreen(),
    );
  }
}

// -------------------------------------------------------------
// STATE MANAGEMENT & DATA MODEL
// -------------------------------------------------------------
class CheckProvider extends ChangeNotifier {
  String bankName = 'JPMORGAN CHASE BANK, N.A.';
  String bankAddress = '1111 POLARIS PKWY, COLUMBUS, OH 43240';
  String routingNumber = '021000021';
  String accountNumber = '987654321098';
  String checkNumber = '1025';
  String payerName = 'JOHN DOE\n123 MAIN STREET\nANYTOWN, USA 12345';
  String payee = 'Jane Smith';
  String date = '10/24/2026';
  double amount = 250.75;
  String memo = 'Monthly Rent';
  
  Uint8List? logoBytes;
  Uint8List? signatureBytes;
  bool isVerifyingRouting = false;

  Future<void> loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    bankName = prefs.getString('bankName') ?? bankName;
    bankAddress = prefs.getString('bankAddress') ?? bankAddress;
    routingNumber = prefs.getString('routingNumber') ?? routingNumber;
    accountNumber = prefs.getString('accountNumber') ?? accountNumber;
    payerName = prefs.getString('payerName') ?? payerName;
    notifyListeners();
  }

  Future<void> savePersistentData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bankName', bankName);
    await prefs.setString('bankAddress', bankAddress);
    await prefs.setString('routingNumber', routingNumber);
    await prefs.setString('accountNumber', accountNumber);
    await prefs.setString('payerName', payerName);
  }

  void updateField({
    String? newBankName, String? newBankAddress, String? newRouting,
    String? newAccount, String? newCheckNum, String? newPayer,
    String? newPayee, String? newDate, double? newAmount, String? newMemo,
  }) {
    if (newBankName != null) bankName = newBankName;
    if (newBankAddress != null) bankAddress = newBankAddress;
    if (newRouting != null) routingNumber = newRouting;
    if (newAccount != null) accountNumber = newAccount;
    if (newCheckNum != null) checkNumber = newCheckNum;
    if (newPayer != null) payerName = newPayer;
    if (newPayee != null) payee = newPayee;
    if (newDate != null) date = newDate;
    if (newAmount != null) amount = newAmount;
    if (newMemo != null) memo = newMemo;
    notifyListeners();
  }

  void setSignature(Uint8List bytes) {
    signatureBytes = bytes;
    notifyListeners();
  }

  void clearSignature() {
    signatureBytes = null;
    notifyListeners();
  }

  Future<void> pickBankLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      logoBytes = await image.readAsBytes();
      notifyListeners();
    }
  }

  void clearLogo() {
    logoBytes = null;
    notifyListeners();
  }

  Future<String?> verifyRoutingNumber() async {
    if (routingNumber.length != 9) return 'Routing number must be exactly 9 digits.';
    isVerifyingRouting = true;
    notifyListeners();

    try {
      final targetUrl = 'https://www.routingnumbers.info/api/data.json?rn=$routingNumber';
      final fetchUrls = [
        targetUrl, 
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(targetUrl)}', 
        'https://corsproxy.io/?${Uri.encodeComponent(targetUrl)}', 
      ];
      
      http.Response? response;
      for (final url in fetchUrls) {
        try {
          response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) break;
        } catch (_) { continue; }
      }
      
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          bankName = data['customer_name'] ?? bankName;
          bankAddress = '${data['city'] ?? ''}, ${data['state'] ?? ''} ${data['zip'] ?? ''}'.trim();
          isVerifyingRouting = false;
          notifyListeners();
          return null; 
        } else {
          isVerifyingRouting = false;
          notifyListeners();
          return 'Routing number not found in database.';
        }
      } else {
        throw Exception("All proxy connections failed.");
      }
    } catch (e) {
      isVerifyingRouting = false;
      notifyListeners();
      return 'Browser blocked API connection. Will work natively in APK/iOS package.';
    }
  }

  String get amountInWords {
    int dollars = amount.floor();
    int cents = ((amount - dollars) * 100).round();
    return '${_convertNumberToWords(dollars).toUpperCase()} AND $cents/100 DOLLARS';
  }

  static String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';
    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    String result = '';
    if (number >= 1000000) { result += '${_convertNumberToWords(number ~/ 1000000)} Million '; number %= 1000000; }
    if (number >= 1000) { result += '${_convertNumberToWords(number ~/ 1000)} Thousand '; number %= 1000; }
    if (number >= 100) { result += '${units[number ~/ 100]} Hundred '; number %= 100; }
    if (number >= 20) { result += '${tens[number ~/ 10]} '; number %= 10; }
    if (number > 0) result += '${units[number]} ';
    return result.trim();
  }
}

// -------------------------------------------------------------
// SIGNATURE DRAWING PAD COMPONENT 
// -------------------------------------------------------------
class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black87
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0 
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -------------------------------------------------------------
// UI SCREEN & CONTROLS
// -------------------------------------------------------------
class CheckEditorScreen extends StatefulWidget {
  const CheckEditorScreen({super.key});
  @override
  State<CheckEditorScreen> createState() => _CheckEditorScreenState();
}

class _CheckEditorScreenState extends State<CheckEditorScreen> {
  late TextEditingController _payerCtrl, _payeeCtrl, _amountCtrl, _memoCtrl, _checkNumCtrl, _bankNameCtrl, _routingCtrl, _accountCtrl, _bankAddressCtrl;
  
  List<Offset?> _signaturePoints = [];
  final GlobalKey _signatureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final p = context.read<CheckProvider>();
    _payerCtrl = TextEditingController(text: p.payerName);
    _payeeCtrl = TextEditingController(text: p.payee);
    _amountCtrl = TextEditingController(text: p.amount.toStringAsFixed(2));
    _memoCtrl = TextEditingController(text: p.memo);
    _checkNumCtrl = TextEditingController(text: p.checkNumber);
    _bankNameCtrl = TextEditingController(text: p.bankName);
    _bankAddressCtrl = TextEditingController(text: p.bankAddress);
    _routingCtrl = TextEditingController(text: p.routingNumber);
    _accountCtrl = TextEditingController(text: p.accountNumber);

    p.addListener(_syncTextControllers);
  }

  void _syncTextControllers() {
    final p = context.read<CheckProvider>();
    if (_bankNameCtrl.text != p.bankName) _bankNameCtrl.text = p.bankName;
    if (_bankAddressCtrl.text != p.bankAddress) _bankAddressCtrl.text = p.bankAddress;
  }

  @override
  void dispose() {
    context.read<CheckProvider>().removeListener(_syncTextControllers);
    _payerCtrl.dispose(); _payeeCtrl.dispose(); _amountCtrl.dispose(); _memoCtrl.dispose(); 
    _checkNumCtrl.dispose(); _bankNameCtrl.dispose(); _bankAddressCtrl.dispose(); 
    _routingCtrl.dispose(); _accountCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureSignature() async {
    if (_signaturePoints.isEmpty) return;
    try {
      RenderRepaintBoundary boundary = _signatureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        context.read<CheckProvider>().setSignature(byteData.buffer.asUint8List());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proper Signature applied.')));
      }
    } catch (e) {
      debugPrint("Signature capture failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CheckProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('USA Check Studio', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Save Bank Defaults',
            icon: const Icon(Icons.save),
            onPressed: () async {
              await provider.savePersistentData();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank profile saved.')));
            },
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Generate PDF'),
            onPressed: () => _printCheckDocument(provider, context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        child: Column(
          children: [
            // Live Preview Section
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const AspectRatio(
                      aspectRatio: 6.0 / 2.75,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(width: 750, height: 343.75, child: CheckFrontPreview()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Form Controls
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Check Signing (Digital Ink)', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    const SizedBox(height: 12),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Authorized Signer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() => _signaturePoints.clear());
                                provider.clearSignature(); 
                              },
                              child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 14)),
                            ),
                            OutlinedButton.icon(
                              onPressed: _captureSignature,
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Apply'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      height: 120, 
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400)),
                      child: Stack(
                        children: [
                          Center(child: Text('Draw Signature Here', style: TextStyle(color: Colors.grey.shade300, fontSize: 16))),
                          RepaintBoundary(
                            key: _signatureKey,
                            child: Listener(
                              onPointerDown: (details) => setState(() => _signaturePoints.add(details.localPosition)),
                              onPointerMove: (details) => setState(() => _signaturePoints.add(details.localPosition)),
                              onPointerUp: (details) {
                                setState(() => _signaturePoints.add(null));
                              },
                              child: Container(
                                color: Colors.transparent,
                                child: CustomPaint(painter: SignaturePainter(_signaturePoints), size: Size.infinite),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text('Payer Information', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _payerCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Your Name & Address', border: OutlineInputBorder()),
                      onChanged: (val) => provider.updateField(newPayer: val),
                    ),
                    const SizedBox(height: 24),
                    Text('Check Details', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _payeeCtrl,
                      decoration: const InputDecoration(labelText: 'Payee (Pay to Order of)', border: OutlineInputBorder()),
                      onChanged: (val) => provider.updateField(newPayee: val),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ ', border: OutlineInputBorder()),
                            onChanged: (val) => provider.updateField(newAmount: double.tryParse(val) ?? 0.0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _checkNumCtrl,
                            decoration: const InputDecoration(labelText: 'Check #', border: OutlineInputBorder()),
                            onChanged: (val) => provider.updateField(newCheckNum: val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _memoCtrl,
                      decoration: const InputDecoration(labelText: 'Memo', border: OutlineInputBorder()),
                      onChanged: (val) => provider.updateField(newMemo: val),
                    ),
                    const SizedBox(height: 24),
                    
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text('Bank Setup (ANSI X9)', style: Theme.of(context).textTheme.titleMedium),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (provider.logoBytes != null)
                              TextButton(
                                onPressed: provider.clearLogo,
                                child: const Text('Remove Logo', style: TextStyle(color: Colors.red)),
                              ),
                            OutlinedButton.icon(
                              onPressed: provider.pickBankLogo,
                              icon: const Icon(Icons.image, size: 16),
                              label: const Text('Manual Logo'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _routingCtrl,
                            maxLength: 9,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Routing (ABA)', border: OutlineInputBorder(), counterText: ''),
                            onChanged: (val) => provider.updateField(newRouting: val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                          onPressed: provider.isVerifyingRouting ? null : () async {
                            final error = await provider.verifyRoutingNumber();
                            if (error != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.redAccent));
                            }
                          },
                          child: provider.isVerifyingRouting 
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) 
                              : const Text('Verify Auto-Logo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _accountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder()),
                      onChanged: (val) => provider.updateField(newAccount: val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bankNameCtrl,
                      decoration: const InputDecoration(labelText: 'Bank Legal Name', border: OutlineInputBorder()),
                      onChanged: (val) => provider.updateField(newBankName: val),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bankAddressCtrl,
                      decoration: const InputDecoration(labelText: 'Bank City, State ZIP', border: OutlineInputBorder()),
                      onChanged: (val) => provider.updateField(newBankAddress: val),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------
  // PDF GENERATION & FILE SAVING ENGINE
  // -----------------------------------------------------------
  Future<void> _printCheckDocument(CheckProvider p, BuildContext context) async {
    try {
      final pdf = pw.Document();
      pw.Font? micrFont;
      pw.Font? handwritingFont;
      
      try {
        final micrFontData = await rootBundle.load("assets/fonts/MICR-E13B.ttf");
        micrFont = pw.Font.ttf(micrFontData);
      } catch (e) {
        micrFont = pw.Font.courier();
      }

      try {
        final hwFontData = await rootBundle.load("assets/fonts/Handwriting.ttf");
        handwritingFont = pw.Font.ttf(hwFontData);
      } catch (e) {
        handwritingFont = pw.Font.helveticaOblique();
      }

      /// ==========================================
      /// 🛠️ TWEAK ZONE: PDF ALIGNMENT & THICKNESS
      /// ==========================================
      const double pdfMemoLineThickness = 0.6;      
      const double pdfSignatureLineThickness = 1.0; 
      const double pdfSignatureImageHeight = 40.0; 
      const double pdfSignatureImageBottomOffset = 4.0; 
      /// ==========================================

      final pageFormat = PdfPageFormat(6.0 * PdfPageFormat.inch, 2.75 * PdfPageFormat.inch, marginAll: 0);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context ctx) {
            return pw.Container(
              padding: pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EBF3F8'), 
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5)
              ),
              child: pw.Stack(
                children: [
                  pw.Positioned(top: 0, left: 0, child: pw.Text(p.payerName, style: pw.TextStyle(fontSize: 8, height: 1.2))),
                  pw.Align(
                    alignment: pw.Alignment.topCenter,
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        if (p.logoBytes != null)
                          pw.Container(
                            height: 24,
                            margin: pw.EdgeInsets.only(bottom: 4),
                            child: pw.Image(pw.MemoryImage(p.logoBytes!)),
                          ),
                        pw.Text(p.bankName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text(p.bankAddress, style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.Positioned(
                    top: 0, right: 0,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(p.checkNumber, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 12),
                        pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text('Date: ', style: pw.TextStyle(fontSize: 9)),
                            pw.Container(
                              padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                              child: pw.Text(p.date, style: pw.TextStyle(font: handwritingFont, fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.Positioned(
                    top: 65, left: 0, right: 0,
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('PAY TO THE\nORDER OF ', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Container(
                            padding: pw.EdgeInsets.only(bottom: 2),
                            decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                            child: pw.Text(p.payee, style: pw.TextStyle(font: handwritingFont, fontSize: 14)), 
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Container(
                          padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
                          child: pw.Text('\$ ${p.amount.toStringAsFixed(2)}', style: pw.TextStyle(font: handwritingFont, fontSize: 12)), 
                        ),
                      ],
                    ),
                  ),
                  pw.Positioned(
                    top: 100, left: 0, right: 0,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                      padding: pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(p.amountInWords, style: pw.TextStyle(font: handwritingFont, fontSize: 12)), 
                    ),
                  ),
                  
                  // FIXED ALIGNMENT: Pushed all the way down to bottom: 15
                  pw.Positioned(
                    bottom: 15, left: 0, right: 0,
                    child: pw.Container(
                      height: 25, 
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Expanded(
                            flex: 4,
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Padding(
                                  padding: pw.EdgeInsets.only(bottom: 2, right: 4),
                                  child: pw.Text('MEMO ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                                ),
                                pw.Expanded(
                                  child: pw.Container(
                                    padding: pw.EdgeInsets.only(bottom: 2),
                                    decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: pdfMemoLineThickness))),
                                    child: pw.Text(p.memo, style: pw.TextStyle(font: handwritingFont, fontSize: 10)), 
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.Spacer(flex: 1),
                          pw.Expanded(
                            flex: 5,
                            child: pw.Stack(
                              alignment: pw.Alignment.bottomCenter,
                              children: [
                                pw.Container(
                                  width: double.infinity,
                                  padding: pw.EdgeInsets.only(bottom: 2),
                                  decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: pdfSignatureLineThickness))),
                                  alignment: pw.Alignment.bottomRight,
                                  child: pw.Text('AUTHORIZED SIGNATURE', style: pw.TextStyle(fontSize: 5)),
                                ),
                                if (p.signatureBytes != null)
                                  pw.Positioned(
                                    bottom: pdfSignatureImageBottomOffset,
                                    left: 0, right: 0,
                                    child: pw.Center(
                                      child: pw.Image(pw.MemoryImage(p.signatureBytes!), height: pdfSignatureImageHeight, fit: pw.BoxFit.contain), 
                                    ),
                                  ),
                              ]
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: pw.Center(
                      child: pw.Text(
                        'A${p.routingNumber}A  ${p.accountNumber}C  ${p.checkNumber}',
                        style: pw.TextStyle(font: micrFont, fontSize: 13, letterSpacing: 2), 
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Check_${p.checkNumber}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Generation Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}

// -------------------------------------------------------------
// LIVE VISUAL CANVAS PREVIEW (FRONT ONLY)
// -------------------------------------------------------------
class CheckFrontPreview extends StatelessWidget {
  const CheckFrontPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CheckProvider>();

    /// ==========================================
    /// 🛠️ TWEAK ZONE: SCREEN ALIGNMENT & THICKNESS
    /// ==========================================
    const double screenMemoLineThickness = 1.0;
    const double screenSignatureLineThickness = 1.2;
    const double screenSignatureImageHeight = 50.0; 
    const double screenSignatureImageBottomOffset = 2.0;
    /// ==========================================
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3F8), 
        border: Border.all(color: Colors.blueGrey.shade300, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(p.payerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.25, color: Colors.black87)),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.logoBytes != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Image.memory(p.logoBytes!, height: 42, fit: BoxFit.contain),
                  ),
                Text(p.bankName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                Text(p.bankAddress, style: TextStyle(fontSize: 9, color: Colors.grey.shade800)),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.checkNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Date: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black87, width: 1.0))),
                      child: Text(p.date, style: const TextStyle(fontFamily: 'Handwriting', fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 100, left: 0, right: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('PAY TO THE\nORDER OF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black87, width: 1.0))),
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(p.payee.isEmpty ? ' ' : p.payee, style: const TextStyle(fontFamily: 'Handwriting', fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: Colors.black87, width: 1.0), color: Colors.white),
                  child: Text('\$ ${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Handwriting', fontSize: 18)), 
                ),
              ],
            ),
          ),
          Positioned(
            top: 160, left: 0, right: 0,
            child: Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black87, width: 1.0))),
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(p.amountInWords, style: const TextStyle(fontFamily: 'Handwriting', fontSize: 18)),
            ),
          ),
          
          // FIXED ALIGNMENT: Pushed all the way down to bottom: 22 to close the huge gap
          Positioned(
            bottom: 22, left: 0, right: 0,
            child: SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 2, right: 6),
                          child: Text('MEMO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black87, width: screenMemoLineThickness))),
                            child: Text(p.memo, style: const TextStyle(fontFamily: 'Handwriting', fontSize: 16, height: 1.0)), 
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 1),
                  Expanded(
                    flex: 5,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black87, width: screenSignatureLineThickness))),
                          alignment: Alignment.bottomRight,
                          child: const Text('AUTHORIZED SIGNATURE', style: TextStyle(fontSize: 7, color: Colors.black54)),
                        ),
                        if (p.signatureBytes != null)
                          Positioned(
                            bottom: screenSignatureImageBottomOffset, 
                            left: 0, right: 0,
                            child: Center(
                              child: Image.memory(p.signatureBytes!, height: screenSignatureImageHeight, fit: BoxFit.contain),
                            ),
                          ),
                      ]
                    )
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 2, left: 0, right: 0,
            child: Center(
              child: Text('A${p.routingNumber}A  ${p.accountNumber}C  ${p.checkNumber}', style: const TextStyle(fontFamily: 'MICR', fontSize: 19, letterSpacing: 2)), 
            ),
          ),
        ],
      ),
    );
  }
}