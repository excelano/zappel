// Textures.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)
//
// Every sprite is drawn here once with Core Graphics, at the screen's pixel scale, and
// kept as a texture. Drawing coordinates are in points with the origin at the bottom left,
// as in SpriteKit; creatures are drawn facing right.

import CoreGraphics
import SpriteKit

struct CaterpillarTextures {
    let head: SKTexture
    let body: SKTexture
    let wingsOpen: SKTexture
    let wingsClosed: SKTexture
}

final class Textures {
    let cell: CGFloat
    let scale: CGFloat

    let sprinklerStand: SKTexture
    let sprinklerHead: SKTexture
    let lifeIcon: SKTexture
    let drop: SKTexture
    let beeFrames: [SKTexture]
    let acorn: SKTexture
    let acornCracked: SKTexture
    let snail: SKTexture
    let shell: SKTexture
    /// Indexed by color, then health 1 to 3 (index 0 unused), then slippery.
    private let flowers: [[[SKTexture]]]
    private var caterpillars: [RGB: CaterpillarTextures] = [:]

    var segmentSize: CGSize { CGSize(width: cell, height: cell) }
    var butterflySize: CGSize { CGSize(width: cell * 1.3, height: cell * 1.1) }
    var dropSize: CGSize { CGSize(width: cell * 0.4, height: cell * 0.65) }
    var beeSize: CGSize { CGSize(width: cell * 1.5, height: cell * 1.25) }
    var acornSize: CGSize { CGSize(width: cell * 0.85, height: cell * 1.05) }
    var snailSize: CGSize { CGSize(width: cell * 1.6, height: cell * 1.1) }
    var shellSize: CGSize { CGSize(width: cell * 0.9, height: cell * 0.9) }
    var sprinklerHeadSize: CGSize { CGSize(width: cell * 0.95, height: cell * 0.95) }

    init(cell: CGFloat, scale: CGFloat) {
        self.cell = cell
        self.scale = scale
        let s = cell
        sprinklerStand = Self.render(CGSize(width: s, height: s), scale) { Self.drawStand($0, s) }
        sprinklerHead = Self.render(CGSize(width: s * 0.95, height: s * 0.95), scale) { Self.drawSprinklerHead($0, s * 0.95) }
        lifeIcon = Self.render(CGSize(width: s, height: s), scale) { context in
            Self.drawStand(context, s)
            context.translateBy(x: s * 0.1, y: s * 0.4)
            Self.drawSprinklerHead(context, s * 0.8)
        }
        drop = Self.render(CGSize(width: s * 0.4, height: s * 0.65), scale) { Self.drawDrop($0, CGSize(width: s * 0.4, height: s * 0.65)) }
        beeFrames = [true, false].map { wingsUp in
            Self.render(CGSize(width: s * 1.5, height: s * 1.25), scale) { Self.drawBee($0, s, wingsUp: wingsUp) }
        }
        acorn = Self.render(CGSize(width: s * 0.85, height: s * 1.05), scale) { Self.drawAcorn($0, s, cracked: false) }
        acornCracked = Self.render(CGSize(width: s * 0.85, height: s * 1.05), scale) { Self.drawAcorn($0, s, cracked: true) }
        snail = Self.render(CGSize(width: s * 1.6, height: s * 1.1), scale) { Self.drawSnail($0, s) }
        shell = Self.render(CGSize(width: s * 0.9, height: s * 0.9), scale) { context in
            Self.drawShell(context, center: CGPoint(x: s * 0.45, y: s * 0.45), radius: s * 0.4, s)
        }
        flowers = Palette.flowerColors.map { color in
            (0...Rules.flowerHealth).map { health in
                [false, true].map { slippery in
                    Self.render(CGSize(width: s, height: s), scale) {
                        Self.drawFlower($0, s, color: color, health: max(health, 1), slippery: slippery)
                    }
                }
            }
        }
    }

    func flower(color: Int, health: Int, slippery: Bool) -> SKTexture {
        flowers[color % flowers.count][health][slippery ? 1 : 0]
    }

    func caterpillar(_ color: RGB) -> CaterpillarTextures {
        if let cached = caterpillars[color] { return cached }
        let s = cell
        let made = CaterpillarTextures(
            head: Self.render(segmentSize, scale) { Self.drawHead($0, s, color: color) },
            body: Self.render(segmentSize, scale) { Self.drawBody($0, s, color: color) },
            wingsOpen: Self.render(butterflySize, scale) { Self.drawButterfly($0, s, color: color, open: 1) },
            wingsClosed: Self.render(butterflySize, scale) { Self.drawButterfly($0, s, color: color, open: 0.35) })
        caterpillars[color] = made
        return made
    }

    /// The sky band behind the score row and the striped lawn below it, the bottom
    /// stripe running on down to the screen's edge.
    func background(size: CGSize, palette: Palette, gridTop: CGFloat, rows: Int, playerZoneTop: Int, soil: CGFloat,
                    gap: CGFloat) -> SKTexture {
        let cell = self.cell
        return Self.render(size, scale) { context in
            let skyBottom = gridTop - cell
            for row in 1..<rows {
                let color = row.isMultiple(of: 2) ? palette.grassLight : palette.grassDark
                context.setFillColor(row >= playerZoneTop ? color.mixed(with: .white, 0.08).cgColor : color.cgColor)
                let top = gridTop - CGFloat(row) * cell
                let bottom = row == rows - 1 ? 0 : top - cell
                context.fill(CGRect(x: 0, y: bottom, width: size.width, height: top - bottom))
            }
            let colors = [palette.skyTop.cgColor, palette.skyBottom.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) {
                context.saveGState()
                context.clip(to: CGRect(x: 0, y: skyBottom, width: size.width, height: size.height - skyBottom))
                context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height),
                                           end: CGPoint(x: 0, y: skyBottom), options: [])
                context.restoreGState()
            }
            context.setFillColor(palette.grassDark.mixed(with: .black, 0.25).cgColor)
            context.fill(CGRect(x: 0, y: skyBottom - cell * 0.08, width: size.width, height: cell * 0.08))
            if soil > 0 {
                Self.drawSoil(context, width: size.width, height: soil, gap: gap, cell: cell)
            }
        }
    }

    /// A strip of earth with a row of stepping stones, where a finger steers on iPhone,
    /// above a darker band of bare earth that takes no touches.
    private static func drawSoil(_ context: CGContext, width: CGFloat, height: CGFloat, gap: CGFloat, cell: CGFloat) {
        let top = gap + height
        context.setFillColor(Palette.soilEdge.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: top))
        context.setFillColor(Palette.soil.cgColor)
        context.fill(CGRect(x: 0, y: gap, width: width, height: height - cell * 0.1))
        let stone = CGSize(width: cell * 0.62, height: cell * 0.34)
        for column in 0..<Rules.columns {
            let x = (CGFloat(column) + 0.5) * cell
            let y = gap + height / 2 + cell * (column.isMultiple(of: 2) ? 0.08 : -0.08)
            let rect = CGRect(x: x - stone.width / 2, y: y - stone.height / 2, width: stone.width, height: stone.height)
            fillEllipse(context, rect.offsetBy(dx: 0, dy: -cell * 0.04), Palette.soilEdge.cgColor)
            fillEllipse(context, rect, Palette.stone.cgColor)
        }
    }

    // MARK: - Rendering

    private static func render(_ size: CGSize, _ scale: CGFloat, _ draw: (CGContext) -> Void) -> SKTexture {
        let width = max(1, Int((size.width * scale).rounded(.up)))
        let height = max(1, Int((size.height * scale).rounded(.up)))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return SKTexture() }
        context.scaleBy(x: scale, y: scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        draw(context)
        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        return texture
    }

    private static func fillEllipse(_ context: CGContext, _ rect: CGRect, _ color: CGColor) {
        context.setFillColor(color)
        context.fillEllipse(in: rect)
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    // MARK: - Caterpillar

    private static func drawBody(_ context: CGContext, _ s: CGFloat, color: RGB) {
        let dark = color.mixed(with: .black, 0.4)
        for dx in [-0.2, 0.2] {
            fillEllipse(context, CGRect(x: s * (0.5 + dx) - s * 0.08, y: s * 0.04, width: s * 0.16, height: s * 0.12), dark.cgColor)
        }
        let center = CGPoint(x: s * 0.5, y: s * 0.52)
        fillEllipse(context, circle(center, s * 0.42), dark.cgColor)
        fillEllipse(context, circle(center, s * 0.36), color.cgColor)
        fillEllipse(context, CGRect(x: s * 0.28, y: s * 0.6, width: s * 0.2, height: s * 0.14), RGB.white.cgColor(alpha: 0.45))
    }

    private static func drawHead(_ context: CGContext, _ s: CGFloat, color: RGB) {
        let dark = color.mixed(with: .black, 0.45)
        context.setStrokeColor(dark.cgColor)
        context.setLineWidth(s * 0.06)
        for (base, tip) in [(CGPoint(x: 0.45, y: 0.76), CGPoint(x: 0.36, y: 0.93)),
                            (CGPoint(x: 0.62, y: 0.76), CGPoint(x: 0.74, y: 0.93))] {
            context.move(to: CGPoint(x: base.x * s, y: base.y * s))
            context.addLine(to: CGPoint(x: tip.x * s, y: tip.y * s))
            context.strokePath()
            fillEllipse(context, circle(CGPoint(x: tip.x * s, y: tip.y * s), s * 0.06), dark.cgColor)
        }
        let center = CGPoint(x: s * 0.5, y: s * 0.45)
        fillEllipse(context, circle(center, s * 0.4), dark.cgColor)
        fillEllipse(context, circle(center, s * 0.34), color.mixed(with: .white, 0.15).cgColor)
        for x in [0.54, 0.74] {
            let eye = CGPoint(x: s * x, y: s * 0.52)
            fillEllipse(context, circle(eye, s * 0.1), RGB.white.cgColor)
            fillEllipse(context, circle(CGPoint(x: eye.x + s * 0.03, y: eye.y), s * 0.055), Palette.ink.cgColor)
        }
        context.setStrokeColor(Palette.ink.cgColor)
        context.setLineWidth(s * 0.05)
        context.addArc(center: CGPoint(x: s * 0.64, y: s * 0.36), radius: s * 0.11,
                       startAngle: .pi * 1.2, endAngle: .pi * 1.8, clockwise: false)
        context.strokePath()
    }

    /// `open` is how far the wings spread, 1 for fully open.
    private static func drawButterfly(_ context: CGContext, _ s: CGFloat, color: RGB, open: CGFloat) {
        let center = CGPoint(x: s * 0.65, y: s * 0.55)
        let edge = color.mixed(with: .black, 0.35)
        for side: CGFloat in [-1, 1] {
            let upper = CGRect(x: center.x + side * s * 0.3 * open - s * 0.26 * open, y: center.y - s * 0.02,
                               width: s * 0.52 * open, height: s * 0.46)
            let lower = CGRect(x: center.x + side * s * 0.2 * open - s * 0.18 * open, y: center.y - s * 0.4,
                               width: s * 0.36 * open, height: s * 0.38)
            for wing in [upper, lower] {
                fillEllipse(context, wing, edge.cgColor)
                fillEllipse(context, wing.insetBy(dx: s * 0.04 * open, dy: s * 0.04), color.cgColor)
            }
            fillEllipse(context, circle(CGPoint(x: upper.midX, y: upper.midY + s * 0.04), s * 0.07 * max(open, 0.5)),
                        RGB.white.cgColor(alpha: 0.85))
        }
        fillEllipse(context, CGRect(x: center.x - s * 0.06, y: center.y - s * 0.36, width: s * 0.12, height: s * 0.72),
                    Palette.ink.cgColor)
    }

    // MARK: - Flowers

    private static func drawFlower(_ context: CGContext, _ s: CGFloat, color: RGB, health: Int, slippery: Bool) {
        let petalColor = slippery ? color.mixed(with: Palette.slippery, 0.7) : color
        let edge = slippery ? Palette.slippery.mixed(with: .black, 0.45) : color.mixed(with: .black, 0.35)
        let center = CGPoint(x: s * 0.5, y: s * 0.5)

        if health == 1 {
            context.setStrokeColor(Palette.leaf.cgColor)
            context.setLineWidth(s * 0.08)
            context.move(to: CGPoint(x: s * 0.5, y: s * 0.1))
            context.addLine(to: CGPoint(x: s * 0.5, y: s * 0.5))
            context.strokePath()
            for side: CGFloat in [-1, 1] {
                fillEllipse(context, CGRect(x: s * 0.5 + side * s * 0.14 - s * 0.12, y: s * 0.14, width: s * 0.24, height: s * 0.14),
                            Palette.leaf.cgColor)
            }
            let bud = CGRect(x: s * 0.33, y: s * 0.42, width: s * 0.34, height: s * 0.44)
            fillEllipse(context, bud, edge.cgColor)
            fillEllipse(context, bud.insetBy(dx: s * 0.05, dy: s * 0.05), petalColor.cgColor)
        } else {
            let size: CGFloat = health == Rules.flowerHealth ? 1 : 0.62
            for index in 0..<5 {
                let angle = CGFloat(index) * 2 * .pi / 5 + .pi / 2
                context.saveGState()
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: angle)
                let petal = CGRect(x: s * 0.06 * size, y: -s * 0.12 * size, width: s * 0.38 * size, height: s * 0.24 * size)
                fillEllipse(context, petal, edge.cgColor)
                fillEllipse(context, petal.insetBy(dx: s * 0.035, dy: s * 0.035), petalColor.cgColor)
                context.restoreGState()
            }
            fillEllipse(context, circle(center, s * 0.13 * size), Palette.flowerCenter.mixed(with: .black, 0.2).cgColor)
            fillEllipse(context, circle(center, s * 0.09 * size), Palette.flowerCenter.cgColor)
        }

        if slippery {
            context.setStrokeColor(RGB.white.cgColor(alpha: 0.95))
            context.setLineWidth(s * 0.07)
            context.addArc(center: center, radius: s * 0.3, startAngle: .pi * 0.6, endAngle: .pi * 0.95, clockwise: false)
            context.strokePath()
            let sparkle = CGPoint(x: s * 0.8, y: s * 0.8)
            context.setLineWidth(s * 0.05)
            context.move(to: CGPoint(x: sparkle.x - s * 0.09, y: sparkle.y))
            context.addLine(to: CGPoint(x: sparkle.x + s * 0.09, y: sparkle.y))
            context.move(to: CGPoint(x: sparkle.x, y: sparkle.y - s * 0.09))
            context.addLine(to: CGPoint(x: sparkle.x, y: sparkle.y + s * 0.09))
            context.strokePath()
        }
    }

    // MARK: - Sprinkler and water

    private static func drawStand(_ context: CGContext, _ s: CGFloat) {
        fillEllipse(context, CGRect(x: s * 0.2, y: s * 0.02, width: s * 0.6, height: s * 0.18), Palette.metalDark.cgColor)
        context.setFillColor(Palette.metalDark.cgColor)
        context.fill(CGRect(x: s * 0.41, y: s * 0.1, width: s * 0.18, height: s * 0.48))
        context.setFillColor(Palette.metal.cgColor)
        context.fill(CGRect(x: s * 0.45, y: s * 0.1, width: s * 0.07, height: s * 0.48))
    }

    private static func drawSprinklerHead(_ context: CGContext, _ size: CGFloat) {
        let center = CGPoint(x: size / 2, y: size / 2)
        let nozzles = (0..<3).map { index in
            let angle = CGFloat(index) * 2 * .pi / 3 + .pi / 2
            return CGPoint(x: center.x + cos(angle) * size * 0.36, y: center.y + sin(angle) * size * 0.36)
        }
        for (color, width) in [(Palette.sprinkler.mixed(with: .black, 0.4), 0.2), (Palette.sprinkler, 0.11)] {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(size * width)
            for nozzle in nozzles {
                context.move(to: center)
                context.addLine(to: nozzle)
            }
            context.strokePath()
        }
        for nozzle in nozzles {
            fillEllipse(context, circle(nozzle, size * 0.1), Palette.waterEdge.cgColor)
        }
        fillEllipse(context, circle(center, size * 0.22), Palette.sprinkler.mixed(with: .black, 0.4).cgColor)
        fillEllipse(context, circle(center, size * 0.16), Palette.sprinkler.cgColor)
        fillEllipse(context, circle(CGPoint(x: center.x - size * 0.05, y: center.y + size * 0.05), size * 0.05),
                    RGB.white.cgColor(alpha: 0.7))
    }

    private static func drawDrop(_ context: CGContext, _ size: CGSize) {
        let radius = size.width / 2 * 0.9
        let center = CGPoint(x: size.width / 2, y: radius + size.width * 0.05)
        let tip = CGPoint(x: size.width / 2, y: size.height * 0.98)
        let path = CGMutablePath()
        path.move(to: tip)
        path.addArc(center: center, radius: radius, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: true)
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(Palette.water.cgColor)
        context.fillPath()
        context.addPath(path)
        context.setStrokeColor(Palette.waterEdge.cgColor)
        context.setLineWidth(size.width * 0.12)
        context.strokePath()
        fillEllipse(context, circle(CGPoint(x: center.x - radius * 0.35, y: center.y + radius * 0.2), radius * 0.25),
                    RGB.white.cgColor(alpha: 0.9))
    }

    // MARK: - Visitors

    private static func drawBee(_ context: CGContext, _ s: CGFloat, wingsUp: Bool) {
        let wing = RGB.white.cgColor(alpha: 0.8)
        let wingEdge = RGB(0x9AA5B1).cgColor
        let wingY = wingsUp ? s * 0.62 : s * 0.5
        for x in [0.42, 0.68] {
            let rect = CGRect(x: s * x - s * 0.17, y: wingY, width: s * 0.34, height: s * (wingsUp ? 0.5 : 0.36))
            fillEllipse(context, rect, wingEdge)
            fillEllipse(context, rect.insetBy(dx: s * 0.03, dy: s * 0.03), wing)
        }
        let body = CGRect(x: s * 0.14, y: s * 0.16, width: s * 1.2, height: s * 0.66)
        fillEllipse(context, body, Palette.ink.cgColor)
        fillEllipse(context, body.insetBy(dx: s * 0.05, dy: s * 0.05), Palette.bee.cgColor)
        context.saveGState()
        context.addEllipse(in: body)
        context.clip()
        context.setFillColor(Palette.ink.cgColor)
        for x in [0.44, 0.74] {
            context.fill(CGRect(x: s * x, y: 0, width: s * 0.14, height: s * 1.2))
        }
        context.restoreGState()
        fillEllipse(context, circle(CGPoint(x: s * 1.12, y: s * 0.56), s * 0.1), RGB.white.cgColor)
        fillEllipse(context, circle(CGPoint(x: s * 1.15, y: s * 0.56), s * 0.06), Palette.ink.cgColor)
    }

    private static func drawAcorn(_ context: CGContext, _ s: CGFloat, cracked: Bool) {
        let nut = CGRect(x: s * 0.12, y: s * 0.04, width: s * 0.6, height: s * 0.72)
        fillEllipse(context, nut, Palette.acornNut.mixed(with: .black, 0.35).cgColor)
        fillEllipse(context, nut.insetBy(dx: s * 0.05, dy: s * 0.05), Palette.acornNut.cgColor)
        fillEllipse(context, CGRect(x: s * 0.24, y: s * 0.3, width: s * 0.12, height: s * 0.24), RGB.white.cgColor(alpha: 0.35))
        if cracked {
            context.setStrokeColor(Palette.ink.cgColor)
            context.setLineWidth(s * 0.06)
            context.move(to: CGPoint(x: s * 0.3, y: s * 0.62))
            context.addLine(to: CGPoint(x: s * 0.44, y: s * 0.44))
            context.addLine(to: CGPoint(x: s * 0.34, y: s * 0.3))
            context.addLine(to: CGPoint(x: s * 0.5, y: s * 0.14))
            context.strokePath()
        }
        let cap = CGRect(x: s * 0.06, y: s * 0.52, width: s * 0.72, height: s * 0.4)
        context.saveGState()
        context.clip(to: CGRect(x: 0, y: s * 0.6, width: s, height: s))
        fillEllipse(context, cap, Palette.acornCap.cgColor)
        context.restoreGState()
        context.setFillColor(Palette.acornCap.cgColor)
        context.fill(CGRect(x: s * 0.06, y: s * 0.6, width: s * 0.72, height: s * 0.1))
        context.setStrokeColor(Palette.acornCap.mixed(with: .black, 0.35).cgColor)
        context.setLineWidth(s * 0.035)
        for x in stride(from: 0.18, through: 0.66, by: 0.12) {
            context.move(to: CGPoint(x: s * x, y: s * 0.62))
            context.addLine(to: CGPoint(x: s * (x + 0.06), y: s * 0.82))
        }
        context.strokePath()
        context.setStrokeColor(Palette.acornCap.cgColor)
        context.setLineWidth(s * 0.08)
        context.move(to: CGPoint(x: s * 0.42, y: s * 0.9))
        context.addLine(to: CGPoint(x: s * 0.5, y: s * 1.0))
        context.strokePath()
    }

    private static func drawShell(_ context: CGContext, center: CGPoint, radius: CGFloat, _ s: CGFloat) {
        fillEllipse(context, circle(center, radius), Palette.shellDark.cgColor)
        fillEllipse(context, circle(center, radius * 0.86), Palette.shell.cgColor)
        context.setStrokeColor(Palette.shellDark.cgColor)
        context.setLineWidth(s * 0.07)
        var angle: CGFloat = 0
        context.move(to: center)
        while angle < .pi * 4.2 {
            let r = radius * 0.75 * angle / (.pi * 4.2)
            context.addLine(to: CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r))
            angle += 0.2
        }
        context.strokePath()
    }

    private static func drawSnail(_ context: CGContext, _ s: CGFloat) {
        let body = Palette.snailBody
        let dark = body.mixed(with: .black, 0.4)
        context.setStrokeColor(dark.cgColor)
        context.setLineWidth(s * 0.05)
        for (base, tip) in [(CGPoint(x: 1.3, y: 0.42), CGPoint(x: 1.38, y: 0.86)), (CGPoint(x: 1.38, y: 0.42), CGPoint(x: 1.52, y: 0.8))] {
            context.move(to: CGPoint(x: base.x * s, y: base.y * s))
            context.addLine(to: CGPoint(x: tip.x * s, y: tip.y * s))
            context.strokePath()
            fillEllipse(context, circle(CGPoint(x: tip.x * s, y: tip.y * s), s * 0.06), Palette.ink.cgColor)
        }
        let foot = CGPath(roundedRect: CGRect(x: s * 0.08, y: s * 0.06, width: s * 1.4, height: s * 0.3),
                          cornerWidth: s * 0.15, cornerHeight: s * 0.15, transform: nil)
        context.addPath(foot)
        context.setFillColor(dark.cgColor)
        context.fillPath()
        context.addPath(CGPath(roundedRect: CGRect(x: s * 0.12, y: s * 0.1, width: s * 1.32, height: s * 0.22),
                               cornerWidth: s * 0.11, cornerHeight: s * 0.11, transform: nil))
        context.setFillColor(body.cgColor)
        context.fillPath()
        fillEllipse(context, circle(CGPoint(x: s * 1.33, y: s * 0.32), s * 0.16), body.cgColor)
        drawShell(context, center: CGPoint(x: s * 0.66, y: s * 0.6), radius: s * 0.42, s)
    }
}
