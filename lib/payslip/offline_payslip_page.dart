import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class OfflinePayslipPage extends StatelessWidget {
  final String html;
  const OfflinePayslipPage({super.key, required this.html});

  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(html);

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Payslip')),
      body: WebViewWidget(controller: controller),
    );
  }
}
