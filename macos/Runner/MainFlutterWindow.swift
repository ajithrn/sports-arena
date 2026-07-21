import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register platform channel for proxy configuration
    let channel = FlutterMethodChannel(
      name: "com.sportsarena/platform",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "setSystemProxy":
        guard let args = call.arguments as? [String: Any],
              let host = args["host"] as? String,
              let port = args["port"] as? Int else {
          result(false)
          return
        }
        let success = MacOSProxyHelper.setProxy(host: host, port: port)
        result(success)
      case "clearSystemProxy":
        let success = MacOSProxyHelper.clearProxy()
        result(success)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}

/// Helper to set/clear system HTTPS proxy on macOS.
/// This makes WKWebView (and all system apps) route through our local proxy.
/// Requires admin privileges — uses osascript to prompt for password.
class MacOSProxyHelper {
  /// Get the active network service name (e.g., "Wi-Fi", "Ethernet")
  static func getActiveNetworkService() -> String? {
    let task = Process()
    task.launchPath = "/usr/sbin/networksetup"
    task.arguments = ["-listnetworkserviceorder"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else { return nil }

    // Parse to find the active service
    // Try common names
    let services = ["Wi-Fi", "Ethernet", "USB 10/100/1000 LAN"]
    for service in services {
      if output.contains(service) {
        return service
      }
    }

    return "Wi-Fi" // Default fallback
  }

  static func setProxy(host: String, port: Int) -> Bool {
    guard let service = getActiveNetworkService() else { return false }

    // Set both HTTPS and HTTP proxy.
    // On modern macOS, networksetup works without admin privileges for the current user.
    let task1 = Process()
    task1.launchPath = "/usr/sbin/networksetup"
    task1.arguments = ["-setsecurewebproxy", service, host, String(port)]
    task1.launch()
    task1.waitUntilExit()

    let task2 = Process()
    task2.launchPath = "/usr/sbin/networksetup"
    task2.arguments = ["-setwebproxy", service, host, String(port)]
    task2.launch()
    task2.waitUntilExit()

    return task1.terminationStatus == 0 && task2.terminationStatus == 0
  }

  static func clearProxy() -> Bool {
    guard let service = getActiveNetworkService() else { return false }

    let task1 = Process()
    task1.launchPath = "/usr/sbin/networksetup"
    task1.arguments = ["-setsecurewebproxystate", service, "off"]
    task1.launch()
    task1.waitUntilExit()

    let task2 = Process()
    task2.launchPath = "/usr/sbin/networksetup"
    task2.arguments = ["-setwebproxystate", service, "off"]
    task2.launch()
    task2.waitUntilExit()

    return task1.terminationStatus == 0 && task2.terminationStatus == 0
  }
}
