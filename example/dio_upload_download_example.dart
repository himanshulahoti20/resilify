// Example: file upload and download with progress callbacks via Dio.
//
// Run with: `dart run example/dio_upload_download_example.dart`

import 'dart:io';

import 'package:resilify/resilify_dio.dart';

Future<void> main() async {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
  final api = DioResultHandler(dio);

  await _upload(api);
  await _download(api);
}

Future<void> _upload(DioResultHandler api) async {
  final tmp = File('${Directory.systemTemp.path}/sample.txt')
    ..writeAsStringSync('hello world');

  final formData = FormData.fromMap({
    'description': 'a tiny upload',
    'file': await MultipartFile.fromFile(tmp.path, filename: 'sample.txt'),
  });

  final result = await api.upload<Map<String, dynamic>>(
    '/uploads',
    formData: formData,
    onSendProgress: (sent, total) {
      if (total > 0) {
        final pct = (sent / total * 100).toStringAsFixed(1);
        stdout.write('\r↑ $pct%');
      }
    },
    parser: (json) => json! as Map<String, dynamic>,
  );

  stdout.writeln();
  result.when(
    success: (json) => print('upload ok: $json'),
    error: (failure) => print('upload failed: $failure'),
  );
}

Future<void> _download(DioResultHandler api) async {
  final savePath = '${Directory.systemTemp.path}/manual.pdf';

  final result = await api.download(
    '/files/manual.pdf',
    savePath,
    onReceiveProgress: (received, total) {
      if (total > 0) {
        final pct = (received / total * 100).toStringAsFixed(1);
        stdout.write('\r↓ $pct%');
      }
    },
  );

  stdout.writeln();
  result.when(
    success: (_) => print('downloaded to $savePath'),
    error: (failure) => print('download failed: $failure'),
  );
}
