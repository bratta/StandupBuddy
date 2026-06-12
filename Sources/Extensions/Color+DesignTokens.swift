import SwiftUI

public extension Color {
    static let cardSurface  = Color(red: 0.219, green: 0.188, blue: 0.180)
    static let codeSurface  = Color(red: 0.149, green: 0.122, blue: 0.118)
    static let inputChipBg  = Color(red: 0.255, green: 0.231, blue: 0.224)
    static let cardBorder   = Color(red: 0.373, green: 0.333, blue: 0.322).opacity(0.5)
    static let softBorder   = Color(red: 0.373, green: 0.333, blue: 0.322).opacity(0.28)
    static let textPrimary  = Color(red: 0.969, green: 0.961, blue: 0.941)
    static let codeText     = Color(red: 0.765, green: 0.725, blue: 0.698)
    static let textTertiary = Color(red: 0.620, green: 0.580, blue: 0.553)
    static let tokVar       = Color(red: 0.471, green: 0.678, blue: 0.937)
    static let tokGroup     = Color(red: 0.431, green: 0.635, blue: 0.910)
    static let tokLabel     = Color(red: 0.918, green: 0.902, blue: 0.863)
    static let tokUrl       = Color(red: 0.745, green: 0.710, blue: 0.678)
    static let tokPunc      = Color(red: 0.592, green: 0.553, blue: 0.529)
    static var accentSoft: Color { .accentColor.opacity(0.16) }
    static var accentLine: Color { .accentColor.opacity(0.42) }
    static let accentDeep   = Color(red: 0.016, green: 0.412, blue: 0.820)
    // Output window design tokens
    static let bgRaised     = Color(red: 0.200, green: 0.169, blue: 0.161)  // #332B29
    static let amber        = Color(red: 0.910, green: 0.635, blue: 0.298)  // #E8A24C
    static let linkBlue     = Color(red: 0.369, green: 0.608, blue: 0.933)  // #5E9BEE
}
