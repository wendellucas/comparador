import 'hash_service.dart';
import 'platform_file_helper.dart';

/// Implementação Web de fallback: o navegador não expõe acesso direto por caminho local.
bool isDirectoryPath(String path) => false;

LocalFileMetadata? readLocalMetadata(String path) => null;

Future<HashComputationResult> computeHashesFromLocalPath(
  String path, {
  void Function(double? progress)? onProgress,
}) {
  throw UnsupportedError('Leitura direta de caminho local não é suportada na Web.');
}
