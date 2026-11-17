// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Vibrant+ design tokens, Brandguide Vibrant+ V1.0 (14.11.2026): «Grau trägt. Puls zeigt.»
/// Views read colors, radii, durations and sizes from here, never hard-coded.
enum Brand {
    // Surfaces (Brandguide 04, light / dark).
    static let offWhite: UInt32 = 0xFDFDFC     // Hintergrund hell, Karte hell, Text dunkel
    static let grouped: UInt32 = 0xF0F0EE      // Gruppenfläche, Seitenleiste hell
    static let hairline: UInt32 = 0xD9DAD8     // Trennlinie hell, Text-2 dunkel
    static let black: UInt32 = 0x090A0A        // Insel, Hintergrund dunkel, Text hell
    static let graphite: UInt32 = 0x2A2C2C     // Karte dunkel, Trennlinie dunkel
    static let grey: UInt32 = 0x6B6E6D         // Text-2 hell, Bedienelement-Rand
    static let lightGrey: UInt32 = 0xD9DAD8   // Text-2 dunkel
    /// Akzent «Puls»: Ereignis, Fokus, Status. Gleich in Light und Dark.
    static let puls: UInt32 = 0xD63C7A
    /// Puls für Text auf hellem Grund: Puls selbst kommt dort nur auf 4,3:1, das reicht für
    /// kleine Schrift nicht (WCAG AA verlangt 4,5:1). Diese Spur ist gleich dunkler, nicht bunter.
    static let pulsInk: UInt32 = 0xC9326F
    // Pastell (Himmel, Pfirsich, Rosé) gehört nur ins Icon und in Werbebilder, nie in eine Oberfläche.
}

/// The island's look. The island is always Black (Brandguide 09: «Insel immer Black, in Light und Dark»),
/// closed or open. «Liquid Glass» is the macOS 26 glass material, with Brand colors for text and accent.
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
    var background: Color
    var card: Color
    var cardHover: Color
    var cardWarm: Color
    var primaryText: Color
    var secondaryText: Color
    var tertiaryText: Color
    var accent: Color
    /// Der Akzent als Text: auf hellem Grund dunkler, damit kleine Schrift lesbar bleibt.
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
    var scheme: ColorScheme

    /// The brand island: Black, in light and dark mode. Graphite layers, Off-White text, Puls for events and focus.
    static let notch = IslandPalette(
        background: .black,
        card: Color(hex: Brand.graphite).opacity(0.55),
        cardHover: Color(hex: Brand.graphite).opacity(0.85),
        cardWarm: Color(hex: Brand.graphite).opacity(0.55),
        primaryText: Color(hex: Brand.offWhite),
        secondaryText: Color(hex: Brand.lightGrey),
        tertiaryText: Color(hex: Brand.lightGrey).opacity(0.7),
        accent: Color(hex: Brand.puls),
        accentText: Color(hex: Brand.puls),
        onAccent: Color(hex: Brand.offWhite),
        warm: Color(hex: Brand.puls),
        warmFill: Color(hex: Brand.puls),
        onWarm: Color(hex: Brand.offWhite),
        separator: Color(hex: Brand.offWhite).opacity(0.1),
        field: Color.black.opacity(0.35),
        danger: Color(hex: Brand.puls),
        dot: Color(hex: Brand.puls),
        scheme: .dark)

    /// Brand, light: Off-White ground, Grau for cards. Pastel is never a surface.
    static let light = IslandPalette(
        background: Color(hex: Brand.offWhite),
        card: Color(hex: Brand.grouped),
        cardHover: Color(hex: Brand.hairline),
        cardWarm: Color(hex: Brand.grouped),
        primaryText: Color(hex: Brand.black),
        secondaryText: Color(hex: Brand.grey),
        tertiaryText: Color(hex: Brand.grey).opacity(0.8),
        accent: Color(hex: Brand.puls),
        accentText: Color(hex: Brand.pulsInk),
        onAccent: Color(hex: Brand.offWhite),
        warm: Color(hex: Brand.pulsInk),
        warmFill: Color(hex: Brand.puls),
        onWarm: Color(hex: Brand.offWhite),
        separator: Color(hex: Brand.black).opacity(0.1),
        field: Color(hex: Brand.offWhite).opacity(0.75),
        danger: Color(hex: Brand.puls),
        dot: Color(hex: Brand.puls),
        scheme: .light)

    /// Brand, dark: Black ground (never #000 in text), Graphite layers, Off-White text.
    static let dark = IslandPalette(
        background: Color(hex: Brand.black),
        card: Color(hex: Brand.graphite),
        cardHover: Color(hex: 0x37393A),
        cardWarm: Color(hex: Brand.graphite),
        primaryText: Color(hex: Brand.offWhite),
        secondaryText: Color(hex: Brand.lightGrey),
        tertiaryText: Color(hex: Brand.lightGrey).opacity(0.7),
        accent: Color(hex: Brand.puls),
        accentText: Color(hex: Brand.puls),
        onAccent: Color(hex: Brand.offWhite),
        warm: Color(hex: Brand.puls),
        warmFill: Color(hex: Brand.puls),
        onWarm: Color(hex: Brand.offWhite),
        separator: Color(hex: Brand.offWhite).opacity(0.1),
        field: Color(hex: Brand.black).opacity(0.45),
        danger: Color(hex: Brand.puls),
        dot: Color(hex: Brand.puls),
        scheme: .dark)
}

extension IslandPalette {
    /// System Settings › Accessibility › Display › Increase contrast: secondary text, hints and
    /// lines move close to the primary text color, so nothing relies on a faint grey.
    func increasedContrast() -> IslandPalette {
        var p = self
        p.secondaryText = primaryText.opacity(0.9)
        p.tertiaryText = primaryText.opacity(0.78)
        p.separator = primaryText.opacity(0.35)
        return p
    }

    /// Liquid Glass: the surfaces are Apple's glass material (drawn by `islandSurface`), so the
    /// palette only carries text, accent and a faint tint for hover. Text follows light/dark.
    static func glass(dark: Bool) -> IslandPalette {
        var p = dark ? IslandPalette.dark : IslandPalette.light
        p.background = .clear
        p.card = .clear
        p.cardWarm = .clear
        p.cardHover = (dark ? Color.white : Color.black).opacity(0.14)
        p.field = (dark ? Color.black : Color.white).opacity(dark ? 0.28 : 0.45)
        p.accent = Color.accentColor
        p.accentText = Color.accentColor
        p.onAccent = .white
        p.warm = Color(hex: Brand.puls)
        p.warmFill = (dark ? Color.white : Color.black).opacity(0.14)
        p.onWarm = p.primaryText
        p.secondaryText = dark ? Color.white.opacity(0.75) : Color.black.opacity(0.65)
        return p
    }
}

/// The current island style. Views read IslandColor, which reads this, so they redraw on change.
@Observable
final class IslandTheme {
    static let shared = IslandTheme()
    var style: IslandStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "island.style") }
    }
    private(set) var macIsDark = IslandTheme.readMacDark()
    private(set) var increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast

    var palette: IslandPalette {
        var base: IslandPalette = switch style {
        case .notch: .notch
        case .glass: .glass(dark: macIsDark)
        }
        if let accent = ThemeStore.shared.chosen, let shades = accent.shades {
            base.accent = Color(hex: shades.base)
            base.accentText = Color(hex: base.scheme == .dark ? shades.light : shades.deep)
            base.onAccent = accent.onAccent
            base.dot = base.accent
        }
        return increaseContrast ? base.increasedContrast() : base
    }

    private init() {
        style = IslandStyle(rawValue: ProcessInfo.processInfo.environment["APP_ISLAND_STYLE"]
            ?? UserDefaults.standard.string(forKey: "island.style") ?? "") ?? .notch
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
                                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.macIsDark = IslandTheme.readMacDark() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast }
        }
    }

    /// For snapshots.
    func setMacDark(_ dark: Bool) { macIsDark = dark }
    func setIncreaseContrast(_ on: Bool) { increaseContrast = on }

    private static func readMacDark() -> Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }
}

/// Colors for the island, the dial, Today and the assistant. They follow IslandTheme.
enum IslandColor {
    private static var p: IslandPalette { IslandTheme.shared.palette }
    static var background: Color { p.background }
    static var card: Color { p.card }
    static var cardHover: Color { p.cardHover }
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
    static var isGlass: Bool { IslandTheme.shared.style == .glass }
}

extension View {
    /// A card surface for the island: the flat palette color, or a soft tint in Liquid Glass.
    func islandSurface(_ shape: some InsettableShape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous),
                       tone: IslandSurfaceTone = .card) -> some View {
        // Cards sit on the island body. In Liquid Glass the body is the glass, so cards are only a
        // soft tint on it (glass is never stacked on glass).
        let fill: Color = IslandColor.isGlass
            ? (IslandColor.scheme == .dark ? Color.white : Color.black).opacity(tone == .warm ? 0.14 : 0.09)
            : (tone == .warm ? IslandColor.cardWarm : IslandColor.card)
        // A hairline that catches light at the top edge lifts the card off the ground
        // (not in Liquid Glass, and not with Increase contrast, where lines have to be plain).
        let rim: Color = IslandColor.isGlass || IslandTheme.shared.increaseContrast ? .clear
            : (IslandColor.scheme == .dark ? Color.white : Color.black)
        return self.background(fill, in: shape)
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [rim.opacity(Shadow.rimTop), rim.opacity(Shadow.rimBottom)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

enum IslandSurfaceTone { case card, warm }

extension View {
    /// The island's own body. Closed, it is always black so it melts into the notch; open, it is
    /// the palette ground, or Liquid Glass in the glass style.
    @ViewBuilder
    func islandBackground(_ shape: some Shape, open: Bool) -> some View {
        if !open {
            self.background(Color.black, in: shape)
        } else if IslandColor.isGlass && !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(IslandColor.isGlass ? (IslandColor.scheme == .dark ? Color(hex: Brand.black) : Color(hex: Brand.offWhite)) : IslandColor.background, in: shape)
        }
    }
}

enum Radius {
    static let island: CGFloat = 24
    static let card: CGFloat = 12
    static let control: CGFloat = 8
    static let chip: CGFloat = 6
}

enum Motion {
    /// Opening and closing the island.
    /// A soft landing with a hint of overshoot, like the island on the iPhone.
    static let island = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// Closing is a little quicker than opening: it should get out of the way.
    static let islandClose = Animation.spring(response: 0.18, dampingFraction: 1.0)
    /// Small state changes inside cards.
    static let quick = Animation.easeOut(duration: 0.14)
    static let fade = Animation.easeInOut(duration: 0.24)
    /// The open island's content: it fades in just after the shape starts to grow,
    /// and out quickly so the shape can close around nothing.
    static let contentIn = Animation.easeOut(duration: 0.26).delay(0.08)
    static let contentOut = Animation.easeIn(duration: 0.08)
    /// «Claude arbeitet»: a slow breath, the only motion that repeats.
    static let pulse = Animation.easeInOut(duration: 0.9).repeatForever()
    /// Buttons give way a little under the pointer.
    static let press = Animation.easeOut(duration: 0.1)
    static let pressScale: CGFloat = 0.97
    /// The open island's content grows out of the notch with the shape: it starts a little smaller.
    static let contentScale: CGFloat = 0.94
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
    /// The open island floats: one wide, soft shadow.
    static let card = Color.black.opacity(0.32)
    static let cardRadius: CGFloat = 20
    static let cardY: CGFloat = 8
    /// The light hairline around island cards: stronger at the top edge.
    static let rimTop = 0.1
    static let rimBottom = 0.02
}

/// Layout metrics for the island and the edge dial.
enum Metrics {
    /// The widest the open island gets: the pages (four tiles side by side).
    static let islandWidth: CGFloat = 648
    /// A single card (a request from Claude, a reminder, the drop zones) needs less.
    static let islandCardWidth: CGFloat = 520
    static let islandHeight: CGFloat = 172
    /// The island panel's fixed height: the tallest the open island gets.
    static let islandMaxHeight: CGFloat = 520
    /// Around the open island's content. Card radius + padding = island radius, so corners run parallel.
    static let islandPadding: CGFloat = Space.sm
    /// What a page has to lay out its cards.
    static let islandContentWidth: CGFloat = islandWidth - islandPadding * 2
    /// The band beside the notch holds the page tabs; it is never lower than this.
    static let islandBandMinHeight: CGFloat = 32
    static let tileWidth: CGFloat = 152
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
            .background(hovering ? IslandColor.cardHover : Color.clear, in: shape)
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
                .background(prominent ? IslandColor.accent : (hovering ? IslandColor.cardHover : IslandColor.card),
                            in: Circle())
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
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypeStyle.islandCaption.weight(.semibold))
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.xs + 2)
                .foregroundStyle(foreground)
                .background(background.opacity(hovering ? 0.85 : 1), in: Capsule())
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
        case .primary: IslandColor.accent
        case .warm: IslandColor.warmFill
        case .secondary: IslandColor.cardHover
        case .danger: IslandColor.danger.opacity(0.35)
        }
    }
}

/// The Vibrant+ mark: the pulse line of the app icon (Brandguide V1.0, 10), the same centre line on the
/// 1024 grid with a 100 px round stroke. Drawn in code so it stays sharp at every size and works as a
/// template image in the menu bar.
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

    /// The stroked pulse line: centre line from the icon, stroke 100, round caps and joins.
    private nonisolated(unsafe) static let outline: CGPath = {
        let line = CGMutablePath()
        line.move(to: CGPoint(x: 153, y: 548))
        for (x, y) in [(376, 548), (417, 197), (543, 834), (629, 431), (700, 548), (873, 548)] {
            line.addLine(to: CGPoint(x: x, y: y))
        }
        return line.copy(strokingWithWidth: 100, lineCap: .round, lineJoin: .round, miterLimit: 10)
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
        let s = min(shoulder, rect.width / 4, rect.height / 2)
        let left = rect.minX + s, right = rect.maxX - s
        let r = min(radius, (right - left) / 2, rect.height - s)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // Right shoulder: curves inward from the top edge down into the body.
        p.addQuadCurve(to: CGPoint(x: right, y: rect.minY + s), control: CGPoint(x: right, y: rect.minY))
        p.addLine(to: CGPoint(x: right, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: right - r, y: rect.maxY), control: CGPoint(x: right, y: rect.maxY))
        p.addLine(to: CGPoint(x: left + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: left, y: rect.maxY - r), control: CGPoint(x: left, y: rect.maxY))
        p.addLine(to: CGPoint(x: left, y: rect.minY + s))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: left, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
