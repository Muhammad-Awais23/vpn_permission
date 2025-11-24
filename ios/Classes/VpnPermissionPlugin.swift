import Flutter
import NetworkExtension
import Security

public class VpnPermissionPlugin: NSObject, FlutterPlugin {
    private var pendingResult: FlutterResult?
    private var requestedProviderId: String = ""

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "vpn_permission", binaryMessenger: registrar.messenger())
        let instance = VpnPermissionPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "checkVpnPermission":
            guard let args = call.arguments as? [String: Any],
                  let providerId = args["providerBundleIdentifier"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing providerBundleIdentifier", details: nil))
                return
            }
            requestedProviderId = providerId
            checkVpnPermission(result: result)

        case "requestVpnPermission":
            guard let args = call.arguments as? [String: Any],
                  let providerId = args["providerBundleIdentifier"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing providerBundleIdentifier", details: nil))
                return
            }
            requestedProviderId = providerId
            pendingResult = result
            requestVpnPermission()

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // --------------------------------------------------------
    // CHECK PERMISSION
    // --------------------------------------------------------
    private func checkVpnPermission(result: @escaping FlutterResult) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                result(FlutterError(code: "LOAD_ERROR", message: error.localizedDescription, details: nil))
                return
            }

            let exists = managers?.contains(where: { manager in
                (manager.protocolConfiguration as? NETunnelProviderProtocol)?
                    .providerBundleIdentifier == self.requestedProviderId
            }) ?? false

            result(exists)
        }
    }

    // --------------------------------------------------------
    // REQUEST PERMISSION (NO DUPLICATE PROFILES)
    // --------------------------------------------------------
    private func requestVpnPermission() {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                self.pendingResult?(FlutterError(code: "LOAD_ERROR", message: error.localizedDescription, details: nil))
                return
            }

            // If profile already exists → return success
            if let _ = managers?.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                    .providerBundleIdentifier == self.requestedProviderId
            }) {
                self.pendingResult?(true)
                return
            }

            //Create minimal profile ONLY if none exists
            let manager = NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = self.requestedProviderId
            proto.serverAddress = "127.0.0.1"

            manager.protocolConfiguration = proto
            manager.localizedDescription = "VPN"
            manager.isEnabled = true

            manager.saveToPreferences { saveError in
                if let saveError = saveError {
                    self.pendingResult?(FlutterError(code: "SAVE_ERROR", message: saveError.localizedDescription, details: nil))
                    return
                }

                manager.loadFromPreferences { loadError in
                    if let loadError = loadError {
                        self.pendingResult?(FlutterError(code: "LOAD_ERROR", message: loadError.localizedDescription, details: nil))
                    } else {
                        self.pendingResult?(true)
                    }
                }
            }
        }
    }
}
