import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('com.comparadorhash/file_picker');

/// Abre o seletor nativo via MethodChannel em Android, iOS e Windows.
Future<List<XFile>> pickFiles() async {
  final results = await _channel.invokeListMethod<String>('pickFiles');
  if (results == null || results.isEmpty) {
    return const [];
  }

  return results
      .where((entry) => entry.isNotEmpty)
      .map((entry) {
        // No Android, o SAF retorna URIs `content://`, que devem ser lidas via ScopedStorageXFile.
        if (Platform.isAndroid || entry.startsWith('content://')) {
          return XFile.scopedStorage(uri: entry);
        }
        return XFile.fileSystem(path: entry);
      })
      .toList(growable: false);
}
