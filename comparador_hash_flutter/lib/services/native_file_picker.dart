import 'package:cross_file/cross_file.dart';

import 'native_file_picker_web.dart'
    if (dart.library.io) 'native_file_picker_io.dart'
    as impl;

/// Fachada multiplataforma para seleção manual de um ou mais arquivos.
///
/// Delega para canais nativos em Android (SAF), iOS (`UIDocumentPickerViewController`)
/// e Windows (`IFileOpenDialog`), ou para `<input type="file" multiple>` na Web,
/// evitando conflitos de versão do `cross_file` com plugins legados.
abstract final class NativeFilePicker {
  /// Abre o seletor de arquivos do sistema permitindo múltipla seleção.
  ///
  /// Retorna uma lista vazia se o usuário cancelar a operação.
  static Future<List<XFile>> pickFiles() => impl.pickFiles();
}
