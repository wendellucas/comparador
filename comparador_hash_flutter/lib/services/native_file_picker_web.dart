import 'dart:async';
import 'dart:js_interop';

import 'package:cross_file/cross_file.dart';
import 'package:cross_file_web/cross_file_web.dart';
import 'package:web/web.dart' as web;

/// Abre `<input type="file" multiple>` no navegador e encapsula os arquivos
/// selecionados como [ScopedStorageXFile] baseados em Blob/File da Web.
Future<List<XFile>> pickFiles() {
  final completer = Completer<List<XFile>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..style.display = 'none';

  web.document.body?.appendChild(input);

  Timer? cancelFallbackTimer;
  late final JSFunction onChangeJs;
  late final JSFunction onCancelJs;
  late final JSFunction onWindowFocusJs;

  void cleanup() {
    cancelFallbackTimer?.cancel();
    input.removeEventListener('change', onChangeJs);
    input.removeEventListener('cancel', onCancelJs);
    web.window.removeEventListener('focus', onWindowFocusJs);
    input.remove();
  }

  void completeWith(List<XFile> files) {
    if (completer.isCompleted) return;
    cleanup();
    completer.complete(files);
  }

  onChangeJs = ((web.Event _) {
    final fileList = input.files;
    if (fileList == null || fileList.length == 0) {
      completeWith(const []);
      return;
    }

    final selected = <XFile>[];
    for (var i = 0; i < fileList.length; i++) {
      final file = fileList.item(i);
      if (file == null) continue;
      final params = WebScopedStorageXFileCreationParams.fromBlob(file);
      selected.add(ScopedStorageXFile.fromCreationParams(params));
    }
    completeWith(selected);
  }).toJS;

  onCancelJs = ((web.Event _) {
    completeWith(const []);
  }).toJS;

  // Fallback para navegadores que não disparam o evento `cancel` ao fechar o diálogo.
  onWindowFocusJs = ((web.Event _) {
    cancelFallbackTimer?.cancel();
    cancelFallbackTimer = Timer(const Duration(milliseconds: 350), () {
      if (!completer.isCompleted) {
        final count = input.files?.length ?? 0;
        if (count == 0) {
          completeWith(const []);
        }
      }
    });
  }).toJS;

  input.addEventListener('change', onChangeJs);
  input.addEventListener('cancel', onCancelJs);
  web.window.addEventListener('focus', onWindowFocusJs);
  input.click();

  return completer.future;
}
