#include <windows.h>
#include <shellapi.h>

#include <algorithm>
#include <cstdint>
#include <cwctype>
#include <filesystem>
#include <string>
#include <system_error>
#include <vector>

namespace fs = std::filesystem;

namespace {

constexpr wchar_t kProductName[] = L"Ghosium Browser";
constexpr wchar_t kSelfTestSwitch[] = L"--ghosium-self-test";
constexpr wchar_t kLowMemorySwitch[] = L"--ghosium-low-memory";
constexpr wchar_t kBalancedSwitch[] = L"--ghosium-balanced";
constexpr std::uint64_t kLowMemoryThresholdBytes = 8ULL * 1024ULL * 1024ULL * 1024ULL;

std::wstring ToLower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(), [](wchar_t ch) {
    return static_cast<wchar_t>(std::towlower(ch));
  });
  return value;
}

bool StartsWithInsensitive(const std::wstring& value, const std::wstring& prefix) {
  if (value.size() < prefix.size()) {
    return false;
  }
  return ToLower(value.substr(0, prefix.size())) == ToLower(prefix);
}

std::wstring QuoteArgument(const std::wstring& argument) {
  if (argument.empty()) {
    return L"\"\"";
  }
  if (argument.find_first_of(L" \t\n\v\"") == std::wstring::npos) {
    return argument;
  }

  std::wstring result = L"\"";
  size_t backslashes = 0;
  for (const wchar_t ch : argument) {
    if (ch == L'\\') {
      ++backslashes;
      continue;
    }
    if (ch == L'\"') {
      result.append(backslashes * 2 + 1, L'\\');
      result.push_back(L'\"');
      backslashes = 0;
      continue;
    }
    result.append(backslashes, L'\\');
    backslashes = 0;
    result.push_back(ch);
  }
  result.append(backslashes * 2, L'\\');
  result.push_back(L'\"');
  return result;
}

fs::path ExecutableDirectory() {
  std::wstring buffer(32768, L'\0');
  const DWORD length = GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
  if (length == 0 || length >= buffer.size()) {
    return {};
  }
  buffer.resize(length);
  return fs::path(buffer).parent_path();
}

fs::path LocalProfileDirectory() {
  std::wstring buffer(32768, L'\0');
  const DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", buffer.data(), static_cast<DWORD>(buffer.size()));
  if (length == 0 || length >= buffer.size()) {
    return {};
  }
  buffer.resize(length);
  return fs::path(buffer) / kProductName / L"User Data";
}

std::uint64_t TotalPhysicalMemory() {
  MEMORYSTATUSEX status{};
  status.dwLength = sizeof(status);
  if (!GlobalMemoryStatusEx(&status)) {
    return 0;
  }
  return static_cast<std::uint64_t>(status.ullTotalPhys);
}

void ShowError(const std::wstring& message) {
  MessageBoxW(nullptr, message.c_str(), kProductName, MB_OK | MB_ICONERROR | MB_SETFOREGROUND);
}

bool CoreFilesExist(const fs::path& root) {
  std::error_code error;
  return fs::is_regular_file(root / L"runtime" / L"chrome.exe", error) &&
         fs::is_regular_file(root / L"extension" / L"manifest.json", error) &&
         fs::is_regular_file(root / L"extension" / L"rules.json", error) &&
         fs::is_regular_file(root / L"extension" / L"newtab.html", error) &&
         fs::is_regular_file(root / L"extension" / L"newtab.css", error) &&
         fs::is_regular_file(root / L"search-provider" / L"manifest.json", error);
}

bool IsInternalSwitch(const std::wstring& argument) {
  const std::wstring lowered = ToLower(argument);
  return lowered == kSelfTestSwitch || lowered == kLowMemorySwitch || lowered == kBalancedSwitch;
}

bool IsProtectedArgument(const std::wstring& argument, bool* consumes_next) {
  *consumes_next = false;
  const std::wstring lowered = ToLower(argument);

  const std::vector<std::wstring> valued = {
      L"--user-data-dir", L"--load-extension", L"--disable-extensions-except",
      L"--remote-debugging-port"};
  for (const auto& option : valued) {
    if (lowered == option) {
      *consumes_next = true;
      return true;
    }
    if (StartsWithInsensitive(lowered, option + L"=")) {
      return true;
    }
  }

  return lowered == L"--enable-crash-reporter" ||
         lowered == L"--enable-sync" ||
         lowered == L"--disable-extensions" ||
         lowered == L"--no-sandbox" ||
         lowered == L"--disable-web-security" ||
         lowered == L"--ignore-certificate-errors" ||
         lowered == L"--allow-running-insecure-content" ||
         lowered == L"--remote-debugging-pipe" ||
         IsInternalSwitch(lowered);
}

void ApplyLauncherMitigations() {
  SetDllDirectoryW(L"");

  PROCESS_MITIGATION_IMAGE_LOAD_POLICY image_policy{};
  image_policy.NoRemoteImages = 1;
  image_policy.NoLowMandatoryLabelImages = 1;
  SetProcessMitigationPolicy(ProcessImageLoadPolicy, &image_policy, sizeof(image_policy));
}

}  // namespace

int APIENTRY wWinMain(HINSTANCE, HINSTANCE, LPWSTR, int) {
  ApplyLauncherMitigations();

  const fs::path root = ExecutableDirectory();
  if (root.empty() || !CoreFilesExist(root)) {
    ShowError(L"Ghosium Browser runtime nije potpun. Ponovno instalirajte službeni paket.");
    return 2;
  }

  int argc = 0;
  LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv == nullptr) {
    ShowError(L"Nije moguće pročitati naredbeni redak.");
    return 3;
  }

  bool force_low_memory = false;
  bool force_balanced = false;
  for (int index = 1; index < argc; ++index) {
    const std::wstring lowered = ToLower(argv[index]);
    if (lowered == kSelfTestSwitch) {
      LocalFree(argv);
      return 0;
    }
    if (lowered == kLowMemorySwitch) {
      force_low_memory = true;
    } else if (lowered == kBalancedSwitch) {
      force_balanced = true;
    }
  }

  const fs::path runtime_directory = root / L"runtime";
  const fs::path chromium_executable = runtime_directory / L"chrome.exe";
  const fs::path privacy_extension = root / L"extension";
  const fs::path search_extension = root / L"search-provider";
  fs::path profile_directory = LocalProfileDirectory();
  if (profile_directory.empty()) {
    profile_directory = root / L"profile";
  }

  std::error_code directory_error;
  fs::create_directories(profile_directory, directory_error);
  if (directory_error) {
    LocalFree(argv);
    ShowError(L"Nije moguće pripremiti lokalni Ghosium profil.");
    return 4;
  }

  const std::uint64_t memory_bytes = TotalPhysicalMemory();
  const bool low_memory = force_low_memory ||
                          (!force_balanced && memory_bytes != 0 && memory_bytes <= kLowMemoryThresholdBytes);

  std::vector<std::wstring> arguments;
  arguments.emplace_back(chromium_executable.wstring());
  arguments.emplace_back(L"--user-data-dir=" + profile_directory.wstring());
  arguments.emplace_back(L"--load-extension=" + privacy_extension.wstring() + L"," + search_extension.wstring());
  arguments.emplace_back(L"--disable-sync");
  arguments.emplace_back(L"--disable-breakpad");
  arguments.emplace_back(L"--disable-background-mode");
  arguments.emplace_back(L"--disable-domain-reliability");
  arguments.emplace_back(L"--no-pings");
  arguments.emplace_back(L"--no-first-run");
  arguments.emplace_back(L"--no-default-browser-check");

  if (low_memory) {
    arguments.emplace_back(L"--renderer-process-limit=6");
    arguments.emplace_back(L"--disk-cache-size=134217728");
  }

  for (int index = 1; index < argc; ++index) {
    bool consumes_next = false;
    if (IsProtectedArgument(argv[index], &consumes_next)) {
      if (consumes_next && index + 1 < argc) {
        ++index;
      }
      continue;
    }
    arguments.emplace_back(argv[index]);
  }
  LocalFree(argv);

  std::wstring command_line;
  for (size_t index = 0; index < arguments.size(); ++index) {
    if (index != 0) {
      command_line.push_back(L' ');
    }
    command_line.append(QuoteArgument(arguments[index]));
  }

  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  PROCESS_INFORMATION process_info{};

  const BOOL created = CreateProcessW(
      chromium_executable.c_str(), command_line.data(), nullptr, nullptr, FALSE,
      CREATE_UNICODE_ENVIRONMENT, nullptr, runtime_directory.c_str(),
      &startup_info, &process_info);

  if (!created) {
    const DWORD error = GetLastError();
    ShowError(L"Chromium runtime se nije mogao pokrenuti. Windows kod greške: " + std::to_wstring(error));
    return 5;
  }

  CloseHandle(process_info.hThread);
  CloseHandle(process_info.hProcess);
  return 0;
}
