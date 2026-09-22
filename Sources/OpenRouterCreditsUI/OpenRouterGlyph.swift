import CoreGraphics
import OpenRouterCreditsCore
import SwiftUI

/// Il marchio di OpenRouter (il segno, senza il wordmark) come forma
/// vettoriale, ricavato dal path ufficiale di `openrouter-light.svg`.
public struct OpenRouterGlyph: Shape {
    /// Ritaglio del segno: è il riquadro stretto del disegno (la curva in alto
    /// a destra sporge oltre l'ultimo punto del path).
    public static let viewBox = CGRect(x: 19.81995, y: 17.19926, width: 365.55992, height: 258.29777)

    /// Rapporto larghezza/altezza del segno.
    public static let aspectRatio: CGFloat = viewBox.width / viewBox.height

    private static let pathData = """
    M303.9475,17.19926c42.79734,0,77.48933,34.69327,77.48933,77.48933s-34.69199,77.48933-77.48933,77.48933l76.86166,76.86244c9.76367,9.76313,2.84903,26.45667-10.95697,26.45667h-220.88335c-71.32686,0-129.14889-57.82202-129.14889-129.14889S77.64197,17.19926,148.96884,17.19926h154.97866ZM148.96884,68.85881c-42.79607,0-77.48933,34.69327-77.48933,77.48933s34.69327,77.48933,77.48933,77.48933,77.48933-34.69327,77.48933-77.48933-34.69327-77.48933-77.48933-77.48933Z
    """

    /// Il path del marchio nelle coordinate originali del file SVG.
    public static let cgPath: CGPath = SVGPathParser.path(from: pathData)

    public init() {}

    public func path(in rect: CGRect) -> Path {
        let box = Self.viewBox
        let scale = min(rect.width / box.width, rect.height / box.height)
        guard scale > 0 else { return Path() }
        let originX = rect.minX + (rect.width - box.width * scale) / 2
        let originY = rect.minY + (rect.height - box.height * scale) / 2
        var transform = CGAffineTransform(
            a: scale,
            b: 0,
            c: 0,
            d: scale,
            tx: originX - box.minX * scale,
            ty: originY - box.minY * scale
        )
        guard let transformed = Self.cgPath.copy(using: &transform) else {
            return Path()
        }
        return Path(transformed)
    }

    /// Riempimento con regola even-odd, necessaria perché il segno ha un foro.
    public static let fillStyle = FillStyle(eoFill: true)
}

public struct OpenRouterBadge: View {
    private let size: CGFloat
    private let mark: Color
    private let background: Color

    public init(size: CGFloat, mark: Color, background: Color) {
        self.size = size
        self.mark = mark
        self.background = background
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(background)
            .frame(width: size, height: size)
            .overlay(
                OpenRouterGlyph()
                    .fill(mark, style: OpenRouterGlyph.fillStyle)
                    .frame(width: size * 0.72, height: size * 0.52)
            )
    }
}