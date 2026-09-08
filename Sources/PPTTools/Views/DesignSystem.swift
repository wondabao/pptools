import SwiftUI
import AppKit

// MARK: - Apple Design System Tokens & Constants

enum AppleDesign {
    // 4pt / 8pt Grid spacing
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // Continuous Corner Radii
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 999
    }

    // Apple Spring Animations
    enum Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let quick = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.85)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.22)
    }

    // Colors: Minimal Neutral Palette with subtle semantic cues
    enum Colors {
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
        static let quaternaryText = Color(nsColor: .quaternaryLabelColor)

        // Subtle hairline separator & borders
        static let hairline = Color.primary.opacity(0.08)
        static let cardBorder = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.24, alpha: 1.0)
                : NSColor(srgbRed: 0xEE / 255.0, green: 0xEE / 255.0, blue: 0xEE / 255.0, alpha: 1.0)
        }))
        static let activeBorder = Color.primary.opacity(0.18)

        // Surface backgrounds
        static let windowBackground = Color(nsColor: .windowBackgroundColor)
        static let sidebarBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.windowBackgroundColor
                : NSColor.white
        }))
        static let cardBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.18, alpha: 1.0)
                : NSColor(srgbRed: 0xF7 / 255.0, green: 0xF7 / 255.0, blue: 0xF7 / 255.0, alpha: 1.0)
        }))
        static let secondaryCardBackground = cardBackground.opacity(0.7)
        static let stageBackground = Color(nsColor: .windowBackgroundColor)

        // Semantic tones (muted, authentic Apple system colors)
        static let success = Color(nsColor: .systemGreen)
        static let warning = Color(nsColor: .systemOrange)
        static let error = Color(nsColor: .systemRed)
        // Pure Apple Monochrome Neutral Accents
        static let neutralAccent = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.88, alpha: 1.0)
                : NSColor(white: 0.16, alpha: 1.0)
        }))
        static let subtleAccent = Color.primary.opacity(0.8)
    }

    // Dual-Layer Apple Soft Shadows
    struct ShadowModifier: ViewModifier {
        var elevation: CGFloat = 1

        func body(content: Content) -> some View {
            content
                .shadow(color: Color.black.opacity(0.04 * Double(elevation)), radius: 3 * elevation, x: 0, y: 1 * elevation)
                .shadow(color: Color.black.opacity(0.05 * Double(elevation)), radius: 10 * elevation, x: 0, y: 4 * elevation)
        }
    }
}

// MARK: - View Modifiers & Extensions

extension View {
    func appleCard(
        cornerRadius: CGFloat = AppleDesign.Radius.md,
        padding: CGFloat = AppleDesign.Spacing.md,
        strokeColor: Color = AppleDesign.Colors.cardBorder,
        elevation: CGFloat = 0
    ) -> some View {
        self.padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppleDesign.Colors.cardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 0.5)
            }
            .modifier(AppleDesign.ShadowModifier(elevation: elevation))
    }

    /// macOS Standard Inspector Section Group (Zero-shadow, clean stroke)
    func appleSectionGroup(
        cornerRadius: CGFloat = 8,
        padding: CGFloat = 12
    ) -> some View {
        self.padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppleDesign.Colors.cardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppleDesign.Colors.cardBorder, lineWidth: 0.5)
            }
    }

    func appleFrostedCard(
        cornerRadius: CGFloat = AppleDesign.Radius.md,
        padding: CGFloat = AppleDesign.Spacing.md,
        strokeColor: Color = AppleDesign.Colors.cardBorder
    ) -> some View {
        self.padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 0.5)
            }
    }
}

// MARK: - Reusable UI Components

/// Apple-style Status Pill Badge
struct AppleStatusPill: View {
    let title: String
    var systemImage: String? = nil
    var customImage: NSImage? = nil
    let color: Color
    var isFilled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let customImage {
                Image(nsImage: customImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(title)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background {
            Capsule(style: .continuous)
                .fill(isFilled ? color : color.opacity(0.12))
        }
        .foregroundStyle(isFilled ? Color.white : color)
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
        }
    }
}

/// Apple-style Metric Tile / Card
struct AppleMetricCard: View {
    let title: String
    let value: Int
    let systemImage: String
    var accentColor: Color = Color.primary
    var valueColor: Color? = nil

    var body: some View {
        HStack(spacing: AppleDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%02d", value))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(valueColor ?? AppleDesign.Colors.primaryText)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppleDesign.Colors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .appleCard(cornerRadius: AppleDesign.Radius.md, padding: AppleDesign.Spacing.sm)
    }
}

/// Refined Slider Control with Value Badge
struct AppleControlSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var unit: String = "px"
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isDisabled ? AppleDesign.Colors.quaternaryText : AppleDesign.Colors.primaryText)
                Spacer()
                Text("\(Int(value)) \(unit)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(isDisabled ? AppleDesign.Colors.quaternaryText : AppleDesign.Colors.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
            }
            Slider(
                value: Binding(
                    get: { value },
                    set: { newVal in
                        if step > 0 {
                            value = (round(newVal / step) * step)
                        } else {
                            value = newVal
                        }
                    }
                ),
                in: range
            )
            .tint(AppleDesign.Colors.neutralAccent)
            .controlSize(.small)
            .disabled(isDisabled)
        }
        .opacity(isDisabled ? 0.45 : 1.0)
    }
}

/// Refined Section Header (macOS Native Inspector Style)
struct AppleSectionHeader: View {
    let number: String
    let title: String
    let subtitle: String?

    init(_ number: String, _ title: String, subtitle: String? = nil) {
        self.number = number
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppleDesign.Colors.primaryText)

            Spacer()

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppleDesign.Colors.secondaryText)
            }
        }
        .padding(.horizontal, 2)
    }
}

/// Helper to configure underlying NSWindow directly
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    final class WindowObservingView: NSView {
        var callback: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureWindow()
        }

        override func layout() {
            super.layout()
            configureWindow()
        }

        private func configureWindow() {
            if let window = window {
                window.titlebarAppearsTransparent = true
                window.titlebarSeparatorStyle = .none
                window.toolbar?.showsBaselineSeparator = false
                window.titleVisibility = .hidden
                callback?(window)
            }
        }
    }

    func makeNSView(context: Context) -> WindowObservingView {
        let view = WindowObservingView()
        view.callback = callback
        DispatchQueue.main.async {
            if let window = view.window ?? NSApp.windows.first {
                window.titlebarAppearsTransparent = true
                window.titlebarSeparatorStyle = .none
                window.toolbar?.showsBaselineSeparator = false
                window.titleVisibility = .hidden
                callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: WindowObservingView, context: Context) {
        nsView.callback = callback
        if let window = nsView.window ?? NSApp.windows.first {
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.toolbar?.showsBaselineSeparator = false
            window.titleVisibility = .hidden
            callback(window)
        }
    }
}

/// Native macOS VisualEffectView for true Finder-like sidebar material
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(material: NSVisualEffectView.Material = .sidebar, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - macOS Inspector Settings Group Components

/// macOS Inspector Section / Settings Group (Clean, flat inspector section without card wrapper)
struct SettingsGroup<Content: View>: View {
    let title: String?
    let footer: String?
    let content: Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// macOS Inspector Style Setting Row
struct SettingsRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color?
    let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor ?? AppleDesign.Colors.neutralAccent)
                    .frame(width: 20)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5.5)
    }
}

/// Divider separating rows in a SettingsGroup
struct SettingsDivider: View {
    var inset: CGFloat = 0
    var body: some View {
        Divider()
            .padding(.leading, inset)
            .opacity(0.35)
    }
}

/// macOS System Settings Visual Thumbnail Choice Card (like 外观 浅色/深色/自动)
struct TemplateVisualCard: View {
    let title: String
    let subtitle: String
    let templateID: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Miniature window illustration
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppleDesign.Colors.sidebarBackground)
                        .frame(width: 74, height: 48)

                    // Template illustration graphics (Monochrome Neutral)
                    Group {
                        if templateID == "picpark-detail-35" {
                            // Detail long image layout: Neutral header + 2-col staggered cards
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.primary.opacity(0.70))
                                    .frame(width: 60, height: 11)
                                HStack(spacing: 2) {
                                    VStack(spacing: 2) {
                                        RoundedRectangle(cornerRadius: 1.5).fill(Color.primary.opacity(0.20)).frame(width: 28, height: 12)
                                        RoundedRectangle(cornerRadius: 1.5).fill(Color.primary.opacity(0.20)).frame(width: 28, height: 12)
                                    }
                                    VStack(spacing: 2) {
                                        RoundedRectangle(cornerRadius: 1.5).fill(Color.primary.opacity(0.20)).frame(width: 28, height: 12)
                                        RoundedRectangle(cornerRadius: 1.5).fill(Color.primary.opacity(0.20)).frame(width: 28, height: 12)
                                    }
                                }
                            }
                            .padding(3)
                        } else if templateID == "picpark-hero" {
                            // eCommerce hero layout: Top large card + bottom 3 cards
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.70))
                                    .frame(width: 60, height: 23)
                                HStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 1.5).fill(Color.primary.opacity(0.20)).frame(width: 18, height: 12)
                                    RoundedRectangle(cornerRadius: 1.5).fill(Color.primary.opacity(0.20)).frame(width: 18, height: 12)
                                    RoundedRectangle(cornerRadius: 1.5).fill(Color.primary.opacity(0.20)).frame(width: 18, height: 12)
                                }
                            }
                            .padding(3)
                        } else {
                            // RedBook card layout: Upper card with header + lower 2 cards
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.65))
                                    .frame(width: 60, height: 21)
                                HStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.20)).frame(width: 28, height: 14)
                                    RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.20)).frame(width: 28, height: 14)
                                }
                            }
                            .padding(3)
                        }
                    }
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(AppleDesign.Colors.neutralAccent, lineWidth: 1.5)
                            .padding(-3)
                    }
                }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// System Settings Style Color Picker Row (PopUp style button matching macOS System Settings)
struct SettingsColorPickerRow: View {
    let title: String
    @Binding var selectedHex: String?
    let onColorChanged: () -> Void

    @State private var isHovered = false

    private var currentHex: String {
        selectedHex ?? "#2457F0"
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                CustomColorManager.shared.toggleColorPanel(currentHex: currentHex) { newHex in
                    selectedHex = newHex
                    onColorChanged()
                }
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(hex: currentHex) ?? Color(hex: "#2457F0")!)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
                        }

                    Text("选取颜色…")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .padding(.leading, 7)
                .padding(.trailing, 4)
                .padding(.vertical, 3.5)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                }
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5.5)
    }
}

/// System Settings Style Menu Picker Row (PopUp style menu button matching SettingsColorPickerRow)
struct SettingsMenuPickerRow<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [(id: T, label: String)]

    @State private var isHovered = false

    private var currentLabel: String {
        options.first(where: { $0.id == selection })?.label ?? ""
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Spacer()

            Menu {
                ForEach(options, id: \.id) { opt in
                    Button {
                        selection = opt.id
                    } label: {
                        if selection == opt.id {
                            Label(opt.label, systemImage: "checkmark")
                        } else {
                            Text(opt.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Text(currentLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 3.5)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                }
            }
            .buttonStyle(.plain)
            .fixedSize()
            .onHover { isHovered = $0 }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5.5)
    }
}

/// Custom NSSegmentedControl subclass matching macOS Calendar app (CALViewSwitcherSegmentedControl) exactly with 36pt height
final class CalendarSegmentedControl: NSSegmentedControl {
    override var intrinsicContentSize: NSSize {
        let original = super.intrinsicContentSize
        return NSSize(width: max(original.width, 220), height: 36)
    }
}

/// SwiftUI wrapper for Calendar-style 36pt Segmented Control
struct CalendarSegmentedPicker: NSViewRepresentable {
    let titles: [String]
    @Binding var selectedIndex: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> CalendarSegmentedControl {
        let control = CalendarSegmentedControl(labels: titles, trackingMode: .selectOne, target: context.coordinator, action: #selector(Coordinator.selectionChanged(_:)))
        control.segmentStyle = .automatic
        control.controlSize = NSControl.ControlSize(rawValue: 4) ?? .large
        control.segmentDistribution = .fillEqually
        control.selectedSegment = selectedIndex
        control.font = .systemFont(ofSize: 13, weight: .medium)
        control.selectedSegmentBezelColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.36, alpha: 1.0)
                : NSColor(srgbRed: 229.0 / 255.0, green: 227.0 / 255.0, blue: 229.0 / 255.0, alpha: 1.0)
        }
        for i in 0..<titles.count {
            control.setWidth(108, forSegment: i)
        }
        DispatchQueue.main.async {
            if let window = control.window ?? NSApp.keyWindow ?? NSApp.windows.first {
                window.titlebarSeparatorStyle = .none
                window.toolbar?.showsBaselineSeparator = false
                window.titleVisibility = .hidden
            }
        }
        return control
    }

    func updateNSView(_ nsView: CalendarSegmentedControl, context: Context) {
        context.coordinator.parent = self
        if nsView.selectedSegment != selectedIndex {
            nsView.selectedSegment = selectedIndex
        }
    }

    final class Coordinator: NSObject {
        var parent: CalendarSegmentedPicker

        init(_ parent: CalendarSegmentedPicker) {
            self.parent = parent
        }

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            parent.selectedIndex = sender.selectedSegment
        }
    }
}

// MARK: - Custom Themed Scroller (#D9D9D9)

private struct ThemedScrollerKeys {
    static var observed: UInt8 = 0
}

enum TableHeaderThemeHelper {
    private static var hasInstalled = false

    static func installHeaderHooks() {
        guard !hasInstalled else { return }
        hasInstalled = true

        let falseBlock: @convention(block) (AnyObject, Int) -> Bool = { _, _ in false }
        let falseImp = imp_implementationWithBlock(falseBlock)
        if let m1 = class_getInstanceMethod(NSTableHeaderView.self, Selector(("_nextColumnDrawsLeftSeparatorFromColumn:"))) {
            method_setImplementation(m1, falseImp)
        }

        let endBlock: @convention(block) (AnyObject) -> Bool = { _ in false }
        let endImp = imp_implementationWithBlock(endBlock)
        if let m2 = class_getInstanceMethod(NSTableHeaderView.self, Selector(("_drawingEndSeparator"))) {
            method_setImplementation(m2, endImp)
        }

        let cellBlock: @convention(block) (AnyObject, AnyObject) -> Bool = { _, _ in false }
        let cellImp = imp_implementationWithBlock(cellBlock)
        if let m3 = class_getInstanceMethod(NSTableHeaderCell.self, Selector(("_shouldDrawRightSeparatorInView:"))) {
            method_setImplementation(m3, cellImp)
        }
    }

    static func styleTableView(_ tv: NSTableView) {
        installHeaderHooks()
        if let hv = tv.headerView {
            hv.setValue(true, forKey: "skipDrawingSeparator")
            hv.needsDisplay = true
        }
        tv.gridStyleMask.remove(.solidVerticalGridLineMask)
        tv.gridStyleMask.remove(.dashedHorizontalGridLineMask)
    }
}

enum ThemedScrollerHelper {
    static let scrollerColor = NSColor(srgbRed: 0xD9 / 255.0, green: 0xD9 / 255.0, blue: 0xD9 / 255.0, alpha: 1.0)

    static func styleScroller(_ scroller: NSScroller?) {
        guard let scroller = scroller else { return }
        scroller.controlSize = .regular
        if let imp = (scroller as AnyObject).value(forKey: "scrollerImp") as? NSObject {
            imp.setValue(scrollerColor, forKey: "knobColor")
        }
    }

    static func styleScrollView(_ sv: NSScrollView) {
        styleScroller(sv.verticalScroller)
        styleScroller(sv.horizontalScroller)

        if objc_getAssociatedObject(sv, &ThemedScrollerKeys.observed) == nil {
            objc_setAssociatedObject(sv, &ThemedScrollerKeys.observed, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            sv.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: sv.contentView,
                queue: .main
            ) { [weak sv] _ in
                guard let sv = sv else { return }
                styleScroller(sv.verticalScroller)
                styleScroller(sv.horizontalScroller)
            }
        }
    }

    static func applyRecursively(to view: NSView?) {
        guard let view = view else { return }
        if let sv = view as? NSScrollView {
            styleScrollView(sv)
            if let tv = sv.documentView as? NSTableView {
                TableHeaderThemeHelper.styleTableView(tv)
            }
        }
        if let tv = view as? NSTableView {
            TableHeaderThemeHelper.styleTableView(tv)
        }
        for sub in view.subviews {
            applyRecursively(to: sub)
        }
    }
}

final class ThemedScrollObserver: NSView {
    private var windowObserver: NSObjectProtocol?
    private var timer: Timer?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
        setupObservers()
    }

    override func layout() {
        super.layout()
        apply()
    }

    func setupObservers() {
        cleanObservers()
        guard let window = self.window else { return }

        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.apply()
        }

        var ticks = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] t in
            self?.apply()
            ticks += 1
            if ticks >= 10 {
                t.invalidate()
            }
        }
    }

    func cleanObservers() {
        if let o = windowObserver {
            NotificationCenter.default.removeObserver(o)
            windowObserver = nil
        }
        timer?.invalidate()
        timer = nil
    }

    deinit {
        cleanObservers()
    }

    func apply() {
        if let root = self.window?.contentView {
            ThemedScrollerHelper.applyRecursively(to: root)
        }
    }
}

struct ThemedScrollBarsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Representable())
    }

    private struct Representable: NSViewRepresentable {
        func makeNSView(context: Context) -> ThemedScrollObserver { ThemedScrollObserver() }
        func updateNSView(_ nsView: ThemedScrollObserver, context: Context) { nsView.apply() }
    }
}

extension View {
    func themedScrollBars() -> some View {
        self.modifier(ThemedScrollBarsModifier())
    }
}
