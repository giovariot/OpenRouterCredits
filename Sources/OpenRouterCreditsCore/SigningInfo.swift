import Foundation
import Security

/// Legge gli entitlement della firma del processo corrente.
///
/// Serve a scoprire l'app group senza duplicare il valore nel codice: il
/// gruppo viene deciso in fase di firma (`scripts/build-app.sh`) e qui si
/// legge da lì. Se il binario non ha entitlement (build ad-hoc o tool da
/// riga di comando) il risultato è `nil`.
enum SigningInfo {
    static let applicationGroupIdentifier: String? = {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let dictionary = information as? [String: Any],
              let entitlements = dictionary[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String] else {
            return nil
        }
        return groups.first
    }()
}