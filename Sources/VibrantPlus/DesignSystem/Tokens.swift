// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Vibrant+ design tokens. «Porzellan trägt, Tinte spricht, Puls zeigt.»
/// Views read colors, radii, durations and sizes from here, never hard-coded.
/// Rosa is only an active state. Text and status colors are at least 4.5:1 on their ground.
enum Brand {
    // Hellmodus
    static let porzellan: UInt32    = 0xF6F5F1 // Haupthintergrund
    static let kreide: UInt32       = 0xFCFCFA // Karten, Popover
    static let leinen: UInt32       = 0xEDECE7 // Gruppen, Seitenleiste
    static let naht: UInt32         = 0xDEDCD5 // 1-px-Trennlinien hell
    static let tinte: UInt32        = 0x1D1D1F // Haupttext, Icon-Linie, Pulsi-Gesicht
    static let stein: UInt32        = 0x5E5D59 // Nebentext hell
    static let kiesel: UInt32       = 0x6E6D68 // Hinweistext hell

    // Dunkelmodus
    static let graphitNacht: UInt32 = 0x141414 // Haupthintergrund dunkel
    static let graphit: UInt32      = 0x1E1E1D // Karten dunkel
    static let schiefer: UInt32     = 0x282827 // Gruppen dunkel
    static let nahtDunkel: UInt32   = 0x3A3A38 // 1-px-Trennlinien dunkel
    static let sand: UInt32         = 0xB4B2AC // Nebentext dunkel
    static let kieselDunkel: UInt32 = 0x8E8C87 // Hinweistext dunkel

    // Akzent & Glow
    static let puls: UInt32          = 0xC2306A // Primärakzent und Primärfläche
    static let pulsHell: UInt32      = 0xF07AA8 // Akzent dunkel und Insel-Text auf Schwarz
    static let pulsGlass: UInt32     = 0xFFB8D5 // Akzenttext auf Rauchglas
    static let bernstein: UInt32     = 0xD98218 // Ruhiger Fehler-Glow hell
    static let bernsteinHell: UInt32 = 0xF5B03E // Ruhiger Fehler-Glow dunkel
    static let bernsteinText: UInt32 = 0x9A5B00 // Warntext hell (4,97 : 1 auf Porzellan)

    // Status text (light / dark). Fills that carry white type use `puls` (5,35 : 1).
    static let erfolg: UInt32        = 0x1E7F45
    static let erfolgHell: UInt32    = 0x4FD07F
    static let gefahr: UInt32        = 0xC8312C
    static let gefahrHell: UInt32    = 0xFF6B63
    static let hinweis: UInt32       = 0x0060C8
    static let hinweisHell: UInt32   = 0x5EA8FF

    // Insel (immer Tiefschwarz)
    static let black: UInt32         = 0x090A0A
}

/// The warm rim around the notch island. One color, soft, never on top of text.
enum GlowSpec {
    static let opacityMin: Double = 0.20
    static let opacityMax: Double = 0.30
    static let opacityStatic: Double = 0.24
    static let blurRadius: CGFloat = 16
    static let lineWidth: CGFloat = 2
    static let breathPeriod: TimeInterval = 2.4
    static let fadeOutDuration: TimeInterval = 0.30
    static let successPulseDuration: TimeInterval = 0.45
}

/// Window and card colors. Light and dark follow the Mac.
enum Surface {
    static let window = Color(light: Brand.porzellan, dark: Brand.graphitNacht)
    static let card = Color(light: Brand.kreide, dark: Brand.graphit)
    static let grouped = Color(light: Brand.leinen, dark: Brand.schiefer)
    static let hairline = Color(light: Brand.naht, dark: Brand.nahtDunkel)
    static let text = Color(light: Brand.tinte, dark: Brand.porzellan)
    static let secondary = Color(light: Brand.stein, dark: Brand.sand)
    static let tertiary = Color(light: Brand.kiesel, dark: Brand.kieselDunkel)
    static let accentFill = Color(hex: Brand.puls)
    static let success = Color(light: Brand.erfolg, dark: Brand.erfolgHell)
    static let warning = Color(light: Brand.bernsteinText, dark: Brand.bernsteinHell)
    static let danger = Color(light: Brand.gefahr, dark: Brand.gefahrHell)
    static let info = Color(light: Brand.hinweis, dark: Brand.hinweisHell)
}

/// The island's look. The island is always Black (Brandguide 09: «Insel immer Black, in Light und Dark»),
/// closed or open. «Liquid Glass» is smoked glass: solid black beside the notch, glass below it, in light and dark.
enum IslandStyle: String, CaseIterable, Identifiable, Codable {
    case notch, glass
    var id: String { rawValue }
    var title: String {
        switch self {
        case .notch: "Notch-Schwarz"
        case .glass: "Liquid Glass"
        }
    }
}

/// One set of island colors.
struct IslandPalette: Equatable {
    /// The solid ground: the island in Notch-Schwarz, and what Liquid Glass falls back to.
    var background: Color
    var card: Color
    /// Controls that sit on a card: pills, round buttons, the selected page.
    var cardHover: Color
    /// Laid over a card under the pointer. Not `cardHover`: the controls on the card would vanish in it.
    var hoverVeil: Color
    var cardWarm: Color
    var primaryText: Color
    var secondaryText: Color
    var tertiaryText: Color
    var accent: Color
    /// A fill that carries text: a shade deeper than the accent, so small white type passes 4.5:1.
    var accentFill: Color
    /// Der Akzent als Text: heller als Puls, damit kleine Schrift auf Karten lesbar bleibt.
    var accentText: Color
    var onAccent: Color
    var warm: Color
    var warmFill: Color
    var onWarm: Color
    var separator: Color
    /// Text fields and code inside cards.
    var field: Color
    var danger: Color
    var dot: Color
    /// The edge of a card where it catches the light, and where it turns away from it.
    var rimLight: Color
    var rimShade: Color
    var scheme: ColorScheme

    /// The brand island: deep black, in light and dark mode. Porcelain text, Puls for what is active.
    static let notch = IslandPalette(
        background: Color(hex: Brand.black),
        card: Color(hex: Brand.schiefer).opacity(0.72),
        cardHover: Color(hex: Brand.schiefer),
        hoverVeil: Color(hex: Brand.porzellan).opacity(0.04),
        cardWarm: Color(hex: Brand.schiefer).opacity(0.72),
        primaryText: Color(hex: Brand.porzellan),
        secondaryText: Color(hex: Brand.sand),
        tertiaryText: Color(hex: Brand.kieselDunkel),
        accent: Color(hex: Brand.puls),
        accentFill: Color(hex: Brand.puls),
        accentText: Color(hex: Brand.pulsHell),
        onAccent: .white,
        warm: Color(hex: Brand.bernsteinHell),
        // «Immer erlauben» is a bigger yes than «Erlauben»: amber, not the primary fill.
        warmFill: Color(hex: Brand.bernsteinHell).opacity(0.22),
        onWarm: Color(hex: Brand.porzellan),
        separator: Color(hex: Brand.porzellan).opacity(0.10),
        field: Color(hex: Brand.black).opacity(0.35),
        danger: Color(hex: Brand.gefahrHell),
        dot: Color(hex: Brand.puls),
        rimLight: Color(hex: Brand.porzellan).opacity(0.08),
        rimShade: Color(hex: Brand.porzellan).opacity(0.03),
        scheme: .dark)

    /// Liquid Glass. The island's body is the one glass layer, smoked so text holds over any window;
    /// cards are clear panes lying in it (glass is never stacked on glass).
    static let glass: IslandPalette = {
        var p = IslandPalette.notch
        p.card = Color.white.opacity(0.08)
        p.cardWarm = Color.white.opacity(0.08)
        p.cardHover = Color.white.opacity(0.16)
        p.hoverVeil = Color.white.opacity(0.05)
        p.secondaryText = Color.white.opacity(0.9)
        p.tertiaryText = Color.white.opacity(0.8)
        p.accentText = Color(hex: Brand.pulsGlass)
        p.warm = Color(hex: Brand.pulsGlass)
        p.separator = Color.white.opacity(0.16)
        p.field = Color.black.opacity(0.28)
        p.rimLight = Color.white.opacity(0.42)
        p.rimShade = Color.white.opacity(0.05)
        return p
    }()

    /// System Settings › Accessibility › Display › Increase contrast: secondary text, hints and
    /// lines move close to the primary text color, so nothing relies on a faint grey.
    func increasedContrast() -> IslandPalette {
        var p = self
        p.secondaryText = primaryText.opacity(0.94)
        p.tertiaryText = primaryText.opacity(0.86)
        p.separator = primaryText.opacity(0.35)
        // Plain lines instead of light play.
        p.rimLight = p.separator
        p.rimShade = p.separator
        return p
    }
}

/// The current island style. Views read IslandColor, which reads this, so they redraw on change.
@Observable
final class IslandTheme {
    static let shared = IslandTheme()
    var style: IslandStyle {
        didSet {
            // Snapshots switch the style; they must not write it into the person's settings.
            guard !Paths.isOverridden else { return }
            UserDefaults.standard.set(style.rawValue, forKey: "island.style")
        }
    }
    private(set) var increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    private(set) var reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency

    /// Glass is really drawn: not with Reduce transparency or Increase contrast, where the ground is solid.
    var drawsGlass: Bool { style == .glass && !reduceTransparency && !increaseContrast }

    var palette: IslandPalette {
        var base: IslandPalette = drawsGlass ? .glass : .notch
        // Puls picked by hand keeps the readable Puls text tones above.
        if let accent = ThemeStore.shared.chosen, let shades = accent.shades, shades.base != Brand.puls {
            base.accent = Color(hex: shades.base)
            base.accentFill = base.accent
            base.accentText = Color(hex: shades.light)
            base.onAccent = accent.onAccent
            base.dot = base.accent
        }
        return increaseContrast ? base.increasedContrast() : base
    }

    private init() {
        style = IslandStyle(rawValue: ProcessInfo.processInfo.environment["APP_ISLAND_STYLE"]
            ?? UserDefaults.standard.string(forKey: "island.style") ?? "") ?? .notch
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
                self?.reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            }
        }
    }

    /// For snapshots.
    func setIncreaseContrast(_ on: Bool) { increaseContrast = on }
    func setReduceTransparency(_ on: Bool) { reduceTransparency = on }
}

/// Colors for the island, the dial, Today and the assistant. They follow IslandTheme.
enum IslandColor {
    private static var p: IslandPalette { IslandTheme.shared.palette }
    static var background: Color { p.background }
    static var card: Color { p.card }
    static var cardHover: Color { p.cardHover }
    static var hoverVeil: Color { p.hoverVeil }
    static var accentFill: Color { p.accentFill }
    static var rimLight: Color { p.rimLight }
    static var rimShade: Color { p.rimShade }
    /// The second card tone (Grau in the brand, no pastel).
    static var cardWarm: Color { p.cardWarm }
    static var primaryText: Color { p.primaryText }
    static var secondaryText: Color { p.secondaryText }
    static var tertiaryText: Color { p.tertiaryText }
    static var accent: Color { p.accent }
    /// Puls as text: darker on light grounds so small type stays above 4.5:1.
    static var accentText: Color { p.accentText }
    static var onAccent: Color { p.onAccent }
    /// Attention as text or icon (permissions, reminders).
    static var warm: Color { p.warm }
    /// Attention as a surface (buttons).
    static var warmFill: Color { p.warmFill }
    static var onWarm: Color { p.onWarm }
    static var separator: Color { p.separator }
    static var field: Color { p.field }
    static var danger: Color { p.danger }
    /// The orange point: titles may end with it. Never a surface.
    static var dot: Color { p.dot }
    static var scheme: ColorScheme { p.scheme }
}

extension View {
    /// A card in the island: a pane with light on its upper edge. In Liquid Glass the pane also carries
    /// a soft sheen; the glass itself is the island's body, so there is never glass on glass.
    func islandSurface(_ shape: some InsettableShape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous),
                       tone: IslandSurfaceTone = .card) -> some View {
        let glass = IslandTheme.shared.drawsGlass
        return self
            .background {
                shape.fill(tone == .warm ? IslandColor.cardWarm : IslandColor.card)
                if glass {
                    shape.fill(LinearGradient(colors: [.white.opacity(Glass.sheen), .clear], startPoint: .top, endPoint: .center))
                }
            }
            .overlay {
                // Light comes from the top left and leaves a faint echo in the far corner.
                shape.strokeBorder(LinearGradient(stops: [.init(color: IslandColor.rimLight, location: 0),
                                                          .init(color: IslandColor.rimShade, location: 0.45),
                                                          .init(color: IslandColor.rimShade, location: 0.75),
                                                          .init(color: IslandColor.rimLight.opacity(Glass.rimEcho), location: 1)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

enum IslandSurfaceTone { case card, warm }

extension View {
    /// The island's own body. Closed, it is always black so it melts into the notch. Open in Liquid
    /// Glass it stays black for `band` points (the camera housing is black) and turns to smoked glass below.
    @ViewBuilder
    func islandBackground(_ shape: some Shape, open: Bool, band: CGFloat = 0) -> some View {
        if !open {
            self.background(Color(hex: Brand.black), in: shape)
        } else if IslandTheme.shared.drawsGlass {
            self.background { GlassSmoke(band: band).clipShape(shape).allowsHitTesting(false) }
                .glassEffect(.regular, in: shape)
        } else {
            self.background(IslandColor.background, in: shape)
        }
    }
}

/// Values of the Liquid Glass island.
enum Glass {
    /// How much black lies in the glass: enough that white 10 pt type holds over a white window.
    static let smoke = 0.65
    /// The way from the black band to the smoke.
    static let melt: CGFloat = 24
    static let sheen = 0.05
    static let rimEcho = 0.45
}

/// Black as high as the notch, then a short melt into smoke.
private struct GlassSmoke: View {
    var band: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            if band > 0 {
                Color(hex: Brand.black).frame(height: band)
                LinearGradient(colors: [Color(hex: Brand.black), Color(hex: Brand.black).opacity(Glass.smoke)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: Glass.melt)
            }
            Color(hex: Brand.black).opacity(Glass.smoke)
        }
    }
}

enum Radius {
    static let island: CGFloat = 24
    static let card: CGFloat = 12
    static let control: CGFloat = 8
    static let chip: CGFloat = 8
    /// Sheets and floating windows.
    static let sheet: CGFloat = 16
}

enum Motion {
    /// Opening and closing the island.
    /// A soft landing with a hint of overshoot, like the island on the iPhone.
    static let island = Animation.spring(response: 0.36, dampingFraction: 0.86)
    /// Closing is a little quicker than opening: it should get out of the way.
    static let islandClose = Animation.spring(response: 0.22, dampingFraction: 1.0)
    /// Another page: nothing was thrown, so nothing bounces.
    static let page = Animation.spring(response: 0.28, dampingFraction: 1.0)
    /// How far a new page comes from the side it lives on.
    static let pageTravel: CGFloat = 16
    /// Small state changes inside cards.
    static let quick = Animation.easeOut(duration: 0.14)
    static let fade = Animation.easeInOut(duration: 0.24)
    /// The open island's content: it fades in just after the shape starts to grow,
    /// and out quickly so the shape can close around nothing.
    static let contentIn = Animation.easeOut(duration: 0.2).delay(0.04)
    static let contentOut = Animation.easeIn(duration: 0.08)
    /// One way of the light over the open island's edge (left shoulder to right, or back).
    static let glowLoopPeriod: TimeInterval = 2.4
    /// «Claude arbeitet»: a slow breath. With the light over the open island, the only motions that repeat.
    static let pulse = Animation.easeInOut(duration: 0.9).repeatForever()
    /// Buttons give way a little under the pointer.
    static let press = Animation.easeOut(duration: 0.1)
    static let pressScale: CGFloat = 0.97
    /// The open island's content grows out of the notch with the shape: it starts a little smaller.
    static let contentScale: CGFloat = 0.97
    /// The whole island starts this much smaller when it opens.
    static let growScale: CGFloat = 0.94
    /// The equalizer's frame interval.
    static let equalizerInterval: TimeInterval = 0.18
    /// The voice level beside the notch follows the microphone: a little quicker.
    static let voiceLevelInterval: TimeInterval = 0.06

    /// AppKit panels (scrim, dial, app grid): in a little slower than out.
    static let panelIn: TimeInterval = 0.18
    static let panelOut: TimeInterval = 0.14

    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Respects System Settings > Accessibility > Display > Reduce motion.
    static func respecting(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }

    /// A panel duration, or 0 with Reduce motion.
    static func duration(_ seconds: TimeInterval) -> TimeInterval {
        reduceMotion ? 0 : seconds
    }
}

enum Shadow {
    /// A card, barely lifted. Dark mode uses the 1 pt light edge (`rimLight`) instead.
    static let card = Color.black.opacity(0.06)
    static let cardRadius: CGFloat = 3
    static let cardY: CGFloat = 1
    /// A floating container, such as the open island over the desktop.
    static let float = Color.black.opacity(0.10)
    static let floatRadius: CGFloat = 30
    static let floatY: CGFloat = 12
}

/// Layout metrics for the island and the edge dial.
enum Metrics {
    /// The widest the open island gets: the pages (four tiles side by side).
    static let islandWidth: CGFloat = 656
    /// A single card (a request from Claude, a reminder, the drop zones) needs less.
    static let islandCardWidth: CGFloat = 520
    static let islandHeight: CGFloat = 172
    /// The island panel's fixed height: the tallest the open island gets.
    static let islandMaxHeight: CGFloat = 520
    /// Around the open island's content. Card radius (12) + padding (12) = island radius (24): the corners run parallel.
    static let islandPadding: CGFloat = Space.md
    /// What a page has to lay out its cards.
    static let islandContentWidth: CGFloat = islandWidth - islandPadding * 2
    /// The band beside the notch holds the page tabs; it is never lower than this.
    static let islandBandMinHeight: CGFloat = 32
    static let tileWidth: CGFloat = 152
    /// Every card header is this high, with or without a button in it: the first lines of all cards align.
    static let cardHeaderHeight: CGFloat = 20
    static let tileHeight: CGFloat = 128
    static let wideTileWidth: CGFloat = 312
    /// The Today cards hold lists and a note: a little taller than a tile.
    static let todayCardHeight: CGFloat = 148
    static let compactPillExtra: CGFloat = 92
    /// The widest a wing grows for a long note (both sides, so the notch stays in the middle).
    static let toastWingWidth: CGFloat = 220
    static let dialPanelWidth: CGFloat = 300
    static let dialTabWidth: CGFloat = 6
    static let dialTabHeight: CGFloat = 132
    /// The permission card's text box scrolls beyond this height (about 9 lines of code).
    static let permissionBodyMaxHeight: CGFloat = 148
}

/// Type styles. System fonts so Dynamic Type and accessibility sizes work.
enum TypeStyle {
    static let largeTitle = Font.system(size: 26, weight: .bold)
    static let title = Font.system(size: 20, weight: .semibold)
    static let headline = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 13)
    static let callout = Font.system(size: 12)
    static let footnote = Font.system(size: 11)
    static let caption = Font.system(size: 10, weight: .medium)
    static let islandTitle = Font.system(size: 13, weight: .semibold)
    static let islandBody = Font.system(size: 12)
    static let islandCaption = Font.system(size: 11)
    static let islandLabel = Font.system(size: 10, weight: .medium)
    /// The smallest text Vibrant+ draws (legends, file names, small values). Nothing goes below 10 pt.
    static let islandMicro = Font.system(size: 10)
    static let islandMicroNumber = Font.system(size: 10).monospacedDigit()
    static let islandNumber = Font.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit()
    static let islandTimer = Font.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit()
    /// Commands, paths and tool input.
    static let islandCode = Font.system(size: 11, design: .monospaced)
    static let islandTab = Font.system(size: 12, weight: .semibold)
    static let islandTabSmall = Font.system(size: 10, weight: .semibold)
    static let islandEmptySymbol = Font.system(size: 16, weight: .medium)
}

extension EnvironmentValues {
    /// The tile the card belongs to is set to «Breit» (see Prefs.wideTiles).
    @Entry var tileWide = false
}

/// A card inside the island.
struct IslandCard<Content: View>: View {
    var width: CGFloat = Metrics.tileWidth
    var height: CGFloat = Metrics.tileHeight
    /// A soft color from the top-left corner (the music cover's color), across the whole card.
    var glow: Color? = nil
    @ViewBuilder var content: Content
    @State private var hovering = false
    @Environment(\.tileWide) private var wide

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        content
            .padding(Space.md)
            .frame(width: wide ? max(width, Metrics.wideTileWidth) : width, height: height, alignment: .topLeading)
            // Hover sits on top of the card fill: a background added after `islandSurface`
            // would land behind it and stay invisible on opaque cards.
            .background(hovering ? IslandColor.hoverVeil : Color.clear, in: shape)
            .background {
                if let glow {
                    RadialGradient(colors: [glow.opacity(0.35), .clear], center: .topLeading, startRadius: 0, endRadius: 260)
                        .clipShape(shape)
                        .allowsHitTesting(false)
                }
            }
            .islandSurface()
            .onHover { h in withAnimation(Motion.respecting(Motion.quick)) { hovering = h } }
    }
}

/// A thin level bar (CPU, memory): a track in the field color, the level in the accent.
struct IslandBar: View {
    /// 0 … 1.
    var value: Double
    var tint: Color = IslandColor.accent

    var body: some View {
        Capsule().fill(IslandColor.cardHover)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule().fill(tint).frame(width: max(4, geo.size.width * min(1, max(0, value))))
                }
            }
            .accessibilityHidden(true)
    }
}

/// A small progress ring for the wing beside the notch (a download under way).
struct IslandRing: View {
    /// 0 … 1.
    var value: Double
    var tint: Color = IslandColor.accent
    var track: Color = IslandColor.cardHover

    var body: some View {
        Circle().stroke(track, lineWidth: 2)
            .overlay {
                Circle().trim(from: 0, to: min(1, max(0, value)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(Motion.respecting(Motion.quick), value: value)
            }
            .frame(width: 12, height: 12)
            .accessibilityHidden(true)
    }
}

/// The small header line on top of a card: symbol + label.
struct CardHeader: View {
    var title: String
    var symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(TypeStyle.islandLabel)
            .foregroundStyle(IslandColor.secondaryText)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .frame(height: Metrics.cardHeaderHeight)
    }
}

/// What an empty card says: what belongs here, centered in the room below the header.
struct IslandEmpty: View {
    var symbol: String
    var text: String

    var body: some View {
        VStack(spacing: Space.xs) {
            PulsiImage(pose: .leerzustand, height: 44, fallbackSymbol: symbol)
            Text(text)
                .font(TypeStyle.islandCaption)
                .foregroundStyle(IslandColor.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A round icon button for the island.
struct IslandIconButton: View {
    var symbol: String
    var label: String
    var size: CGFloat = 28
    var prominent = false
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
                .foregroundStyle(prominent ? IslandColor.onAccent : IslandColor.primaryText)
                .background(hovering ? IslandColor.hoverVeil : Color.clear, in: Circle())
                .background(prominent ? IslandColor.accentFill : IslandColor.cardHover, in: Circle())
        }
        .buttonStyle(IslandPressStyle())
        .help(label)
        .accessibilityLabel(label)
        .onHover { hovering = $0 }
    }
}

/// How every island button reacts: it gives way a little while pressed (no scale with
/// Reduce motion, only a darker tone) and fades when disabled.
struct IslandPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? Motion.pressScale : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(Motion.press, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// A capsule text button for the island ("Erlauben", "Beitreten").
struct IslandPillButton: View {
    enum Kind { case primary, secondary, warm, danger }
    var title: String
    var kind: Kind = .secondary
    /// Fills the width it is given (a grid of equal buttons).
    var expands = false
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypeStyle.islandCaption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, expands ? Space.xs : Space.md)
                .padding(.vertical, Space.xs + 2)
                .frame(maxWidth: expands ? .infinity : nil)
                .foregroundStyle(foreground)
                // Hover lightens: it never lowers the contrast of the label.
                .background(hovering ? IslandColor.hoverVeil : Color.clear, in: Capsule())
                .background(background, in: Capsule())
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering = $0 }
    }

    private var foreground: Color {
        switch kind {
        case .primary: IslandColor.onAccent
        case .warm: IslandColor.onWarm
        case .secondary, .danger: IslandColor.primaryText
        }
    }

    private var background: Color {
        switch kind {
        case .primary: IslandColor.accentFill
        case .warm: IslandColor.warmFill
        case .secondary: IslandColor.cardHover
        case .danger: IslandColor.danger.opacity(0.35)
        }
    }
}

/// The Vibrant+ mark: the pulse line of icon A on the 1024 grid, stroke 64, round ends.
/// Drawn in code so it stays sharp at every size and works as a template image in the menu bar.
/// The pink dot stays out of the template: the menu bar tints the whole mark.
nonisolated struct VibrantMark: Shape {
    func path(in rect: CGRect) -> Path {
        let outline = Self.outline
        let box = outline.boundingBoxOfPath
        let s = min(rect.width / box.width, rect.height / box.height)
        let t = CGAffineTransform(translationX: rect.midX - box.midX * s, y: rect.midY - box.midY * s).scaledBy(x: s, y: s)
        return Path(outline.copy(using: [t]) ?? outline)
    }

    /// Width / height of the mark.
    static var aspectRatio: CGFloat {
        let box = outline.boundingBoxOfPath
        return box.height > 0 ? box.width / box.height : 1
    }

    /// The stroked pulse line: centre line from icon A, stroke 64, round caps and joins.
    private nonisolated(unsafe) static let outline: CGPath = {
        let line = CGMutablePath()
        line.move(to: CGPoint(x: 232, y: 540))
        for (x, y) in [(400, 540), (444, 318), (548, 742), (616, 430), (664, 540), (736, 540)] {
            line.addLine(to: CGPoint(x: x, y: y))
        }
        return line.copy(strokingWithWidth: 64, lineCap: .round, lineJoin: .round, miterLimit: 10)
    }()
}

@MainActor extension VibrantMark {
    /// The mark as a template image: black with alpha, macOS tints it for the menu bar.
    static func menuBarImage(height: CGFloat = 15) -> NSImage {
        let width = height * aspectRatio
        let image = NSImage(size: NSSize(width: width, height: height), flipped: true) { rect in
            let path = NSBezierPath(cgPath: VibrantMark().path(in: rect).cgPath)
            path.windingRule = .nonZero
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Vibrant+"
        return image
    }
}

/// The island's outline: a flat top flush with the screen edge, small concave shoulders
/// where it meets the menu bar (like the notch itself), and round bottom corners.
/// The shoulders sit outside the body: the shape is `2 × shoulder` wider than the body.
nonisolated struct IslandShape: Shape {
    var radius: CGFloat
    var shoulder: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(radius, shoulder) }
        set { radius = newValue.first; shoulder = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = outline(in: rect)
        p.closeSubpath()
        return p
    }

    /// The visible edge only: from the left shoulder around the bottom to the right one. The top lies
    /// on the display's edge, where a stroke or a light would not be seen.
    func outline(in rect: CGRect) -> Path {
        let s = max(0, min(shoulder, rect.width / 4, rect.height / 2))
        let left = rect.minX + s, right = rect.maxX - s, bottom = rect.maxY
        // A continuous corner, like the cards': it leaves the straight edge a little earlier than a circle would.
        let reach = max(0, min(radius * Self.cornerReach, (right - left) / 2, rect.height - s))
        let pull = reach * Self.cornerPull
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Left shoulder: curves inward from the top edge down into the body.
        p.addQuadCurve(to: CGPoint(x: left, y: rect.minY + s), control: CGPoint(x: left, y: rect.minY))
        p.addLine(to: CGPoint(x: left, y: bottom - reach))
        p.addCurve(to: CGPoint(x: left + reach, y: bottom),
                   control1: CGPoint(x: left, y: bottom - pull), control2: CGPoint(x: left + pull, y: bottom))
        p.addLine(to: CGPoint(x: right - reach, y: bottom))
        p.addCurve(to: CGPoint(x: right, y: bottom - reach),
                   control1: CGPoint(x: right - pull, y: bottom), control2: CGPoint(x: right, y: bottom - pull))
        p.addLine(to: CGPoint(x: right, y: rect.minY + s))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: right, y: rect.minY))
        return p
    }

    private static let cornerReach: CGFloat = 1.28
    private static let cornerPull: CGFloat = 0.3
}

/// The island's edge without its top, for strokes and light.
nonisolated struct IslandOutline: Shape {
    var island: IslandShape

    var animatableData: IslandShape.AnimatableData {
        get { island.animatableData }
        set { island.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path { island.outline(in: rect) }
}
