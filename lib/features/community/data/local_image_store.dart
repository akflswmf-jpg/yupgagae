import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalImageStore {
  static Future<String> persistImageFromPath(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw Exception('이미지 파일이 존재하지 않습니다: $sourcePath');
    }

    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'community_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final dstPath = p.join(imagesDir.path, fileName);

    await src.copy(dstPath);
    return dstPath;
  }
}