import CoreServices
import Foundation
import WidgetKit

/// Rimette a posto la registrazione dell'estensione widget senza passare dal
/// Terminale: toglie la quarantena dal bundle, registra l'app in LaunchServices
/// e l'estensione in pluginkit, poi chiede a WidgetKit di ricaricare.
enum WidgetRegistration {
    static let quarantineAttribute = "com.apple.quarantine"
    static let widgetBundleID = "com.giovanni.openroutercredits.widget"

    enum Outcome {
        /// L'estensione risulta registrata.
        case registered
        /// Registrazione eseguita ma pluginkit non elenca ancora l'estensione.
        case pending
        /// La quarantena è rimasta (il sandbox impedisce di toglierla da qui).
        case quarantined(command: String)
    }

    static var bundleURL: URL { Bundle.main.bundleURL }

    static var appexURL: URL? {
        let plugIns = bundleURL.appendingPathComponent("Contents/PlugIns")
        let items = (try? FileManager.default.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil)) ?? []
        return items.first { $0.pathExtension == "appex" }
    }

    /// Comando da lanciare a mano se il sandbox non ci lascia toglierla.
    static var manualCommand: String {
        "xattr -dr \(quarantineAttribute) \"\(bundleURL.path)\""
    }

    static func run() async -> Outcome {
        await Task.detached(priority: .userInitiated) { perform() }.value
    }

    private static func perform() -> Outcome {
        removeQuarantine()

        _ = LSRegisterURL(bundleURL as CFURL, true)
        if let appex = appexURL {
            _ = shell("/usr/bin/pluginkit", ["-a", appex.path])
        }

        WidgetCenter.shared.reloadAllTimelines()

        if isQuarantined() {
            return .quarantined(command: manualCommand)
        }
        return isRegistered() ? .registered : .pending
    }

    // MARK: - Quarantena

    private static func isQuarantined() -> Bool {
        getxattr(bundleURL.path, quarantineAttribute, nil, 0, 0, XATTR_NOFOLLOW) >= 0
    }

    /// Toglie l'attributo da tutto il bundle (best effort: da sandbox può fallire).
    private static func removeQuarantine() {
        var paths = [bundleURL.path]
        if let enumerator = FileManager.default.enumerator(atPath: bundleURL.path) {
            for case let relative as String in enumerator {
                paths.append(bundleURL.appendingPathComponent(relative).path)
            }
        }
        for path in paths {
            removexattr(path, quarantineAttribute, XATTR_NOFOLLOW)
        }
    }

    // MARK: - pluginkit

    private static func isRegistered() -> Bool {
        let output = shell("/usr/bin/pluginkit", ["-m", "-p", "com.apple.widgetkit-extension", "-i", widgetBundleID]) ?? ""
        return output.contains(widgetBundleID)
    }

    private static func shell(_ launchPath: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
