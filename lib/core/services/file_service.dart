import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../errors/app_exception.dart';

class FileService {
  Future<String?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    return result?.files.single.path;
  }

  Future<List<String>> pickPdfs() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    return result?.paths.whereType<String>().toList() ?? const [];
  }

  Future<String?> pickDocx() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['docx'],
    );
    return result?.files.single.path;
  }

  Future<Directory> outputDirectory() async {
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(base.path, 'Smart PDF Manager'));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> uniqueOutputPath(String stem) async {
    final directory = await outputDirectory();
    final cleaned = stem
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    var path = p.join(directory.path, '$cleaned.pdf');
    var suffix = 1;
    while (File(path).existsSync()) {
      path = p.join(directory.path, '$cleaned ($suffix).pdf');
      suffix++;
    }
    return path;
  }

  Future<String> writePdf(List<int> bytes, String stem) async {
    try {
      final path = await uniqueOutputPath(stem);
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } on FileSystemException catch (error) {
      throw AppException('Could not save the PDF.', error);
    }
  }

  Future<String> rename(String sourcePath, String newName) async {
    final file = File(sourcePath);
    final name = newName.toLowerCase().endsWith('.pdf')
        ? newName
        : '$newName.pdf';
    return (await file.rename(p.join(file.parent.path, name))).path;
  }

  Future<String> copyToManagedFolder(String sourcePath) async {
    final target = await uniqueOutputPath(
      p.basenameWithoutExtension(sourcePath),
    );
    return (await File(sourcePath).copy(target)).path;
  }

  Future<String?> chooseDirectory() => FilePicker.platform.getDirectoryPath();

  Future<String> copyOrMove(
    String sourcePath,
    String destinationDirectory, {
    required bool move,
  }) async {
    final source = File(sourcePath);
    final target = p.join(destinationDirectory, p.basename(sourcePath));
    if (move) {
      return (await source.rename(target)).path;
    }
    return (await source.copy(target)).path;
  }
}
