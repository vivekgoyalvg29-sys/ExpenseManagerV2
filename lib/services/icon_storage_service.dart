import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class IconStorageService {
  static Future<String?> pickAndStoreIconImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    final sourcePath = picked.path;
    if (sourcePath == null || sourcePath.isEmpty) return null;

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return null;

    final directory = await getApplicationDocumentsDirectory();
    final iconsDirectory = Directory(p.join(directory.path, 'custom_icons'));
    if (!await iconsDirectory.exists()) {
      await iconsDirectory.create(recursive: true);
    }

    final extension = p.extension(sourcePath).isEmpty ? '.png' : p.extension(sourcePath);
    final targetPath = p.join(
      iconsDirectory.path,
      'icon_${DateTime.now().microsecondsSinceEpoch}$extension',
    );

    final copied = await sourceFile.copy(targetPath);
    return copied.path;
  }
}
