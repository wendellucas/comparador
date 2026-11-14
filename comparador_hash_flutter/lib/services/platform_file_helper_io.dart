import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../models/hash_algorithm.dart';
import 'hash_service.dart';
import 'platform_file_helper.dart';

/// Retorna `true` quando [path] representa uma pasta no sistema de arquivos local.
bool isDirectoryPath(String path) {
  return FileSystemEntity.isDirectorySync(path);
}

/// Coleta metadados básicos de [path] ou retorna `null` se não for um arquivo regular.
LocalFileMetadata? readLocalMetadata(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final stat = file.statSync();
  if (stat.type == FileSystemEntityType.directory) return null;
  return LocalFileMetadata(
    sizeBytes: stat.size,
    lastModified: stat.modified,
    directoryPath: file.parent.path,
  );
}

/// Dispara o hashing em um Isolate dedicado para evitar travar animações e UI
/// durante a leitura de arquivos grandes (ex.: imagens ISO, vídeos e instaladores).
Future<HashComputationResult> computeHashesFromLocalPath(
  String path, {
  void Function(double? progress)? onProgress,
}) async {
  final receivePort = ReceivePort();
  final completer = Completer<HashComputationResult>();

  StreamSubscription<dynamic>? subscription;
  subscription = receivePort.listen(
    (dynamic message) {
      if (message is double) {
        onProgress?.call(message);
      } else if (message is Map<String, Object?>) {
        final error = message['error'];
        if (error != null) {
          if (!completer.isCompleted) {
            completer.completeError(Exception(error.toString()));
          }
        } else {
          final rawHashes = message['hashes']! as Map<dynamic, dynamic>;
          final hashes = <HashAlgorithm, String>{
            for (final entry in rawHashes.entries)
              HashAlgorithm.values[entry.key as int]: entry.value as String,
          };
          final bytesRead = message['bytesRead']! as int;
          if (!completer.isCompleted) {
            completer.complete(
              HashComputationResult(hashes: hashes, bytesRead: bytesRead),
            );
          }
        }
        subscription?.cancel();
        receivePort.close();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      subscription?.cancel();
      receivePort.close();
    },
  );

  try {
    await Isolate.spawn<_IsolateHashRequest>(
      _hashInIsolate,
      _IsolateHashRequest(path: path, sendPort: receivePort.sendPort),
    );
  } catch (error, stackTrace) {
    await subscription.cancel();
    receivePort.close();
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }

  return completer.future;
}

class _IsolateHashRequest {
  const _IsolateHashRequest({
    required this.path,
    required this.sendPort,
  });

  final String path;
  final SendPort sendPort;
}

/// Leitura síncrona em blocos de 512 KB executada dentro do Isolate secundário.
void _hashInIsolate(_IsolateHashRequest request) {
  RandomAccessFile? raf;
  try {
    final file = File(request.path);
    final totalSize = file.lengthSync();
    raf = file.openSync(mode: FileMode.read);

    const chunkSize = 512 * 1024;
    final buffer = Uint8List(chunkSize);
    final accumulator = MultiHashAccumulator();
    var lastReportedBytes = 0;
    const reportIntervalBytes = 1024 * 1024;

    request.sendPort.send(0.0);

    while (true) {
      final bytesRead = raf.readIntoSync(buffer);
      if (bytesRead <= 0) break;

      final slice = bytesRead == buffer.length
          ? buffer
          : Uint8List.sublistView(buffer, 0, bytesRead);
      accumulator.addChunk(slice);

      if (totalSize > 0 &&
          accumulator.bytesRead - lastReportedBytes >= reportIntervalBytes) {
        lastReportedBytes = accumulator.bytesRead;
        request.sendPort.send(
          (accumulator.bytesRead / totalSize).clamp(0.0, 1.0),
        );
      }
    }

    final result = accumulator.finish();
    request.sendPort.send(1.0);
    request.sendPort.send(<String, Object?>{
      'hashes': <int, String>{
        for (final entry in result.hashes.entries) entry.key.index: entry.value,
      },
      'bytesRead': result.bytesRead,
    });
  } catch (error) {
    request.sendPort.send(<String, Object?>{'error': error.toString()});
  } finally {
    try {
      raf?.closeSync();
    } catch (_) {}
  }
}
