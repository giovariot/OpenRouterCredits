import CoreGraphics
import Foundation

/// Parser minimale di path SVG (`d`) verso `CGPath`.
///
/// Supporta i comandi `M m L l H h V v C c S s Q q T t Z z`, inclusa la
/// ripetizione implicita dei parametri. I comandi ad arco (`A a`) non sono
/// supportati: non servono per il marchio OpenRouter e un percorso che li usi
/// fa fallire il parsing in modo esplicito invece di disegnare qualcosa di
/// sbagliato.
public enum SVGPathParser {
    public static func path(from d: String) -> CGPath {
        var scanner = Scanner(d)
        let path = CGMutablePath()

        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var previousControl: CGPoint?
        var previousCommand: Character?

        while let command = scanner.nextCommand() {
            let relative = command.isLowercase
            let kind = Character(command.uppercased())

            switch kind {
            case "M":
                var first = true
                while let point = scanner.nextPoint() {
                    let target = relative ? current + point : point
                    if first {
                        path.move(to: target)
                        subpathStart = target
                        first = false
                    } else {
                        path.addLine(to: target)
                    }
                    current = target
                }
                previousControl = nil

            case "L":
                while let point = scanner.nextPoint() {
                    let target = relative ? current + point : point
                    path.addLine(to: target)
                    current = target
                }
                previousControl = nil

            case "H":
                while let value = scanner.nextNumber() {
                    let target = CGPoint(x: relative ? current.x + value : value, y: current.y)
                    path.addLine(to: target)
                    current = target
                }
                previousControl = nil

            case "V":
                while let value = scanner.nextNumber() {
                    let target = CGPoint(x: current.x, y: relative ? current.y + value : value)
                    path.addLine(to: target)
                    current = target
                }
                previousControl = nil

            case "C":
                while let handle1 = scanner.nextPoint(), let handle2 = scanner.nextPoint(), let point = scanner.nextPoint() {
                    let control1 = relative ? current + handle1 : handle1
                    let control2 = relative ? current + handle2 : handle2
                    let target = relative ? current + point : point
                    path.addCurve(to: target, control1: control1, control2: control2)
                    previousControl = control2
                    current = target
                }

            case "S":
                while let handle2 = scanner.nextPoint(), let point = scanner.nextPoint() {
                    let control1: CGPoint
                    if let previousControl, let previousCommand, "CS".contains(previousCommand) {
                        control1 = current * 2 - previousControl
                    } else {
                        control1 = current
                    }
                    let control2 = relative ? current + handle2 : handle2
                    let target = relative ? current + point : point
                    path.addCurve(to: target, control1: control1, control2: control2)
                    previousControl = control2
                    current = target
                }

            case "Q":
                while let handle = scanner.nextPoint(), let point = scanner.nextPoint() {
                    let control = relative ? current + handle : handle
                    let target = relative ? current + point : point
                    path.addQuadCurve(to: target, control: control)
                    previousControl = control
                    current = target
                }

            case "T":
                while let point = scanner.nextPoint() {
                    let control: CGPoint
                    if let previousControl, let previousCommand, "QT".contains(previousCommand) {
                        control = current * 2 - previousControl
                    } else {
                        control = current
                    }
                    let target = relative ? current + point : point
                    path.addQuadCurve(to: target, control: control)
                    previousControl = control
                    current = target
                }

            case "Z":
                path.closeSubpath()
                current = subpathStart
                previousControl = nil

            default:
                preconditionFailure("Comando SVG non supportato: \(command)")
            }

            previousCommand = kind
        }

        return path
    }

    /// Variante comoda per i path del marchio, che usano solo curve cubiche.
    static func bounds(of path: CGPath) -> CGRect {
        path.boundingBoxOfPath
    }

    private struct Scanner {
        private let scalars: [Character]
        private var index = 0

        init(_ string: String) {
            scalars = Array(string)
        }

        private mutating func skipSeparators() {
            while index < scalars.count {
                let c = scalars[index]
                if c == " " || c == "," || c == "\n" || c == "\t" || c == "\r" {
                    index += 1
                } else {
                    break
                }
            }
        }

        /// Restituisce il prossimo comando, saltando separatori e numeri
        /// già consumati dalle ripetizioni implicite.
        mutating func nextCommand() -> Character? {
            skipSeparators()
            while index < scalars.count {
                let c = scalars[index]
                if c.isLetter {
                    index += 1
                    return c
                }
                // Un numero senza comando (ripetizione implicita): il comando
                // precedente resta valido, ma qui lo consumiamo comunque.
                if nextNumber() != nil { continue }
                index += 1
            }
            return nil
        }

        mutating func nextNumber() -> Double? {
            skipSeparators()
            let start = index
            if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
                index += 1
            }
            var sawDigit = false
            while index < scalars.count, scalars[index].isNumber {
                index += 1
                sawDigit = true
            }
            if index < scalars.count, scalars[index] == "." {
                index += 1
                while index < scalars.count, scalars[index].isNumber {
                    index += 1
                    sawDigit = true
                }
            }
            if sawDigit, index < scalars.count, scalars[index] == "e" || scalars[index] == "E" {
                let exponentStart = index
                index += 1
                if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
                    index += 1
                }
                var sawExponentDigit = false
                while index < scalars.count, scalars[index].isNumber {
                    index += 1
                    sawExponentDigit = true
                }
                if !sawExponentDigit {
                    index = exponentStart
                }
            }
            guard sawDigit, index > start else {
                index = start
                return nil
            }
            return Double(String(scalars[start..<index]))
        }

        mutating func nextPoint() -> CGPoint? {
            guard let x = nextNumber() else { return nil }
            guard let y = nextNumber() else { return nil }
            return CGPoint(x: x, y: y)
        }
    }
}

func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
    CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
}