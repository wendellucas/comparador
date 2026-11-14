import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';

import '../models/compared_file.dart';
import 'hash_service.dart';
import 'platform_file_helper.dart';

/// Exceção amigável lançada quando o usuário arrasta uma pasta ou item inválido.
class InvalidFileDropException implements Exception {
  const InvalidFileDropException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Responsável por carregar metadados e calcular hashes a partir de [XFile]
/// (seleção manual) ou [DropItem] (`desktop_drop`).
abstract final class FileLoader {
  /// Carrega e calcula os hashes de um [XFile] vindo do seletor de arquivos
  /// ou de uma atualização por caminho local.
  static Future<ComparedFile> loadFromXFile(
    XFile xFile, {
    String? preferredName,
    String? knownLocalPath,
    bool preserveSourceReference = true,
    void Function(String? fileName)? onFileNameResolved,
    void Function(double? progress)? onProgress,
  }) async {
    final resolvedLocalPath = knownLocalPath ??
        (xFile is FileSystemXFile ? xFile.path : null);

    // Garante rejeição explícita caso um caminho local aponte para uma pasta.
    if (!kIsWeb &&
        resolvedLocalPath != null &&
        resolvedLocalPath.isNotEmpty &&
        isDirectoryPath(resolvedLocalPath)) {
      throw InvalidFileDropException(
        'O item selecionado não é um arquivo válido (pastas não podem ser comparadas diretamente):\n$resolvedLocalPath',
      );
    }

    String? resolvedName = preferredName;
    if (resolvedName == null || resolvedName.trim().isEmpty) {
      try {
        resolvedName = await xFile.name();
      } catch (_) {
        resolvedName = null;
      }
    }
    if (resolvedName == null || resolvedName.trim().isEmpty) {
      resolvedName = (resolvedLocalPath != null && resolvedLocalPath.isNotEmpty)
          ? _extractFileName(resolvedLocalPath)
          : _extractFileName(xFile.uri);
    }
    onFileNameResolved?.call(resolvedName);

    // Caminho otimizado para IO local: processa em Isolate separado via RandomAccessFile.
    if (!kIsWeb &&
        resolvedLocalPath != null &&
        resolvedLocalPath.isNotEmpty) {
      final metadata = readLocalMetadata(resolvedLocalPath);
      if (metadata != null) {
        final result = await computeHashesFromLocalPath(
          resolvedLocalPath,
          onProgress: onProgress,
        );
        return ComparedFile(
          name: resolvedName,
          localPath: resolvedLocalPath,
          directoryLabel: metadata.directoryPath,
          sizeBytes: result.bytesRead,
          lastModified: metadata.lastModified,
          hashes: result.hashes,
          sourceXFile: preserveSourceReference ? xFile : null,
        );
      }
    }

    // Fluxo universal (Web Blob, Android SAF `content://` e provedores virtuais).
    int? totalBytes;
    try {
      totalBytes = await xFile.length();
    } catch (_) {
      totalBytes = null;
    }

    DateTime? lastModified;
    try {
      final modified = await xFile.lastModified();
      if (modified != null && modified.millisecondsSinceEpoch > 0) {
        lastModified = modified;
      }
    } catch (_) {
      lastModified = null;
    }

    final result = await computeAllHashesFromStream(
      xFile.openRead(),
      totalBytes: totalBytes,
      onProgress: onProgress,
    );

    return ComparedFile(
      name: resolvedName.isNotEmpty ? resolvedName : 'arquivo',
      localPath: (!kIsWeb &&
              resolvedLocalPath != null &&
              resolvedLocalPath.isNotEmpty)
          ? resolvedLocalPath
          : null,
      directoryLabel: _buildSourceLabel(xFile.uri),
      sizeBytes: result.bytesRead,
      lastModified: lastModified,
      hashes: result.hashes,
      sourceXFile: preserveSourceReference ? xFile : null,
    );
  }

  /// Processa um [DropItem] recebido dentro de `DropTarget.onDrop`.
  ///
  /// IMPORTANTE: deve ser aguardado antes de `onDrop` retornar, pois o SO libera
  /// permissões temporárias e arquivos prometidos assim que o callback termina.
  static Future<ComparedFile> loadFromDropItem(
    DropItem item, {
    void Function(String? fileName)? onFileNameResolved,
    void Function(double? progress)? onProgress,
  }) async {
    switch (item) {
      case DropDirectoryItem():
        throw InvalidFileDropException(
          'Pastas não podem ser comparadas diretamente:\n${item.name}',
        );
      case DropStringItem():
        throw const InvalidFileDropException(
          'O item arrastado não é um arquivo válido (texto ou link não podem ser comparados).',
        );
      case DropFileItem():
        final hasLocalPath =
            !kIsWeb && item.localPath != null && item.localPath!.isNotEmpty;
        final needsMacBookmark =
            item.appleBookmark != null &&
            !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.macOS;

        var accessedBookmark = false;
        try {
          if (needsMacBookmark) {
            accessedBookmark = await DesktopDrop.instance
                .startAccessingSecurityScopedResource(
                  bookmark: item.appleBookmark!,
                );
            if (!accessedBookmark) {
              throw const InvalidFileDropException(
                'Sem permissão do macOS para acessar o arquivo arrastado.',
              );
            }
          }

          onFileNameResolved?.call(item.name);
          // Só mantém `sourceXFile` se houver caminho local estável; URIs efêmeras
          // de drag no Android/Web expiram ao término do `onDrop`.
          return await loadFromXFile(
            item.file,
            preferredName: item.name,
            knownLocalPath: hasLocalPath ? item.localPath : null,
            preserveSourceReference: hasLocalPath,
            onFileNameResolved: onFileNameResolved,
            onProgress: onProgress,
          );
        } finally {
          if (accessedBookmark && item.appleBookmark != null) {
            try {
              await DesktopDrop.instance.stopAccessingSecurityScopedResource(
                bookmark: item.appleBookmark!,
              );
            } catch (_) {}
          }
        }
    }
  }

  static String _buildSourceLabel(String uri) {
    if (kIsWeb) {
      return 'Arquivo selecionado no navegador';
    }
    if (uri.startsWith('content://')) {
      return 'Armazenamento do dispositivo (Android)';
    }
    return 'Arquivo selecionado';
  }

  static String _extractFileName(String raw) {
    final cleaned = raw.split('?').first;
    final parts = cleaned.split(RegExp(r'[/\\]'));
    for (var i = parts.length - 1; i >= 0; i--) {
      if (parts[i].isNotEmpty) {
        return Uri.decodeComponent(parts[i]);
      }
    }
    return 'arquivo';
  }
}
