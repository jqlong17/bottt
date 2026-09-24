import AppKit
import CoreGraphics
import SwiftUI

enum PetSpriteMap {
    static let cols = 16
    static let rows = 13

    /// 平顶方头、分开的方眼、略窄的身体、两侧短手、四条分开的短腿。
    static let idle = [
        ".SSSSSSSSSSSSSS.",
        ".SHHHHHHHHHHHHS.",
        ".SBBEEBBBBEEBBS.",
        ".SBBEEBBBBEEBBS.",
        ".SBBBBBBBBBBBBS.",
        ".SSSSSSSSSSSSSS.",
        "...SBBBBBBBBS...",
        ".BBSBBBBBBBBSBB.",
        ".BBSBBBBBBBBSBB.",
        "...SBBBBBBBBS...",
        "................",
        ".FF..FF..FF..FF.",
        ".FF..FF..FF..FF.",
    ]

    static let talking: [String] = {
        var rows = idle
        rows[3] = ".SBBBBBBBBBBBBS."
        rows[6] = "...SBBBMMBBBS..."
        return rows
    }()

    static func pixels(talking isTalking: Bool) -> [String] {
        for row in idle + talking {
            precondition(row.count == cols)
        }
        precondition(idle.count == rows && talking.count == rows)
        return isTalking ? talking : idle
    }
}

enum PetMetrics {
    static let minSpan: CGFloat = 48
    static let maxSpan: CGFloat = 240
    /// 原来 16×10pt，默认收到大约一半。
    static let defaultSpan: CGFloat = 80
    static let hopRows: CGFloat = 1
    /// 头顶字幕带。窗口往上长，脚还留在原来的位置。
    static let captionBand: CGFloat = 28
    /// 只放字幕时固定字号，约 5 个词一行，宽度可比身体更宽。
    static let captionFontSize: CGFloat = 12
    static let captionMinWidth: CGFloat = 260

    static func cell(span: CGFloat) -> CGFloat {
        max(1, span / CGFloat(PetSpriteMap.cols))
    }

    static func canvasSize(span: CGFloat) -> CGSize {
        let cell = cell(span: span)
        return CGSize(
            width: cell * CGFloat(PetSpriteMap.cols),
            height: cell * (CGFloat(PetSpriteMap.rows) + hopRows)
        )
    }

    static func windowSize(span: CGFloat) -> CGSize {
        let canvas = canvasSize(span: span)
        return CGSize(
            width: max(canvas.width, captionMinWidth),
            height: canvas.height + captionBand
        )
    }

    /// `point` 用视图坐标，原点在左下。空白像素返回 false，点击会穿过窗口。
    static func isSolid(point: CGPoint, bounds: CGRect, span: CGFloat, talking: Bool) -> Bool {
        let cell = cell(span: span)
        guard cell > 0, bounds.width > 0, bounds.height > 0 else { return false }
        let canvas = canvasSize(span: span)
        let originX = (bounds.width - canvas.width) / 2
        let originTop = cell * hopRows
        let hop = talking ? cell : 0
        let x = Int(floor((point.x - originX) / cell))
        let yFromTop = bounds.height - point.y
        let row = Int(floor((yFromTop - originTop + hop) / cell))
        let grid = PetSpriteMap.pixels(talking: talking)
        guard row >= 0, row < grid.count, x >= 0, x < PetSpriteMap.cols else { return false }
        let line = grid[row]
        let index = line.index(line.startIndex, offsetBy: x)
        return line[index] != "."
    }
}

struct PetInk {
    var body: CGColor
    var shade: CGColor
    var highlight: CGColor
    var foot: CGColor
    var eye: CGColor

    func color(for pixel: Character) -> CGColor? {
        switch pixel {
        case "B": return body
        case "S": return shade
        case "H": return highlight
        case "F": return foot
        case "E", "M": return eye
        default: return nil
        }
    }

    static func make(bodyColor: Color) -> PetInk {
        let ns = NSColor(bodyColor).usingColorSpace(.sRGB)
            ?? NSColor(srgbRed: 184 / 255, green: 104 / 255, blue: 80 / 255, alpha: 1)
        let body = (ns.redComponent, ns.greenComponent, ns.blueComponent)
        return PetInk(
            body: cg(body),
            shade: cg(scale(body, by: 0.72)),
            highlight: cg(mix(body, with: (1, 1, 1), amount: 0.42)),
            foot: cg(scale(body, by: 0.55)),
            eye: CGColor(srgbRed: 0.110, green: 0.090, blue: 0.100, alpha: 1)
        )
    }

    private static func scale(_ rgb: (CGFloat, CGFloat, CGFloat), by factor: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        (rgb.0 * factor, rgb.1 * factor, rgb.2 * factor)
    }

    private static func mix(
        _ rgb: (CGFloat, CGFloat, CGFloat),
        with other: (CGFloat, CGFloat, CGFloat),
        amount: CGFloat
    ) -> (CGFloat, CGFloat, CGFloat) {
        (
            rgb.0 + (other.0 - rgb.0) * amount,
            rgb.1 + (other.1 - rgb.1) * amount,
            rgb.2 + (other.2 - rgb.2) * amount
        )
    }

    private static func cg(_ rgb: (CGFloat, CGFloat, CGFloat)) -> CGColor {
        CGColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }
}

struct PetSprite: View {
    var pose: PetPose
    var blinking: Bool
    var bodyColor: Color
    var span: CGFloat

    var body: some View {
        let size = PetMetrics.canvasSize(span: span)
        let ink = PetInk.make(bodyColor: bodyColor)
        Canvas { context, _ in
            draw(context: &context, span: span, ink: ink)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private func draw(context: inout GraphicsContext, span: CGFloat, ink: PetInk) {
        // 形象分支会接 lift / busy 帧与微笑脸；此处先复用 idle/talking 像素，只把姿势枚举接好。
        let talking = pose == .talking
        let grid = PetSpriteMap.pixels(talking: talking)
        let cell = PetMetrics.cell(span: span)
        let originY = cell * PetMetrics.hopRows
        let hop: CGFloat
        switch pose {
        case .talking, .lift:
            hop = cell
        case .busy:
            hop = cell * 0.35
        case .stand:
            hop = 0
        }

        context.withCGContext { cg in
            cg.setShouldAntialias(false)
            cg.interpolationQuality = .none
            for (y, row) in grid.enumerated() {
                for (x, pixel) in row.enumerated() {
                    let shown = (blinking && pixel == "E") ? "B" : pixel
                    guard let color = ink.color(for: shown) else { continue }
                    cg.setFillColor(color)
                    cg.fill(CGRect(
                        x: CGFloat(x) * cell,
                        y: originY + CGFloat(y) * cell - hop,
                        width: cell,
                        height: cell
                    ))
                }
            }
        }
    }
}
