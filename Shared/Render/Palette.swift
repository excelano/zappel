// Palette.swift
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import CoreGraphics
import SwiftUI

struct RGB: Hashable {
    var red: Double
    var green: Double
    var blue: Double

    init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
    var color: Color { Color(red: red, green: green, blue: blue) }

    func cgColor(alpha: Double) -> CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

    /// Mixes toward another color; 0 keeps this one, 1 gives the other.
    func mixed(with other: RGB, _ amount: Double) -> RGB {
        var result = self
        result.red += (other.red - red) * amount
        result.green += (other.green - green) * amount
        result.blue += (other.blue - blue) * amount
        return result
    }

    static let white = RGB(0xFFFFFF)
    static let black = RGB(0x000000)
}

/// The garden's colors for one time of day.
struct Palette {
    var skyTop: RGB
    var skyBottom: RGB
    var grassLight: RGB
    var grassDark: RGB
    var caterpillar: RGB

    static let times: [Palette] = [
        // Morning
        Palette(skyTop: RGB(0x8FD3F4), skyBottom: RGB(0xD6F0FF), grassLight: RGB(0x5DBB4A), grassDark: RGB(0x4CA63C), caterpillar: RGB(0x7ED957)),
        // Midday
        Palette(skyTop: RGB(0x4FB3F6), skyBottom: RGB(0xA9DCFF), grassLight: RGB(0x52AE3F), grassDark: RGB(0x449A34), caterpillar: RGB(0xFF9F1C)),
        // Afternoon gold
        Palette(skyTop: RGB(0xF6C667), skyBottom: RGB(0xFCE7B2), grassLight: RGB(0x6FA83C), grassDark: RGB(0x5E9332), caterpillar: RGB(0x2EC4B6)),
        // Sunset pink
        Palette(skyTop: RGB(0xF28FAD), skyBottom: RGB(0xFFC7A8), grassLight: RGB(0x4E8F45), grassDark: RGB(0x417B3A), caterpillar: RGB(0xB388EB)),
        // Dusk purple
        Palette(skyTop: RGB(0x4B3F8C), skyBottom: RGB(0x8E6BBF), grassLight: RGB(0x2F6B4A), grassDark: RGB(0x275B3F), caterpillar: RGB(0xFFD23F)),
    ]

    static func forWave(_ wave: Int) -> Palette {
        times[(wave - 1) % times.count]
    }

    static let flowerColors = [RGB(0xFF5D8F), RGB(0xFFFFFF), RGB(0xFFB627), RGB(0xC77DFF)]
    static let flowerCenter = RGB(0xFFD60A)
    static let slippery = RGB(0x4CC9F0)
    static let leaf = RGB(0x2D7A2D)
    static let water = RGB(0x9BE2FF)
    static let waterEdge = RGB(0x3FA7D6)
    static let metal = RGB(0xB8C4CC)
    static let sprinkler = RGB(0xFF6B35)
    static let metalDark = RGB(0x6B7B86)
    static let bee = RGB(0xFFC300)
    static let ink = RGB(0x1B1B1B)
    static let acornCap = RGB(0x7A4B24)
    static let acornNut = RGB(0xC68B4E)
    static let shell = RGB(0xD9822B)
    static let shellDark = RGB(0x8C4F16)
    static let snailBody = RGB(0xA7B89A)
    static let soil = RGB(0x7A5534)
    static let soilEdge = RGB(0x5A3C22)
    static let stone = RGB(0xB5A48E)
}
