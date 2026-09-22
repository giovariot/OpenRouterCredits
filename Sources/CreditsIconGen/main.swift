import CoreGraphics
import Foundation
import ImageIO
import OpenRouterCreditsUI
import UniformTypeIdentifiers

// Genera il set di icone dell'app (badge OpenRouter) in formato .iconset.
// Uso: CreditsIconGen [cartella-di-uscita]

let outputDirectory = URL(
    fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build",
    isDirectory: true
)
let iconset = outputDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func renderIcon(pixels: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    let size = CGFloat(pixels)
    let inset = size * 0.085
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let corner = rect.width * 0.225
    let squircle = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    context.saveGState()
    context.addPath(squircle)
    context.clip()
    let colors = [
        CGColor(red: 0.52, green: 0.20, blue: 0.98, alpha: 1),
        CGColor(red: 0.41, green: 0.09, blue: 0.85, alpha: 1),
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )
    }
    context.restoreGState()

    let box = OpenRouterGlyph.viewBox
    let targetWidth = rect.width * 0.58
    let scale = targetWidth / box.width
    let glyphTransform = CGAffineTransform(
        a: scale,
        b: 0,
        c: 0,
        d: scale,
        tx: rect.midX - box.midX * scale,
        ty: rect.midY - box.midY * scale
    )
    var mutableTransform = glyphTransform
    if let glyph = OpenRouterGlyph.cgPath.copy(using: &mutableTransform) {
        context.addPath(glyph)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fillPath(using: .evenOdd)
    }

    return context.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        FileHandle.standardError.write(Data("impossibile creare \(url.path)\n".utf8))
        return
    }
    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) {
        FileHandle.standardError.write(Data("impossibile scrivere \(url.path)\n".utf8))
    }
}

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for variant in variants {
    guard let image = renderIcon(pixels: variant.pixels) else {
        FileHandle.standardError.write(Data("render fallito a \(variant.pixels)px\n".utf8))
        continue
    }
    writePNG(image, to: iconset.appendingPathComponent(variant.name))
}

print("iconset scritto in \(iconset.path)")