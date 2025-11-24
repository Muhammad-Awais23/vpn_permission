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
            // CHANGED: Just check, don't create
            guard let args = call.arguments as? [String: Any],
                  let providerId = args["providerBundleIdentifier"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing providerBundleIdentifier", details: nil))
                return
            }
            requestedProviderId = providerId
            // Return false to indicate permission needs to be granted through actual VPN connection
            checkVpnPermission(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // --------------------------------------------------------
    // CHECK PERMISSION - Only checks, never creates
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
}