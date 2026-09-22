import AppKit
import Foundation
import OpenRouterCreditsCore
import OpenRouterCreditsUI
import SwiftUI
import WidgetKit

// Rende i widget in PNG, fuori da WidgetKit, per controllare la grafica.
// Uso: CreditsPreviewRender [cartella-di-uscita] [lingua]

let outputDirectory = URL(
    fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/previews",
    isDirectory: true
)
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// Con un secondo argomento si renderizza in un'altra lingua, leggendo le
// traduzioni dal repository (utile per controllare i testi).
if CommandLine.arguments.count > 2,
   let bundle = Bundle(path: "Localization/\(CommandLine.arguments[2]).lproj") {
    Strings.bundle = bundle
    UserDefaults.standard.set([CommandLine.arguments[2]], forKey: "AppleLanguages")
    print("lingua: \(CommandLine.arguments[2])")
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let now = Date()

struct Scenario {
    var name: String
    var size: CreditsWidgetModel.Size
    var style: WidgetStyleOption
    var colorScheme: ColorScheme
    var renderingMode: WidgetRenderingMode
    var snapshot: CreditsSnapshot?
    var history: [StoredState.Sample]
    var lastError: String?
    var isConfigured: Bool
    var wallpaper: Bool
}

func sampleHistory(now: Date) -> [StoredState.Sample] {
    let values: [Double] = [
        15.20, 15.05, 14.92, 14.88, 14.61, 14.40, 14.35, 14.10,
        13.95, 13.80, 13.72, 13.44, 13.30, 13.18, 12.99, 12.86,
        12.75, 12.71, 12.60, 12.58, 12.52, 12.47, 12.44, 12.40,
    ]
    return values.enumerated().map { index, value in
        StoredState.Sample(
            date: now.addingTimeInterval(-3600 * Double(values.count - 1 - index)),
            value: value
        )
    }
}

let accountSnapshot = CreditsSnapshot(
    updatedAt: now.addingTimeInterval(-90),
    accountRemaining: 12.4,
    accountTotal: 20,
    accountUsage: 7.6,
    keyLimit: 20,
    keyLimitRemaining: 12.4,
    keyUsage: 7.6,
    usageDaily: 0.42,
    usageWeekly: 1.87,
    usageMonthly: 5.31,
    keyLabel: "widget",
    isFreeTier: false,
    freeRequestsRemaining: 1000
)

let keyOnlySnapshot = CreditsSnapshot(
    updatedAt: now.addingTimeInterval(-240),
    keyLimit: 25,
    keyLimitRemaining: 18.3,
    keyUsage: 6.7,
    usageDaily: 0.18,
    usageWeekly: 0.94,
    usageMonthly: 3.02,
    keyLabel: "produzione"
)

let unlimitedSnapshot = CreditsSnapshot(
    updatedAt: now.addingTimeInterval(-600),
    keyUsage: 42.19,
    usageDaily: 1.24,
    usageWeekly: 6.55,
    usageMonthly: 19.4,
    keyLabel: "senza limite"
)

let scenarios: [Scenario] = [
    Scenario(name: "small-bianco-viola", size: .small, style: .whitePurple, colorScheme: .light, renderingMode: .fullColor,
             snapshot: accountSnapshot, history: sampleHistory(now: now), lastError: nil, isConfigured: true, wallpaper: false),
    Scenario(name: "small-nero-verde", size: .small, style: .blackGreen, colorScheme: .dark, renderingMode: .fullColor,
             snapshot: accountSnapshot, history: sampleHistory(now: now), lastError: nil, isConfigured: true, wallpaper: false),
    Scenario(name: "medium-bianco-viola", size: .medium, style: .whitePurple, colorScheme: .light, renderingMode: .fullColor,
             snapshot: accountSnapshot, history: sampleHistory(now: now), lastError: nil, isConfigured: true, wallpaper: false),
    Scenario(name: "medium-nero-verde", size: .medium, style: .blackGreen, colorScheme: .dark, renderingMode: .fullColor,
             snapshot: accountSnapshot, history: sampleHistory(now: now), lastError: nil, isConfigured: true, wallpaper: false),
    Scenario(name: "medium-solo-chiave", size: .medium, style: .whitePurple, colorScheme: .light, renderingMode: .fullColor,
             snapshot: keyOnlySnapshot, history: sampleHistory(now: now).map { StoredState.Sample(date: $0.date, value: $0.value * 1.4) },
             lastError: nil, isConfigured: true, wallpaper: false),
    Scenario(name: "small-senza-limite", size: .small, style: .blackGreen, colorScheme: .dark, renderingMode: .fullColor,
             snapshot: unlimitedSnapshot, history: [], lastError: nil, isConfigured: true, wallpaper: false),
    Scenario(name: "small-da-configurare", size: .small, style: .whitePurple, colorScheme: .light, renderingMode: .fullColor,
             snapshot: nil, history: [], lastError: nil, isConfigured: false, wallpaper: false),
    Scenario(name: "medium-errore", size: .medium, style: .whitePurple, colorScheme: .light, renderingMode: .fullColor,
             snapshot: accountSnapshot, history: sampleHistory(now: now), lastError: "Nessuna connessione", isConfigured: true, wallpaper: false),
    Scenario(name: "small-monocromatico", size: .small, style: .automatic, colorScheme: .dark, renderingMode: .vibrant,
             snapshot: accountSnapshot, history: sampleHistory(now: now), lastError: nil, isConfigured: true, wallpaper: true),
    Scenario(name: "medium-monocromatico", size: .medium, style: .automatic, colorScheme: .dark, renderingMode: .vibrant,
             snapshot: accountSnapshot, history: sampleHistory(now: now), lastError: nil, isConfigured: true, wallpaper: true),
]

func pixelSize(for size: CreditsWidgetModel.Size) -> CGSize {
    switch size {
    case .small: return CGSize(width: 170, height: 170)
    case .medium: return CGSize(width: 364, height: 170)
    }
}

let wallpaperGradient = LinearGradient(
    colors: [
        Color(red: 0.62, green: 0.70, blue: 0.82),
        Color(red: 0.72, green: 0.78, blue: 0.88),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

@MainActor
func render(_ scenario: Scenario) {
    let theme = WidgetTheme.resolved(
        style: scenario.style,
        colorScheme: scenario.colorScheme,
        renderingMode: scenario.renderingMode
    )
    let model = CreditsWidgetModel(
        size: scenario.size,
        style: scenario.style,
        snapshot: scenario.snapshot,
        history: scenario.history,
        lastError: scenario.lastError,
        isConfigured: scenario.isConfigured,
        now: now
    )

    let content = ZStack {
        if scenario.wallpaper {
            Rectangle().fill(wallpaperGradient)
        } else {
            Rectangle().fill(theme.background)
        }
        CreditsWidgetView(model: model, theme: theme)
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .environment(\.colorScheme, scenario.colorScheme)

    let size = pixelSize(for: scenario.size)
    let renderer = ImageRenderer(content: content.frame(width: size.width, height: size.height))
    renderer.scale = 2

    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("render fallito: \(scenario.name)\n".utf8))
        return
    }

    let url = outputDirectory.appendingPathComponent("\(scenario.name).png")
    try? png.write(to: url)
    print("scritto \(url.path)")
}

MainActor.assumeIsolated {
    for scenario in scenarios {
        render(scenario)
    }
}