import AppKit

enum PaintTool: String, CaseIterable {
    case brush, pencil, eraser, fill, picker, text, line, dashedLine, arrow, doubleArrow, rectangle, roundedRectangle, ellipse, more, selection
    case triangle, rightTriangle, diamond, pentagon, hexagon, star, fourPointStar, sixPointStar
    case trapezoid, parallelogram, singleRoundedRectangle, chevron, blockArrow, leftArrow, upArrow, downArrow
    case heart, roundedBubble, ellipseBubble, thoughtBubble, cloud, cylinder, cube, cone

    static let bubbleShapes: [PaintTool] = [.roundedBubble, .ellipseBubble, .thoughtBubble]
    static let blockArrowShapes: [PaintTool] = [.blockArrow, .leftArrow, .upArrow, .downArrow]
    static let extraShapes: [PaintTool] = bubbleShapes + blockArrowShapes + [
        .triangle, .rightTriangle, .diamond, .pentagon, .hexagon,
        .star, .fourPointStar, .sixPointStar, .trapezoid, .parallelogram,
        .singleRoundedRectangle, .chevron, .heart, .cloud, .cylinder, .cube, .cone
    ]

    var title: String {
        switch self {
        case .brush: return L("画笔")
        case .pencil: return L("铅笔")
        case .eraser: return L("橡皮")
        case .fill: return L("填色")
        case .picker: return L("取色")
        case .text: return L("文字")
        case .line: return L("直线")
        case .dashedLine: return L("虚线")
        case .arrow: return L("单箭头")
        case .doubleArrow: return L("双箭头")
        case .rectangle: return L("矩形")
        case .roundedRectangle: return L("圆角")
        case .ellipse: return L("椭圆")
        case .more: return L("更多")
        case .selection: return L("选区")
        case .triangle: return L("三角形")
        case .rightTriangle: return L("直角三角形")
        case .diamond: return L("菱形")
        case .pentagon: return L("五边形")
        case .hexagon: return L("六边形")
        case .star: return L("五角星")
        case .fourPointStar: return L("四角星")
        case .sixPointStar: return L("六角星")
        case .trapezoid: return L("梯形")
        case .parallelogram: return L("平行四边形")
        case .singleRoundedRectangle: return L("半圆头矩形")
        case .chevron: return L("燕尾形")
        case .blockArrow: return L("右向箭头")
        case .leftArrow: return L("左向箭头")
        case .upArrow: return L("向上箭头")
        case .downArrow: return L("向下箭头")
        case .heart: return L("心形")
        case .roundedBubble: return L("圆角气泡")
        case .ellipseBubble: return L("椭圆气泡")
        case .thoughtBubble: return L("思考气泡")
        case .cloud: return L("云朵")
        case .cylinder: return L("圆柱体")
        case .cube: return L("立方体")
        case .cone: return L("圆锥体")
        }
    }

    var tagline: String {
        switch self {
        case .brush: return L("让灵感，落在画布上。")
        case .pencil: return L("轻轻起笔，勾勒心中的模样。")
        case .eraser: return L("擦去一切烦恼。")
        case .fill: return L("给平凡的日子，填一点色彩。")
        case .picker: return L("收藏眼前，恰好的那一抹色。")
        case .text: return L("把心里话，写进画里。")
        case .line: return L("笔直的人生，走出自己的方向。")
        case .dashedLine: return L("留一点空隙，让想象接着走。")
        case .doubleArrow: return L("来往之间，总有值得的相遇。")
        case .arrow, .blockArrow: return L("心之所向，就是前进的方向。")
        case .rectangle: return L("方寸之间，装下整个世界。")
        case .roundedRectangle: return L("把生活的棱角，变得温柔。")
        case .ellipse: return L("兜兜转转，也是一种圆满。")
        case .more: return L("多一点形状，多一种想象。")
        case .triangle: return L("稳稳站住，也要向上生长。")
        case .rightTriangle: return L("有自己的角度，也有自己的坚持。")
        case .diamond: return L("换个角度，平凡也会闪光。")
        case .pentagon: return L("换一种轮廓，遇见新的可能。")
        case .hexagon: return L("每一个角，都有相遇的方向。")
        case .star: return L("把微小的光，画成自己的星星。")
        case .fourPointStar: return L("一束微光，也能照亮四方。")
        case .sixPointStar: return L("让每一份光芒，都有归处。")
        case .trapezoid: return L("脚下宽一点，向上近一点。")
        case .parallelogram: return L("稍稍倾斜，生活也能很稳。")
        case .singleRoundedRectangle: return L("一半坚定，一半温柔。")
        case .chevron: return L("走过转折，继续向前。")
        case .leftArrow: return L("偶尔回望，也是一种前行。")
        case .upArrow: return L("抬头向上，离梦想更近一点。")
        case .downArrow: return L("沉下心来，才能稳稳落笔。")
        case .heart: return L("把喜欢的事，认真放在心上。")
        case .roundedBubble: return L("温柔的话，也值得好好说。")
        case .ellipseBubble: return L("让每一句话，都有圆润的回响。")
        case .thoughtBubble: return L("把小小的念头，交给想象。")
        case .cloud: return L("让心事，轻轻飘远一点。")
        case .cylinder: return L("把平面的想象，立起来看看。")
        case .cube: return L("换个面，发现不一样的世界。")
        case .cone: return L("向着心中的一点，慢慢靠近。")
        case .selection: return L("框住喜欢的，留下想要的。")
        }
    }

    var shortcut: String {
        switch self {
        case .brush: return "B"
        case .pencil: return "P"
        case .eraser: return "E"
        case .fill: return "G"
        case .picker: return "I"
        case .text: return "T"
        case .line: return "L"
        case .dashedLine: return "D"
        case .rectangle: return "R"
        case .ellipse: return "O"
        case .selection: return "M"
        default: return ""
        }
    }
    var isBubble: Bool { Self.bubbleShapes.contains(self) }
    var isExtraShape: Bool { Self.extraShapes.contains(self) }
    var isLine: Bool { [.line, .dashedLine, .arrow, .doubleArrow].contains(self) }
    var isShape: Bool { [.rectangle, .roundedRectangle, .ellipse].contains(self) || isExtraShape }
}

// 图标预览和画布共用几何路径，避免菜单形状与实际绘制不一致。
enum ShapeRenderer {
    static func draw(_ tool: PaintTool, in rect: CGRect, context: CGContext, filled: Bool, color: NSColor, lineWidth: CGFloat) {
        guard rect.width > 0, rect.height > 0 else { return }
        let path = CGMutablePath()
        let details = CGMutablePath()
        let hidden = CGMutablePath()
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        func polygon(_ points: [(CGFloat, CGFloat)]) {
            guard let first = points.first else { return }
            path.move(to: p(first.0, first.1))
            points.dropFirst().forEach { path.addLine(to: p($0.0, $0.1)) }
            path.closeSubpath()
        }
        switch tool {
        case .rectangle: path.addRect(rect)
        case .roundedRectangle:
            let radius = Swift.min(18, Swift.min(rect.width, rect.height) / 4)
            path.addRoundedRect(in: rect, cornerWidth: radius, cornerHeight: radius)
        case .ellipse: path.addEllipse(in: rect)
        case .triangle: polygon([(0.5, 0), (1, 1), (0, 1)])
        case .rightTriangle: polygon([(0, 0), (1, 1), (0, 1)])
        case .diamond: polygon([(0.5, 0), (1, 0.5), (0.5, 1), (0, 0.5)])
        case .pentagon, .hexagon, .star, .fourPointStar, .sixPointStar:
            let star = [.star, .fourPointStar, .sixPointStar].contains(tool)
            let count = tool == .fourPointStar ? 4 : (tool == .hexagon || tool == .sixPointStar ? 6 : 5)
            let vertices = star ? count * 2 : count
            let ratio: CGFloat = tool == .fourPointStar ? 0.22 : 0.43
            polygon((0..<vertices).map { index in
                let angle = CGFloat(index) * .pi * 2 / CGFloat(vertices) - .pi / 2
                let radius: CGFloat = star && index % 2 == 1 ? ratio * 0.5 : 0.5
                return (0.5 + cos(angle) * radius, 0.5 + sin(angle) * radius)
            })
        case .trapezoid: polygon([(0.22, 0), (0.78, 0), (1, 1), (0, 1)])
        case .parallelogram: polygon([(0.25, 0), (1, 0), (0.75, 1), (0, 1)])
        case .singleRoundedRectangle:
            let radius = Swift.min(rect.width / 2, rect.height / 2)
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: radius)
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: radius)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); path.closeSubpath()
        case .chevron: polygon([(0, 0), (0.65, 0), (1, 0.5), (0.65, 1), (0, 1), (0.35, 0.5)])
        case .blockArrow: polygon([(0, 0.28), (0.62, 0.28), (0.62, 0), (1, 0.5), (0.62, 1), (0.62, 0.72), (0, 0.72)])
        case .leftArrow: polygon([(1, 0.28), (0.38, 0.28), (0.38, 0), (0, 0.5), (0.38, 1), (0.38, 0.72), (1, 0.72)])
        case .upArrow: polygon([(0.5, 0), (1, 0.38), (0.72, 0.38), (0.72, 1), (0.28, 1), (0.28, 0.38), (0, 0.38)])
        case .downArrow: polygon([(0.28, 0), (0.72, 0), (0.72, 0.62), (1, 0.62), (0.5, 1), (0, 0.62), (0.28, 0.62)])
        case .heart:
            path.move(to: p(0.5, 0.97))
            path.addCurve(to: p(0.04, 0.3), control1: p(0.18, 0.7), control2: p(-0.08, 0.54))
            path.addCurve(to: p(0.5, 0.2), control1: p(0.1, -0.08), control2: p(0.44, -0.04))
            path.addCurve(to: p(0.96, 0.3), control1: p(0.56, -0.04), control2: p(0.9, -0.08))
            path.addCurve(to: p(0.5, 0.97), control1: p(1.08, 0.54), control2: p(0.82, 0.7)); path.closeSubpath()
        case .roundedBubble:
            path.move(to: p(0.12, 0)); path.addLine(to: p(0.88, 0))
            path.addQuadCurve(to: p(1, 0.12), control: p(1, 0)); path.addLine(to: p(1, 0.66))
            path.addQuadCurve(to: p(0.88, 0.78), control: p(1, 0.78)); path.addLine(to: p(0.45, 0.78))
            path.addLine(to: p(0.12, 1)); path.addLine(to: p(0.2, 0.78)); path.addLine(to: p(0.12, 0.78))
            path.addQuadCurve(to: p(0, 0.66), control: p(0, 0.78)); path.addLine(to: p(0, 0.12))
            path.addQuadCurve(to: p(0.12, 0), control: p(0, 0)); path.closeSubpath()
        case .ellipseBubble:
            path.move(to: p(0.5, 0))
            path.addCurve(to: p(1, 0.38), control1: p(0.78, 0), control2: p(1, 0.17))
            path.addCurve(to: p(0.5, 0.76), control1: p(1, 0.59), control2: p(0.78, 0.76))
            path.addLine(to: p(0.16, 1)); path.addLine(to: p(0.24, 0.7))
            path.addCurve(to: p(0, 0.38), control1: p(0.09, 0.62), control2: p(0, 0.52))
            path.addCurve(to: p(0.5, 0), control1: p(0, 0.17), control2: p(0.22, 0)); path.closeSubpath()
        case .cloud, .thoughtBubble:
            let scale: CGFloat = tool == .thoughtBubble ? 0.78 : 1
            func cp(_ x: CGFloat, _ y: CGFloat) -> CGPoint { p(x, y * scale) }
            path.move(to: cp(0.2, 0.85))
            path.addCurve(to: cp(0.16, 0.35), control1: cp(-0.06, 0.85), control2: cp(-0.04, 0.38))
            path.addCurve(to: cp(0.58, 0.17), control1: cp(0.1, -0.02), control2: cp(0.5, -0.08))
            path.addCurve(to: cp(0.88, 0.4), control1: cp(0.8, 0), control2: cp(1.02, 0.13))
            path.addCurve(to: cp(0.83, 0.85), control1: cp(1.13, 0.48), control2: cp(1.04, 0.87))
            path.closeSubpath()
            if tool == .thoughtBubble {
                path.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.19, y: rect.minY + rect.height * 0.76, width: rect.width * 0.14, height: rect.height * 0.12))
                path.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.07, y: rect.minY + rect.height * 0.93, width: rect.width * 0.07, height: rect.height * 0.07))
            }
        case .cylinder:
            path.move(to: p(0, 0.15)); path.addCurve(to: p(1, 0.15), control1: p(0, -0.05), control2: p(1, -0.05))
            path.addLine(to: p(1, 0.85)); path.addCurve(to: p(0, 0.85), control1: p(1, 1.05), control2: p(0, 1.05)); path.closeSubpath()
            details.move(to: p(0, 0.15)); details.addCurve(to: p(1, 0.15), control1: p(0, 0.35), control2: p(1, 0.35))
            hidden.move(to: p(0, 0.85)); hidden.addCurve(to: p(1, 0.85), control1: p(0, 0.65), control2: p(1, 0.65))
        case .cube:
            polygon([(0.25, 0), (1, 0), (1, 0.75), (0.75, 1), (0, 1), (0, 0.25)])
            details.move(to: p(0, 0.25)); details.addLine(to: p(0.75, 0.25)); details.addLine(to: p(1, 0))
            details.move(to: p(0.75, 0.25)); details.addLine(to: p(0.75, 1))
        case .cone:
            path.move(to: p(0.5, 0)); path.addLine(to: p(1, 0.82))
            path.addCurve(to: p(0, 0.82), control1: p(1, 1.05), control2: p(0, 1.05)); path.closeSubpath()
            hidden.move(to: p(0, 0.82)); hidden.addCurve(to: p(1, 0.82), control1: p(0, 0.59), control2: p(1, 0.59))
        default: return
        }
        context.saveGState()
        context.setLineWidth(lineWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.addPath(path)
        context.drawPath(using: filled ? .fillStroke : .stroke)
        if !details.isEmpty { context.addPath(details); context.strokePath() }
        if !filled && !hidden.isEmpty {
            context.setLineDash(phase: 0, lengths: [lineWidth * 3, lineWidth * 2])
            context.addPath(hidden); context.strokePath()
        }
        context.restoreGState()
    }
}
