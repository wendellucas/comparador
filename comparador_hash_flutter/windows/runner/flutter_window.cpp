#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <shobjidl.h>
#include <wrl/client.h>

#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Converte strings UTF-16 do Win32 para UTF-8 usado pelos canais Flutter.
std::string WideToUtf8(const wchar_t* wide) {
  if (!wide || *wide == L'\0') {
    return {};
  }
  const int required = WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1, nullptr, 0, nullptr, nullptr);
  if (required <= 1) {
    return {};
  }
  std::string utf8(static_cast<size_t>(required - 1), '\0');
  WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1, utf8.data(),
                      required, nullptr, nullptr);
  return utf8;
}

// Abre o diálogo moderno IFileOpenDialog permitindo selecionar 1 ou mais arquivos locais.
bool PickMultipleFilesWithDialog(HWND owner, std::vector<std::string>* out_paths,
                                 std::string* out_error) {
  Microsoft::WRL::ComPtr<IFileOpenDialog> dialog;
  HRESULT hr = CoCreateInstance(CLSID_FileOpenDialog, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog));
  if (FAILED(hr) || !dialog) {
    *out_error = "Falha ao inicializar o diálogo de arquivos do Windows.";
    return false;
  }

  DWORD options = 0;
  if (SUCCEEDED(dialog->GetOptions(&options))) {
    dialog->SetOptions(options | FOS_ALLOWMULTISELECT | FOS_FILEMUSTEXIST |
                       FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST);
  }
  dialog->SetTitle(L"Selecionar arquivo(s) para comparação");

  hr = dialog->Show(owner);
  if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    return true;
  }
  if (FAILED(hr)) {
    *out_error = "Erro ao exibir a janela de seleção de arquivos.";
    return false;
  }

  Microsoft::WRL::ComPtr<IShellItemArray> items;
  hr = dialog->GetResults(&items);
  if (FAILED(hr) || !items) {
    *out_error = "Não foi possível ler os arquivos selecionados.";
    return false;
  }

  DWORD count = 0;
  items->GetCount(&count);
  for (DWORD i = 0; i < count; ++i) {
    Microsoft::WRL::ComPtr<IShellItem> item;
    if (SUCCEEDED(items->GetItemAt(i, &item)) && item) {
      PWSTR path_raw = nullptr;
      if (SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH, &path_raw)) &&
          path_raw) {
        std::string utf8_path = WideToUtf8(path_raw);
        CoTaskMemFree(path_raw);
        if (!utf8_path.empty()) {
          out_paths->push_back(std::move(utf8_path));
        }
      }
    }
  }
  return true;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetupNativeChannels();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::SetupNativeChannels() {
  file_picker_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.comparadorhash/file_picker",
          &flutter::StandardMethodCodec::GetInstance());

  file_picker_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "pickFiles") {
          std::vector<std::string> paths;
          std::string error;
          HWND owner = flutter_controller_ && flutter_controller_->view()
                           ? flutter_controller_->view()->GetNativeWindow()
                           : GetHandle();
          if (!PickMultipleFilesWithDialog(owner, &paths, &error)) {
            result->Error("PICK_FAILED", error);
            return;
          }
          flutter::EncodableList encoded;
          encoded.reserve(paths.size());
          for (const auto& p : paths) {
            encoded.emplace_back(p);
          }
          result->Success(flutter::EncodableValue(encoded));
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::OnDestroy() {
  file_picker_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
