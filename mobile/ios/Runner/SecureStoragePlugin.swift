import Flutter
import UIKit
import Security

public class SecureStoragePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.vms.app/secure_storage",
            binaryMessenger: registrar.messenger()
        )
        let instance = SecureStoragePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "write":
            guard let key = args?["key"] as? String, let value = args?["value"] as? String else {
                result(FlutterError(code: "INVALID", message: "key and value required", details: nil))
                return
            }
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: "com.vms.app",
                kSecAttrAccount: key,
                kSecValueData: Data(value.utf8),
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ]
            SecItemDelete(query as CFDictionary) // Delete any existing item first
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                result(FlutterError(code: "KEYCHAIN_ERROR", message: "Status code: \(status)", details: nil))
                return
            }
            result(nil)

        case "read":
            guard let key = args?["key"] as? String else {
                result(FlutterError(code: "INVALID", message: "key required", details: nil))
                return
            }
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: "com.vms.app",
                kSecAttrAccount: key,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne,
            ]
            var ref: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &ref)
            if status == errSecSuccess, let data = ref as? Data {
                result(String(data: data, encoding: .utf8))
            } else {
                result(nil)
            }

        case "delete":
            guard let key = args?["key"] as? String else {
                result(FlutterError(code: "INVALID", message: "key required", details: nil))
                return
            }
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: "com.vms.app",
                kSecAttrAccount: key,
            ]
            SecItemDelete(query as CFDictionary)
            result(nil)

        case "clear":
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: "com.vms.app",
            ]
            SecItemDelete(query as CFDictionary)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
