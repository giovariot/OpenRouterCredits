// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenRouterCredits",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenRouterCredits", targets: ["OpenRouterCreditsApp"]),
        .executable(name: "OpenRouterCreditsWidget", targets: ["OpenRouterCreditsWidget"]),
        .executable(name: "CreditsPreviewRender", targets: ["CreditsPreviewRender"]),
        .executable(name: "CreditsIconGen", targets: ["CreditsIconGen"]),
    ],
    targets: [
        .target(
            name: "OpenRouterCreditsCore"
        ),
        .target(
            name: "OpenRouterCreditsUI",
            dependencies: ["OpenRouterCreditsCore"]
        ),
        .executableTarget(
            name: "OpenRouterCreditsWidget",
            dependencies: ["OpenRouterCreditsCore", "OpenRouterCreditsUI"],
            // Xcode collega ogni app extension con `LD_ENTRY_POINT = _NSExtensionMain`
            // (vedi DarwinProductTypes.xcspec). Senza questo flag il binario
            // partirebbe da `main` e il sistema non lo caricherebbe come estensione.
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"])
            ]
        ),
        .executableTarget(
            name: "OpenRouterCreditsApp",
            dependencies: ["OpenRouterCreditsCore", "OpenRouterCreditsUI"]
        ),
        .executableTarget(
            name: "CreditsPreviewRender",
            dependencies: ["OpenRouterCreditsCore", "OpenRouterCreditsUI"]
        ),
        .executableTarget(
            name: "CreditsIconGen",
            dependencies: ["OpenRouterCreditsCore", "OpenRouterCreditsUI"]
        ),
        .testTarget(
            name: "OpenRouterCreditsCoreTests",
            dependencies: ["OpenRouterCreditsCore", "OpenRouterCreditsUI"]
        ),
    ]
)
