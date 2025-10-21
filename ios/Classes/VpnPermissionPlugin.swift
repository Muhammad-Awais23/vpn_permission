import Flutter
import NetworkExtension
import Security

public class VpnPermissionPlugin: NSObject, FlutterPlugin {
    private var vpnManagers: [NETunnelProviderManager] = []
    private var pendingResult: FlutterResult?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "vpn_permission", binaryMessenger: registrar.messenger())
        let instance = VpnPermissionPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkVpnPermission":
            checkVpnPermission(result: result)
        case "requestVpnPermission":
            guard let args = call.arguments as? [String: Any],
                  let providerBundleIdentifier = args["providerBundleIdentifier"] as? String,
                  let localizedDescription = args["localizedDescription"] as? String,
                  let groupIdentifier = args["groupIdentifier"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Missing required parameters",
                    details: ["Required": "providerBundleIdentifier, localizedDescription, groupIdentifier"]
                ))
                return
            }
            pendingResult = result
            requestVpnPermission(
                providerBundleIdentifier: providerBundleIdentifier,
                localizedDescription: localizedDescription,
                groupIdentifier: groupIdentifier
            )
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func checkVpnPermission(result: @escaping FlutterResult) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            guard error == nil else {
                result(FlutterError(code: "LOAD_ERROR", message: error?.localizedDescription, details: nil))
                return
            }
            
            // Store loaded managers to reuse them later
            self?.vpnManagers = managers ?? []
            
            let isConnected = managers?.contains(where: { $0.connection.status == .connected }) ?? false
            result(isConnected)
        }
    }
    
    private func requestVpnPermission(
        providerBundleIdentifier: String,
        localizedDescription: String,
        groupIdentifier: String
    ) {
        // First, load existing configurations
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            guard let self = self else { return }
            
            if let error = error {
                self.pendingResult?(FlutterError(
                    code: "LOAD_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
                return
            }
            
            // Check if a configuration already exists for this provider
            let existingManager = managers?.first { manager in
                if let proto = manager.protocolConfiguration as? NETunnelProviderProtocol {
                    return proto.providerBundleIdentifier == providerBundleIdentifier
                }
                return false
            }
            
            // Use existing manager or create new one
            let manager = existingManager ?? NETunnelProviderManager()
            let tunnelProtocol = NETunnelProviderProtocol()
            
            // Configure tunnel protocol
            tunnelProtocol.providerBundleIdentifier = providerBundleIdentifier
            tunnelProtocol.serverAddress = "" // Required but can be empty
            tunnelProtocol.providerConfiguration = [
                "groupIdentifier": groupIdentifier,
                "localizedDescription": localizedDescription
            ]
            
            manager.protocolConfiguration = tunnelProtocol
            manager.localizedDescription = localizedDescription
            manager.isEnabled = true
            
            // Save configuration
            manager.saveToPreferences { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.pendingResult?(FlutterError(
                        code: "SAVE_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    // Reload to ensure it's persisted
                    manager.loadFromPreferences { error in
                        if error == nil {
                            // Update stored managers
                            if !self.vpnManagers.contains(where: { $0 === manager }) {
                                self.vpnManagers.append(manager)
                            }
                            self.pendingResult?(true)
                        } else {
                            self.pendingResult?(FlutterError(
                                code: "LOAD_ERROR",
                                message: error?.localizedDescription,
                                details: nil
                            ))
                        }
                    }
                }
            }
        }
    }
}