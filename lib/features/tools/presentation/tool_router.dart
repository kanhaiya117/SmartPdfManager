import 'package:flutter/material.dart';

import '../../dashboard/domain/dashboard_tool.dart';
import 'creation_tools_screen.dart';
import 'ocr_screen.dart';
import 'scanner_screen.dart';
import 'signature_screen.dart';
import 'utility_tool_screen.dart';

class ToolRouter extends StatelessWidget {
  const ToolRouter({required this.tool, super.key});

  final DashboardTool tool;

  @override
  Widget build(BuildContext context) {
    return switch (tool) {
      DashboardTool.scanner => const ScannerScreen(),
      DashboardTool.sign => const SignatureScreen(),
      DashboardTool.textToPdf => const TextToPdfScreen(),
      DashboardTool.imageToPdf => const ImageToPdfScreen(),
      DashboardTool.docxToPdf => const DocxToPdfScreen(),
      DashboardTool.ocr => const OcrScreen(),
      _ => UtilityToolScreen(tool: tool),
    };
  }
}
