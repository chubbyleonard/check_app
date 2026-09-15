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
// CHECK TEMPLATE SYSTEM (PROCEDURAL GENERATION)
// -------------------------------------------------------------
class CheckTemplate {
  final String name;
  final List<Color> bgGradient;
  final List<PdfColor> pdfBgGradient;
  final Color lineColor;
  final PdfColor pdfLineColor;
  
  CheckTemplate({
    required this.name, required this.bgGradient, required this.pdfBgGradient,
    required this.lineColor, required this.pdfLineColor,
  });
}

final List<CheckTemplate> checkTemplates = [
  CheckTemplate(
    name: 'Classic Blue',
    bgGradient: [const Color(0xFFEBF3F8), Colors.white, const Color(0xFFD4E6F1)],
    pdfBgGradient: [PdfColor.fromHex('#EBF3F8'), PdfColors.white, PdfColor.fromHex('#D4E6F1')],
    lineColor: const Color(0xFF34495E), pdfLineColor: PdfColor.fromHex('#34495E'),
  ),
  CheckTemplate(
    name: 'Executive Red',
    bgGradient: [const Color(0xFFF9EBEA), Colors.white, const Color(0xFFF2D7D5)],
    pdfBgGradient: [PdfColor.fromHex('#F9EBEA'), PdfColors.white, PdfColor.fromHex('#F2D7D5')],
    lineColor: const Color(0xFF7B241C), pdfLineColor: PdfColor.fromHex('#7B241C'),
  ),
  CheckTemplate(
    name: 'Forest Green',
    bgGradient: [const Color(0xFFE9F7EF), Colors.white, const Color(0xFFD4EFDF)],
    pdfBgGradient: [PdfColor.fromHex('#E9F7EF'), PdfColors.white, PdfColor.fromHex('#D4EFDF')],
    lineColor: const Color(0xFF145A32), pdfLineColor: PdfColor.fromHex('#145A32'),
  ),
  CheckTemplate(
    name: 'Royal Purple',
    bgGradient: [const Color(0xFFF4ECF7), Colors.white, const Color(0xFFE8DAEF)],
    pdfBgGradient: [PdfColor.fromHex('#F4ECF7'), PdfColors.white, PdfColor.fromHex('#E8DAEF')],
    lineColor: const Color(0xFF512E5F), pdfLineColor: PdfColor.fromHex('#512E5F'),
  ),
  CheckTemplate(
    name: 'Parchment Gold',
    bgGradient: [const Color(0xFFFBF6E9), Colors.white, const Color(0xFFF5EACF)],
    pdfBgGradient: [PdfColor.fromHex('#FBF6E9'), PdfColors.white, PdfColor.fromHex('#F5EACF')],
    lineColor: const Color(0xFF6E552F), pdfLineColor: PdfColor.fromHex('#6E552F'),
  ),
  CheckTemplate(
    name: 'Modern Slate',
    bgGradient: [const Color(0xFFF0F2F5), Colors.white, const Color(0xFFE5E7E9)],
    pdfBgGradient: [PdfColor.fromHex('#F0F2F5'), PdfColors.white, PdfColor.fromHex('#E5E7E9')],
    lineColor: const Color(0xFF2C3E50), pdfLineColor: PdfColor.fromHex('#2C3E50'),
  ),
];

// -------------------------------------------------------------
// STATE MANAGEMENT & DATA MODEL
// -------------------------------------------------------------
class CheckProvider extends ChangeNotifier {
  String bankName = 'JPMORGAN CHASE BANK, N.A.';
  String bankAddress = '1111 POLARIS PKWY, COLUMBUS, OH 43240';
  String domain = 'chase.com';
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
  bool showWatermark = true;
  CheckTemplate selectedTemplate = checkTemplates[0];
  
  Map<String, dynamic> _offlineDatabase = {};
  Map<String, dynamic> _myCustomBanks = {}; 

  Future<void> loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    bankName = prefs.getString('bankName') ?? bankName;
    bankAddress = prefs.getString('bankAddress') ?? bankAddress;
    domain = prefs.getString('domain') ?? domain;
    routingNumber = prefs.getString('routingNumber') ?? routingNumber;
    accountNumber = prefs.getString('accountNumber') ?? accountNumber;
    payerName = prefs.getString('payerName') ?? payerName;
    date = prefs.getString('date') ?? date;
    showWatermark = prefs.getBool('showWatermark') ?? true;
    
    final templateName = prefs.getString('selectedTemplate');
    if (templateName != null) {
      selectedTemplate = checkTemplates.firstWhere((t) => t.name == templateName, orElse: () => checkTemplates[0]);
    }

    final customBanksString = prefs.getString('myCustomBanks');
    if (customBanksString != null) {
      _myCustomBanks = json.decode(customBanksString);
    }
    
    _autoSelectTemplate(bankName);
    notifyListeners();
  }

  Future<void> savePersistentData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bankName', bankName);
    await prefs.setString('bankAddress', bankAddress);
    await prefs.setString('domain', domain);
    await prefs.setString('routingNumber', routingNumber);
    await prefs.setString('accountNumber', accountNumber);
    await prefs.setString('payerName', payerName);
    await prefs.setString('date', date);
    await prefs.setBool('showWatermark', showWatermark);
    await prefs.setString('selectedTemplate', selectedTemplate.name);
  }

  Future<void> saveCurrentBankToCustomList() async {
    if (routingNumber.length == 9 && bankName.isNotEmpty) {
      _myCustomBanks[routingNumber] = {
        'name': bankName,
        'address': bankAddress,
        'domain': domain,
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('myCustomBanks', json.encode(_myCustomBanks));
      notifyListeners();
    }
  }

  void updateField({
    String? newBankName, String? newBankAddress, String? newDomain, String? newRouting,
    String? newAccount, String? newCheckNum, String? newPayer,
    String? newPayee, String? newDate, double? newAmount, String? newMemo,
  }) {
    if (newBankName != null) {
      bankName = newBankName;
      _autoSelectTemplate(bankName);
    }
    if (newBankAddress != null) bankAddress = newBankAddress;
    if (newDomain != null) domain = newDomain;
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

  void _autoSelectTemplate(String bank) {
    String lower = bank.toLowerCase();
    if (lower.contains('chase') || lower.contains('citi') || lower.contains('capital one') || lower.contains('us bank')) {
      selectedTemplate = checkTemplates.firstWhere((t) => t.name == 'Classic Blue');
    } else if (lower.contains('wells fargo') || lower.contains('america') || lower.contains('keybank')) {
      selectedTemplate = checkTemplates.firstWhere((t) => t.name == 'Executive Red');
    } else if (lower.contains('td bank') || lower.contains('regions') || lower.contains('m&t') || lower.contains('huntington')) {
      selectedTemplate = checkTemplates.firstWhere((t) => t.name == 'Forest Green');
    } else if (lower.contains('truist') || lower.contains('ally')) {
      selectedTemplate = checkTemplates.firstWhere((t) => t.name == 'Royal Purple');
    }
  }

  void setTemplate(CheckTemplate template) {
    selectedTemplate = template;
    notifyListeners();
  }
  
  void toggleWatermark(bool value) {
    showWatermark = value;
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
  
  Future<void> fetchLogoFromDomain(String targetDomain) async {
    if (targetDomain.isEmpty) return;
    try {
      final logoUrl = 'https://img.logo.dev/$targetDomain?token=pk_Lvrx2cdnRPyw9kxA7h79xA';
      final response = await http.get(Uri.parse(logoUrl)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        logoBytes = response.bodyBytes;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<String?> verifyRoutingNumber() async {
    if (routingNumber.length != 9) return 'Routing number must be exactly 9 digits.';
    isVerifyingRouting = true;
    notifyListeners();

    if (_myCustomBanks.containsKey(routingNumber)) {
      bankName = _myCustomBanks[routingNumber]['name'];
      bankAddress = _myCustomBanks[routingNumber]['address'];
      domain = _myCustomBanks[routingNumber]['domain'] ?? '';
      _autoSelectTemplate(bankName);
      if (domain.isNotEmpty) await fetchLogoFromDomain(domain);
      
      isVerifyingRouting = false;
      notifyListeners();
      return 'Found in your custom saved banks!'; 
    }

    if (_offlineDatabase.isEmpty) {
      try {
        final String jsonString = await rootBundle.loadString('assets/routing.json');
        _offlineDatabase = json.decode(jsonString);
      } catch (e) {
        isVerifyingRouting = false;
        notifyListeners();
        return 'Offline database file missing.';
      }
    }

    if (_offlineDatabase.containsKey(routingNumber)) {
      bankName = _offlineDatabase[routingNumber]['name'] ?? bankName;
      bankAddress = _offlineDatabase[routingNumber]['address'] ?? bankAddress;
      domain = _offlineDatabase[routingNumber]['domain'] ?? domain;
      _autoSelectTemplate(bankName);
      
      if (domain.isNotEmpty) await fetchLogoFromDomain(domain);

      isVerifyingRouting = false;
      notifyListeners();
      return null; 
    } else {
      isVerifyingRouting = false;
      notifyListeners();
      return 'Bank not found. Type it below and hit "Save Custom Bank".';
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
// SIGNATURE DRAWING PAD
// -------------------------------------------------------------
class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black87
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5 
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
  late TextEditingController _payerCtrl, _payeeCtrl, _amountCtrl, _memoCtrl, _checkNumCtrl, _dateCtrl, _bankNameCtrl, _routingCtrl, _accountCtrl, _bankAddressCtrl, _domainCtrl;

  @override
  void initState() {
    super.initState();
    final p = context.read<CheckProvider>();
    _payerCtrl = TextEditingController(text: p.payerName);
    _payeeCtrl = TextEditingController(text: p.payee);
    _amountCtrl = TextEditingController(text: p.amount.toStringAsFixed(2));
    _memoCtrl = TextEditingController(text: p.memo);
    _checkNumCtrl = TextEditingController(text: p.checkNumber);
    _dateCtrl = TextEditingController(text: p.date);
    _bankNameCtrl = TextEditingController(text: p.bankName);
    _bankAddressCtrl = TextEditingController(text: p.bankAddress);
    _routingCtrl = TextEditingController(text: p.routingNumber);
    _accountCtrl = TextEditingController(text: p.accountNumber);
    _domainCtrl = TextEditingController(text: p.domain);

    p.addListener(_syncTextControllers);
  }

  void _syncTextControllers() {
    final p = context.read<CheckProvider>();
    if (_bankNameCtrl.text != p.bankName) _bankNameCtrl.text = p.bankName;
    if (_bankAddressCtrl.text != p.bankAddress) _bankAddressCtrl.text = p.bankAddress;
    if (_domainCtrl.text != p.domain) _domainCtrl.text = p.domain;
  }

  @override
  void dispose() {
    context.read<CheckProvider>().removeListener(_syncTextControllers);
    _payerCtrl.dispose(); _payeeCtrl.dispose(); _amountCtrl.dispose(); _memoCtrl.dispose(); 
    _checkNumCtrl.dispose(); _dateCtrl.dispose(); _bankNameCtrl.dispose(); _bankAddressCtrl.dispose(); 
    _routingCtrl.dispose(); _accountCtrl.dispose(); _domainCtrl.dispose();
    super.dispose();
  }

  // MODAL DIALOG SIGNATURE POP-UP
  Future<void> _openSignaturePad(BuildContext context) async {
    List<Offset?> localSignaturePoints = [];
    final GlobalKey localSignatureKey = GlobalKey();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF5F7FA),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Draw Signature', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Please sign exactly as it should appear on the check.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 16),
                  Container(
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.blueGrey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AspectRatio(
                      aspectRatio: 3.5, 
                      child: Stack(
                        children: [
                          if (localSignaturePoints.isEmpty)
                            Center(child: Text('Sign Here', style: TextStyle(color: Colors.grey.shade300, fontSize: 18, fontStyle: FontStyle.italic))),
                          RepaintBoundary(
                            key: localSignatureKey,
                            child: Listener(
                              onPointerDown: (details) => setState(() => localSignaturePoints.add(details.localPosition)),
                              onPointerMove: (details) => setState(() => localSignaturePoints.add(details.localPosition)),
                              onPointerUp: (details) => setState(() => localSignaturePoints.add(null)),
                              child: Container(
                                color: Colors.transparent,
                                child: CustomPaint(
                                  painter: SignaturePainter(localSignaturePoints),
                                  size: Size.infinite,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => localSignaturePoints.clear()),
                  child: const Text('Clear', style: TextStyle(color: Colors.red)),
                ),
                FilledButton(
                  onPressed: () async {
                    if (localSignaturePoints.isNotEmpty) {
                      try {
                        RenderRepaintBoundary boundary = localSignatureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                        ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                        ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                        if (byteData != null && context.mounted) {
                          context.read<CheckProvider>().setSignature(byteData.buffer.asUint8List());
                        }
                      } catch (e) {
                        debugPrint("Signature capture failed: $e");
                      }
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Apply Signature'),
                ),
              ],
            );
          },
        );
      }
    );
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
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Defaults saved.')));
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

            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Check Design Template', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: checkTemplates.map((t) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(t.name, style: TextStyle(color: provider.selectedTemplate.name == t.name ? Colors.white : Colors.black87)),
                            selected: provider.selectedTemplate.name == t.name,
                            onSelected: (bool selected) {
                              if (selected) provider.setTemplate(t);
                            },
                            selectedColor: t.lineColor,
                            backgroundColor: Colors.grey.shade200,
                            checkmarkColor: Colors.white,
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Show Dynamic Logo Watermark', style: TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text('Displays a secure faint logo pattern in the background'),
                      value: provider.showWatermark,
                      onChanged: provider.toggleWatermark,
                      contentPadding: EdgeInsets.zero,
                      activeColor: provider.selectedTemplate.lineColor,
                    ),
                    const SizedBox(height: 24),

                    Text('Check Signing (Digital Ink)', style: Theme.of(context).textTheme.titleMedium),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.draw, size: 20, color: Colors.blueGrey),
                            const SizedBox(width: 8),
                            Text(provider.signatureBytes != null ? 'Signature Applied' : 'No Signature', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ]
                        ),
                        Row(
                          children: [
                            if (provider.signatureBytes != null)
                              TextButton(
                                onPressed: provider.clearSignature,
                                child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 14)),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => _openSignaturePad(context),
                              icon: const Icon(Icons.edit, size: 16),
                              label: Text(provider.signatureBytes != null ? 'Redraw' : 'Tap to Sign'),
                            ),
                          ],
                        ),
                      ],
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
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _dateCtrl,
                            decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                            onChanged: (val) => provider.updateField(newDate: val),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error), 
                                  backgroundColor: error.contains('custom saved') ? Colors.green : Colors.blueGrey,
                                )
                              );
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _domainCtrl,
                            decoration: const InputDecoration(labelText: 'Website Domain (Optional)', hintText: 'e.g. chase.com', border: OutlineInputBorder()),
                            onChanged: (val) => provider.updateField(newDomain: val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await provider.fetchLogoFromDomain(provider.domain);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logo Fetched!')));
                          },
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Fetch'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await provider.saveCurrentBankToCustomList();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Saved to your personal bank vault!'), backgroundColor: Colors.green),
                          );
                        }
                      },
                      icon: const Icon(Icons.library_add, size: 16),
                      label: const Text('Save as Custom Bank'),
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

      const double pdfMemoLineThickness = 0.6;      
      const double pdfSignatureLineThickness = 1.0; 
      
      // FIX: Shrunk signature height from 40.0 to 26.0 to prevent PDF bloating
      const double pdfSignatureImageHeight = 26.0; 
      const double pdfSignatureImageBottomOffset = 2.0; 

      final pageFormat = PdfPageFormat(6.0 * PdfPageFormat.inch, 2.75 * PdfPageFormat.inch, marginAll: 0);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: p.selectedTemplate.pdfBgGradient,
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                ),
                border: pw.Border.all(color: p.selectedTemplate.pdfLineColor, width: 0.5)
              ),
              child: pw.Stack(
                children: [
                  // DYNAMIC WATERMARK
                  if (p.logoBytes != null && p.showWatermark)
                    pw.Positioned.fill(
                      child: pw.Opacity(
                        opacity: 0.08,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(30.0),
                          child: pw.Image(pw.MemoryImage(p.logoBytes!), fit: pw.BoxFit.contain),
                        ),
                      ),
                    ),
                  
                  pw.Positioned(top: 0, left: 0, child: pw.Text(p.payerName, style: const pw.TextStyle(fontSize: 8, height: 1.2))),
                  pw.Align(
                    alignment: pw.Alignment.topCenter,
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        if (p.logoBytes != null)
                          pw.Container(
                            height: 24,
                            margin: const pw.EdgeInsets.only(bottom: 4),
                            child: pw.Image(pw.MemoryImage(p.logoBytes!)),
                          ),
                        pw.Text(p.bankName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text(p.bankAddress, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
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
                            pw.Text('Date: ', style: pw.TextStyle(fontSize: 9, color: p.selectedTemplate.pdfLineColor)),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: p.selectedTemplate.pdfLineColor, width: 0.5))),
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
                        pw.Text('PAY TO THE\nORDER OF ', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: p.selectedTemplate.pdfLineColor)),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: p.selectedTemplate.pdfLineColor, width: 0.8))),
                            child: pw.Text(p.payee, style: pw.TextStyle(font: handwritingFont, fontSize: 14)), 
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: p.selectedTemplate.pdfLineColor, width: 0.8), color: PdfColors.white),
                          child: pw.Text('\$ ${p.amount.toStringAsFixed(2)}', style: pw.TextStyle(font: handwritingFont, fontSize: 12)), 
                        ),
                      ],
                    ),
                  ),
                  pw.Positioned(
                    top: 100, left: 0, right: 0,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: p.selectedTemplate.pdfLineColor, width: 0.8))),
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(p.amountInWords, style: pw.TextStyle(font: handwritingFont, fontSize: 12)), 
                    ),
                  ),
                  
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
                                  padding: const pw.EdgeInsets.only(bottom: 2, right: 4),
                                  child: pw.Text('MEMO ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: p.selectedTemplate.pdfLineColor)),
                                ),
                                pw.Expanded(
                                  child: pw.Container(
                                    padding: const pw.EdgeInsets.only(bottom: 2),
                                    decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: p.selectedTemplate.pdfLineColor, width: pdfMemoLineThickness))),
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
                                  padding: const pw.EdgeInsets.only(bottom: 2),
                                  decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: p.selectedTemplate.pdfLineColor, width: pdfSignatureLineThickness))),
                                  alignment: pw.Alignment.bottomRight,
                                  child: pw.Text('AUTHORIZED SIGNATURE', style: pw.TextStyle(fontSize: 5, color: p.selectedTemplate.pdfLineColor)),
                                ),
                                if (p.signatureBytes != null)
                                  pw.Positioned(
                                    bottom: pdfSignatureImageBottomOffset,
                                    left: 0, right: 0,
                                    child: pw.Center(
                                      child: pw.Image(pw.MemoryImage(p.signatureBytes!), height: pdfSignatureImageHeight, fit: pw.BoxFit.contain), 
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // FIXED SCANNABLE MICR ROW
                  pw.Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: pw.Center(
                      child: pw.Text(
                        'A${p.routingNumber.replaceAll(RegExp(r'[^0-9]'), '')}A  ${p.accountNumber.replaceAll(RegExp(r'[^0-9]'), '')}C  ${p.checkNumber.replaceAll(RegExp(r'[^0-9]'), '')}',
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

    const double screenMemoLineThickness = 1.0;
    const double screenSignatureLineThickness = 1.2;
    const double screenSignatureImageHeight = 50.0; 
    const double screenSignatureImageBottomOffset = 2.0;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: p.selectedTemplate.bgGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: p.selectedTemplate.lineColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Stack(
        children: [
          // DYNAMIC WATERMARK
          if (p.logoBytes != null && p.showWatermark)
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Image.memory(p.logoBytes!, fit: BoxFit.contain),
                ),
              ),
            ),
            
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
                    Text('Date: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.selectedTemplate.lineColor)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.selectedTemplate.lineColor, width: 1.0))),
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
                Text('PAY TO THE\nORDER OF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: p.selectedTemplate.lineColor)),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.selectedTemplate.lineColor, width: 1.0))),
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(p.payee.isEmpty ? ' ' : p.payee, style: const TextStyle(fontFamily: 'Handwriting', fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: p.selectedTemplate.lineColor, width: 1.0), color: Colors.white),
                  child: Text('\$ ${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Handwriting', fontSize: 18)), 
                ),
              ],
            ),
          ),
          Positioned(
            top: 160, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.selectedTemplate.lineColor, width: 1.0))),
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(p.amountInWords, style: const TextStyle(fontFamily: 'Handwriting', fontSize: 18)),
            ),
          ),
          
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, right: 6),
                          child: Text('MEMO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: p.selectedTemplate.lineColor)),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.selectedTemplate.lineColor, width: screenMemoLineThickness))),
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
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.selectedTemplate.lineColor, width: screenSignatureLineThickness))),
                          alignment: Alignment.bottomRight,
                          child: Text('AUTHORIZED SIGNATURE', style: TextStyle(fontSize: 7, color: p.selectedTemplate.lineColor)),
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
          
          // FIXED UI MICR ROW
          Positioned(
            bottom: 2, left: 0, right: 0,
            child: Center(
              child: Text(
                'A${p.routingNumber.replaceAll(RegExp(r'[^0-9]'), '')}A  ${p.accountNumber.replaceAll(RegExp(r'[^0-9]'), '')}C  ${p.checkNumber.replaceAll(RegExp(r'[^0-9]'), '')}', 
                style: const TextStyle(fontFamily: 'MICR', fontSize: 19, letterSpacing: 2, color: Colors.black87)
              ),
            ),
          ),
        ],
      ),
    );
  }
}