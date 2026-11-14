import 'hash_service.dart';
import 'platform_file_helper_web.dart'
    if (dart.library.io) 'platform_file_helper_io.dart'
    as impl;

/// Metadados de arquivo obtidos diretamente do sistema de arquivos local (IO).
class LocalFileMetadata {
  const LocalFileMetadata({
    required this.sizeBytes,
    required this.lastModified,
    required this.directoryPath,
  });

  final int sizeBytes;
  final DateTime lastModified;
  final String directoryPath;
}

/// Verifica se o caminho informado aponta para um diretório local.
bool isDirectoryPath(String path) => impl.isDirectoryPath(path);

/// Lê tamanho, data de modificação e pasta pai de um arquivo local quando acessível.
LocalFileMetadata? readLocalMetadata(String path) =>
    impl.readLocalMetadata(path);

/// Calcula os hashes em um Isolate separado nas plataformas com `dart:io`.
Future<HashComputationResult> computeHashesFromLocalPath(
  String path, {
  void Function(double? progress)? onProgress,
}) => impl.computeHashesFromLocalPath(path, onProgress: onProgress);
