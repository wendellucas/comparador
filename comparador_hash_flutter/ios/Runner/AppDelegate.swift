import Flutter
import UIKit
import UniformTypeIdentifiers

/// AppDelegate responsável por registrar plugins e expor o seletor nativo
/// de arquivos do iOS/iPadOS via MethodChannel usando UIDocumentPickerViewController.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private let filePickerChannelName = "com.comparadorhash/file_picker"
  private var pendingPickerResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ComparadorFilePicker") {
      let channel = FlutterMethodChannel(
        name: filePickerChannelName,
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        if call.method == "pickFiles" {
          self.presentDocumentPicker(result: result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  private func presentDocumentPicker(result: @escaping FlutterResult) {
    if pendingPickerResult != nil {
      result(FlutterError(
        code: "PICKER_BUSY",
        message: "Já existe uma seleção de arquivos em andamento.",
        details: nil
      ))
      return
    }

    guard let presenter = topMostViewController() else {
      result(FlutterError(
        code: "NO_VIEW_CONTROLLER",
        message: "Não foi possível localizar a janela ativa para exibir o seletor.",
        details: nil
      ))
      return
    }

    pendingPickerResult = result

    // asCopy: true garante cópia local temporária legível sem necessidade de security-scoped bookmark adicional.
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
    picker.allowsMultipleSelection = true
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  private func topMostViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let keyWindow = scenes
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow }) ?? scenes.flatMap { $0.windows }.first

    var controller = keyWindow?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    let result = pendingPickerResult
    pendingPickerResult = nil
    result?(urls.map { $0.path })
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = pendingPickerResult
    pendingPickerResult = nil
    result?([])
  }
}
