import AppKit
import CoreGraphics
import SwiftUI

/// 用户在设置里选的形象；用代码画素图画，不嵌原图。
enum PetLook: String, CaseIterable, Identifiable, Equatable {
    case squareEyes
    case roundGlasses
    case smile
    case mustache
    case sharpEyes
    case wizardHat
    case partyHat
    case chefHat
    case heart
    case checkeredFlag
    case dizzy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .squareEyes: return "方眼"
        case .roundGlasses: return "圆眼镜"
        case .smile: return "微笑"
        case .mustache: return "小胡子"
        case .sharpEyes: return "尖眼"
        case .wizardHat: return "巫师帽"
        case .partyHat: return "派对帽"
        case .chefHat: return "厨师帽"
        case .heart: return "头顶心"
        case .checkeredFlag: return "格子旗"
        case .dizzy: return "头晕螺旋"
        }
    }
}

enum PetSpriteMap {
    static let cols = 16
    /// 头顶留给帽子/螺旋；腿直接贴在身体下，中间不留空行。
    static let rows = 18

    /// 平顶方头、方眼、略窄身体、两侧短手、四条贴身短腿。
    private static let base: [String] = [
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
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
        ".FF..FF..FF..FF.",
        ".FF..FF..FF..FF.",
    ]

    static func pixels(look: PetLook, pose: PetPose, talking: Bool) -> [String] {
        var grid = base
        assertValid(grid)
        applyFace(&grid, look: look)
        applyHat(&grid, look: look)
        if talking {
            applyTalking(&grid)
        }
        applyPose(&grid, pose: pose)
        assertValid(grid)
        return grid
    }

    private static func assertValid(_ grid: [String]) {
        precondition(grid.count == rows)
        for row in grid {
            precondition(row.count == cols)
        }
    }

    private static func applyFace(_ grid: inout [String], look: PetLook) {
        switch look {
        case .squareEyes, .wizardHat, .partyHat, .chefHat, .heart, .checkeredFlag:
            break
        case .roundGlasses:
            put(&grid, 8, ".SBWWWWBBWWWWBS.")
            put(&grid, 9, ".SBWKKWBBWKKWBS.")
            put(&grid, 10, ".SBWWWWBBWWWWBS.")
        case .smile:
            put(&grid, 10, ".SBBB.WWWW.BBBS.")
        case .mustache:
            put(&grid, 10, ".SBB.KKKKKK.BBS.")
        case .sharpEyes:
            // 尖眼 > <
            put(&grid, 8, ".SBB.EB..BE.BBS.")
            put(&grid, 9, ".SBBEEB..BEEBBS.")
            put(&grid, 10, ".SBB.EB..BE.BBS.")
        case .dizzy:
            // 叉眼：两眼各画一个 X，嘴成一条缝。
            put(&grid, 8, ".SBE.EBBB.E.EBS.")
            put(&grid, 9, ".SB.E.BBB.E.BBS.")
            put(&grid, 10, ".SBE.EBWW.E.EBS.")
        }
    }

    private static func applyHat(_ grid: inout [String], look: PetLook) {
        switch look {
        case .squareEyes, .roundGlasses, .smile, .mustache, .sharpEyes:
            break
        case .wizardHat:
            put(&grid, 0, "......L.........")
            put(&grid, 1, ".....LLL........")
            put(&grid, 2, "....LLLLW.......")
            put(&grid, 3, "...LLLLLLL......")
            put(&grid, 4, "..LLKKKKKKLL....")
            put(&grid, 5, ".LLLLLLLLLLLLL..")
        case .partyHat:
            put(&grid, 1, ".......Y........")
            put(&grid, 2, "......PYP.......")
            put(&grid, 3, ".....PPPPP......")
            put(&grid, 4, "....PPYPYPP.....")
            put(&grid, 5, "...PPPPPPPPP....")
        case .chefHat:
            put(&grid, 1, "....WWWWWWW.....")
            put(&grid, 2, "...WWWWWWWWW....")
            put(&grid, 3, "...WW.WWW.WW....")
            put(&grid, 4, "....WWWWWWW.....")
            put(&grid, 5, ".....WWWWW......")
        case .heart:
            put(&grid, 2, ".....R.R........")
            put(&grid, 3, "....RRWRR.......")
            put(&grid, 4, ".....RRR........")
            put(&grid, 5, "......R.........")
        case .checkeredFlag:
            put(&grid, 0, ".........K......")
            put(&grid, 1, "........KWKW....")
            put(&grid, 2, "........WKWK....")
            put(&grid, 3, "........KWKW....")
            put(&grid, 4, ".........K......")
            put(&grid, 5, ".........K......")
        case .dizzy:
            put(&grid, 0, "......Z.........")
            put(&grid, 1, "....ZZ.ZZ.......")
            put(&grid, 2, "...Z..Z..Z......")
            put(&grid, 3, "...Z.ZZZ.Z......")
            put(&grid, 4, "....Z...Z.......")
            put(&grid, 5, ".....ZZZ........")
        }
    }

    private static func applyTalking(_ grid: inout [String]) {
        // 说话时下眼行收成身体色，身体中间张开嘴。
        put(&grid, 9, stampMouthClosedEyes(grid[9]))
        var body = Array(grid[12])
        if body.count == cols {
            body[6] = "M"
            body[7] = "M"
            put(&grid, 12, String(body))
        }
    }

    private static func stampMouthClosedEyes(_ row: String) -> String {
        var chars = Array(row)
        for i in chars.indices where chars[i] == "E" {
            chars[i] = "B"
        }
        return String(chars)
    }

    private static func applyPose(_ grid: inout [String], pose: PetPose) {
        switch pose {
        case .stand, .talking:
            // talking 只改嘴型（applyTalking），像素姿势仍用站立。
            break
        case .lift:
            // 头顶杠铃：两端铃片 + 横杆，双手举起；侧臂收起。
            put(&grid, 1, "LL............LL")
            put(&grid, 2, "LLLLLLLLLLLLLLLL")
            put(&grid, 3, "LK....BBBB....KL")
            put(&grid, 4, "......BBBB......")
            put(&grid, 5, "......BBBB......")
            put(&grid, 12, "...SBBBBBBBBS...")
            put(&grid, 13, "...SBBBBBBBBS...")
            put(&grid, 14, "...SBBBBBBBBS...")
            put(&grid, 15, "...SBBBBBBBBS...")
        case .busy:
            // 头顶一摞书，侧臂伸出表示忙碌。
            put(&grid, 2, merge(grid[2], "....RRRR........"))
            put(&grid, 3, merge(grid[3], "...YYYYYY......."))
            put(&grid, 4, merge(grid[4], "..GGGGGGGG......"))
            put(&grid, 5, merge(grid[5], "...KKKKKK......."))
            put(&grid, 13, "BBSBBBBBBBBBBSBB")
            put(&grid, 14, "BBSBBBBBBBBS.BB.")
        }
    }

    private static func put(_ grid: inout [String], _ row: Int, _ value: String) {
        precondition(value.count == cols)
        precondition(row >= 0 && row < rows)
        grid[row] = value
    }

    /// 非空像素盖住底层；用于姿势叠在帽子上。
    private static func merge(_ base: String, _ overlay: String) -> String {
        precondition(base.count == cols && overlay.count == cols)
        var out = Array(base)
        for (i, ch) in overlay.enumerated() where ch != "." {
            out[i] = ch
        }
        return String(out)
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
    static func isSolid(
        point: CGPoint,
        bounds: CGRect,
        span: CGFloat,
        talking: Bool,
        look: PetLook,
        pose: PetPose
    ) -> Bool {
        let cell = cell(span: span)
        guard cell > 0, bounds.width > 0, bounds.height > 0 else { return false }
        let canvas = canvasSize(span: span)
        let originX = (bounds.width - canvas.width) / 2
        let originTop = cell * hopRows
        let hop = talking ? cell : 0
        let x = Int(floor((point.x - originX) / cell))
        let yFromTop = bounds.height - point.y
        let row = Int(floor((yFromTop - originTop + hop) / cell))
        let grid = PetSpriteMap.pixels(look: look, pose: pose, talking: talking)
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
    var white: CGColor
    var red: CGColor
    var blue: CGColor
    var purple: CGColor
    var yellow: CGColor
    var green: CGColor
    var cyan: CGColor

    func color(for pixel: Character) -> CGColor? {
        switch pixel {
        case "B": return body
        case "S": return shade
        case "H": return highlight
        case "F": return foot
        case "E", "M", "K": return eye
        case "W", "C": return white
        case "R": return red
        case "L": return blue
        case "P": return purple
        case "Y": return yellow
        case "G": return green
        case "Z": return cyan
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
            eye: CGColor(srgbRed: 0.110, green: 0.090, blue: 0.100, alpha: 1),
            white: CGColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1),
            red: CGColor(srgbRed: 0.86, green: 0.22, blue: 0.28, alpha: 1),
            blue: CGColor(srgbRed: 0.22, green: 0.42, blue: 0.86, alpha: 1),
            purple: CGColor(srgbRed: 0.55, green: 0.28, blue: 0.78, alpha: 1),
            yellow: CGColor(srgbRed: 0.95, green: 0.78, blue: 0.22, alpha: 1),
            green: CGColor(srgbRed: 0.28, green: 0.68, blue: 0.38, alpha: 1),
            cyan: CGColor(srgbRed: 0.25, green: 0.72, blue: 0.88, alpha: 1)
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
    var look: PetLook = .squareEyes

    private var talking: Bool { pose == .talking }

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
        let grid = PetSpriteMap.pixels(look: look, pose: pose, talking: talking)
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
                    let shown = (blinking && (pixel == "E" || pixel == "K")) ? "B" : pixel
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
