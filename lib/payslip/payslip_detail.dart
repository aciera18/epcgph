import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class PayslipPage extends StatefulWidget {
  final String? html;
  final List<Uint8List>? images;

  const PayslipPage({super.key, this.html, this.images});

  @override
  State<PayslipPage> createState() => _PayslipPageState();
}

class _PayslipPageState extends State<PayslipPage> {
  late final WebViewController _controller;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.html != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadHtmlString(widget.html!);
    }
  }

  /// Print HTML or image-based payslip
  Future<void> _printPdf() async {
    setState(() => isProcessing = true);
    try {
      if (widget.html != null) {
        // Print directly from HTML
        await Printing.layoutPdf(
          onLayout: (format) async {
            return await Printing.convertHtml(
              format: format,
              html: widget.html!,
            );
          },
        );
      } else if (widget.images != null && widget.images!.isNotEmpty) {
        // Print from images
        final pdf = pw.Document();
        for (final img in widget.images!) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (context) => pw.Center(
                child: pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.contain),
              ),
            ),
          );
        }
        await Printing.layoutPdf(onLayout: (format) => pdf.save());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No content to print')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing PDF: $e')),
      );
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payslip'),
        actions: [
          // 🖨️ Floating print button in AppBar
          IconButton(
            tooltip: 'Print Payslip',
            onPressed: isProcessing ? null : _printPdf,
            icon: const Icon(Icons.print),
          ),
        ],
      ),
      body: widget.html != null
          ? WebViewWidget(controller: _controller)
          : Center(
        child: Text(
          'No payslip to display',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
