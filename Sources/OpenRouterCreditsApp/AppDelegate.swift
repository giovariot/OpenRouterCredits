import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// L'app serve a configurare le chiavi e a mostrare lo stato: quando si
    /// chiude la finestra si chiude anche lei. Il widget continua a
    /// funzionare da solo, perché aggiorna i dati nella propria timeline.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}