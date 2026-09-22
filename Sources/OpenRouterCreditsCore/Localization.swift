import Foundation

/// Accesso alle traduzioni dell'app e del widget.
///
/// Le chiavi sono le frasi in italiano (lingua base): se manca una traduzione
/// viene mostrata la chiave stessa, quindi l'interfaccia resta leggibile.
/// Le traduzioni stanno in `Localization/<lingua>.lproj/Localizable.strings` e
/// vengono copiate dentro l'app e l'estensione in fase di build.
public enum Strings {
    /// Bundle in cui cercare le traduzioni. I tool di anteprima lo cambiano
    /// per rendere i widget in un'altra lingua.
    public static var bundle: Bundle = .main

    public static func text(_ key: String, _ arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        guard !arguments.isEmpty else { return format }
        return String(format: format, arguments: arguments)
    }
}
