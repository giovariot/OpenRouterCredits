import OpenRouterCreditsCore
import SwiftUI

/// La grafica del widget, condivisa tra estensione, app e anteprime.
///
/// Usa solo font di sistema (SF) e riceve il tema già risolto, così lo stesso
/// layout funziona in `fullColor`, `accented` e `vibrant`.
public struct CreditsWidgetView: View {
    private let model: CreditsWidgetModel
    private let theme: WidgetTheme
    private let metrics: WidgetMetrics

    public init(model: CreditsWidgetModel, theme: WidgetTheme) {
        self.model = model
        self.theme = theme
        self.metrics = WidgetMetrics.build(from: model)
    }

    public var body: some View {
        Group {
            switch model.size {
            case .small:
                smallBody
            case .medium:
                mediumBody
            }
        }
        .padding(model.size == .small ? 14 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Small

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 6)
            if metrics.isEmpty {
                emptyState(compact: true)
                Spacer(minLength: 0)
            } else {
                hero(fontSize: 30)
                Spacer(minLength: 8)
                if let fraction = metrics.fraction {
                    ProgressBar(fraction: fraction, theme: theme)
                    Spacer(minLength: 7)
                }
                footer
            }
        }
    }

    // MARK: - Medium

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 6)
                if metrics.isEmpty {
                    emptyState(compact: false)
                    Spacer(minLength: 0)
                } else {
                    hero(fontSize: 32)
                    Spacer(minLength: 9)
                    if let fraction = metrics.fraction {
                        ProgressBar(fraction: fraction, theme: theme)
                        Spacer(minLength: 9)
                    }
                    footer
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !metrics.isEmpty {
                sidePanel
            }
        }
    }

    // MARK: - Componenti

    private var header: some View {
        HStack(spacing: 5) {
            OpenRouterGlyph()
                .fill(theme.accent, style: OpenRouterGlyph.fillStyle)
                .frame(width: 15, height: 15 / OpenRouterGlyph.aspectRatio)
                .widgetAccentable()

            Text("OpenRouter")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 2)

            if model.lastError != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    private func hero(fontSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metrics.heroValue.map { Format.money($0, cents: model.options.showCents) } ?? "$--")
                .font(.system(size: fontSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .widgetAccentable()

            Text(metrics.caption)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)

            if let detail = metrics.detail {
                Text(detail)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .padding(.top, 1)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let updated = metrics.updatedText {
            Text(updated)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private func emptyState(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metrics.caption)
                .font(.system(size: compact ? 15 : 17, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let detail = metrics.detail {
                Text(detail)
                    .font(.system(size: compact ? 10.5 : 11.5))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(3)
            }
        }
    }

    private var sidePanel: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if usesChart {
                Sparkline(samples: model.history, theme: theme)
                    .frame(width: 122, height: 52)
                Text(Strings.text("ultime 24 ore"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.top, 3)
            } else {
                Text(Format.money(panelValue, cents: model.options.showCents))
                    .font(.system(size: 20, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                Text(panelLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .padding(.top, 1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                if !hiddenStatMetrics.contains(.daily), let daily = metrics.dailyText {
                    statLine(daily)
                }
                if !hiddenStatMetrics.contains(.weekly), let weekly = metrics.weeklyText {
                    statLine(weekly)
                }
                if !hiddenStatMetrics.contains(.monthly), let monthly = metrics.monthlyText {
                    statLine(monthly)
                }
            }
        }
        .frame(width: 122, alignment: .trailing)
    }

    /// I valori già mostrati in grande (o nel pannello senza grafico) non
    /// vengono ripetuti nell'elenco a destra.
    private var hiddenStatMetrics: Set<WidgetMetric> {
        var hidden: Set<WidgetMetric> = [metrics.metric]
        if !usesChart, !(metrics.metric == .daily && model.snapshot?.displayRemaining != nil) {
            hidden.insert(.daily)
        }
        return hidden
    }

    /// Il grafico si può spegnere dalle impostazioni del widget.
    private var usesChart: Bool {
        model.options.showChart && model.history.count >= 2
    }

    /// Senza grafico si mostra la spesa di oggi, o il residuo se la spesa di
    /// oggi è già il numero in evidenza.
    private var panelValue: Double? {
        if metrics.metric == .daily, let remaining = model.snapshot?.displayRemaining {
            return remaining
        }
        return metrics.dailyAmount
    }

    private var panelLabel: String {
        if metrics.metric == .daily, model.snapshot?.displayRemaining != nil {
            return Strings.text("credito residuo")
        }
        return Strings.text("spesa di oggi")
    }

    private func statLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(theme.textTertiary)
            .lineLimit(1)
    }
}

/// Barra di avanzamento del credito residuo.
struct ProgressBar: View {
    let fraction: Double
    let theme: WidgetTheme

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(theme.track)
                Capsule(style: .continuous)
                    .fill(theme.barTint)
                    .frame(width: max(4, geometry.size.width * fraction))
            }
        }
        .frame(height: 5)
        .widgetAccentable()
    }
}

/// Mini grafico dell'andamento dei crediti nelle ultime ore.
struct Sparkline: View {
    let samples: [StoredState.Sample]
    let theme: WidgetTheme

    var body: some View {
        GeometryReader { geometry in
            let points = points(in: geometry.size)
            ZStack {
                if points.count >= 2 {
                    areaPath(points, size: geometry.size)
                        .fill(
                            LinearGradient(
                                colors: [theme.accent.opacity(0.30), theme.accent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    linePath(points)
                        .stroke(
                            theme.accent,
                            style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
                        )
                }
            }
        }
        .widgetAccentable()
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard samples.count >= 2 else { return [] }
        let values = samples.map(\.value)
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 0
        let span = maximum - minimum
        let inset: CGFloat = 3
        let usableHeight = max(size.height - inset * 2, 1)

        return samples.enumerated().map { index, sample in
            let x = CGFloat(index) / CGFloat(samples.count - 1) * size.width
            let normalized = span > 0 ? (sample.value - minimum) / span : 0.5
            let y = inset + usableHeight * CGFloat(1 - normalized)
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func areaPath(_ points: [CGPoint], size: CGSize) -> Path {
        var path = linePath(points)
        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: size.height))
        path.addLine(to: CGPoint(x: points[0].x, y: size.height))
        path.closeSubpath()
        return path
    }
}