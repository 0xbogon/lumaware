import Cocoa

// MARK: - Icons

/// Menubar icon: monitor outline with a sun in the screen. Template image, so macOS tints it.
func makeMenubarIcon() -> NSImage {
    let img = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
        NSColor.black.setStroke()
        NSColor.black.setFill()

        // Screen
        let screen = NSBezierPath(roundedRect: NSRect(x: 1, y: 5, width: 18, height: 12).insetBy(dx: 0.7, dy: 0.7),
                                  xRadius: 2, yRadius: 2)
        screen.lineWidth = 1.4
        screen.stroke()

        // Stand: neck and base
        let stand = NSBezierPath()
        stand.lineWidth = 1.4
        stand.lineCapStyle = .round
        stand.move(to: NSPoint(x: 10, y: 5));    stand.line(to: NSPoint(x: 10, y: 2.5))
        stand.move(to: NSPoint(x: 6.5, y: 2.5)); stand.line(to: NSPoint(x: 13.5, y: 2.5))
        stand.stroke()

        // Sun: disk plus eight rays, centered in the screen
        let c = NSPoint(x: 10, y: 11)
        NSBezierPath(ovalIn: NSRect(x: c.x - 1.5, y: c.y - 1.5, width: 3, height: 3)).fill()
        let rays = NSBezierPath()
        rays.lineWidth = 1.0
        rays.lineCapStyle = .round
        for i in 0..<8 {
            let a = CGFloat(i) * .pi / 4
            rays.move(to: NSPoint(x: c.x + cos(a) * 2.5, y: c.y + sin(a) * 2.5))
            rays.line(to: NSPoint(x: c.x + cos(a) * 3.4, y: c.y + sin(a) * 3.4))
        }
        rays.stroke()
        return true
    }
    img.isTemplate = true
    return img
}

/// Vector sun for the slider ends (template image, so it follows light/dark mode).
func makeSunIcon(size: CGFloat, disk: CGFloat, rayInner: CGFloat, rayOuter: CGFloat, rayWidth: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { r in
        NSColor.black.setFill()
        NSColor.black.setStroke()
        let c = NSPoint(x: r.midX, y: r.midY)
        NSBezierPath(ovalIn: NSRect(x: c.x - disk, y: c.y - disk, width: disk * 2, height: disk * 2)).fill()
        let rays = NSBezierPath()
        rays.lineWidth = rayWidth
        rays.lineCapStyle = .round
        for i in 0..<8 {
            let a = CGFloat(i) * .pi / 4
            rays.move(to: NSPoint(x: c.x + cos(a) * rayInner, y: c.y + sin(a) * rayInner))
            rays.line(to: NSPoint(x: c.x + cos(a) * rayOuter, y: c.y + sin(a) * rayOuter))
        }
        rays.stroke()
        return true
    }
    img.isTemplate = true
    return img
}

// MARK: - SwitchRow

/// A menu row with a label on the left and a toggle switch on the right.
/// The whole row is clickable and sits on a rounded translucent background that darkens on hover.
final class SwitchRow: NSView {
    static let rowWidth: CGFloat = 420
    static let rowHeight: CGFloat = 38

    let toggle = NSSwitch()
    let onChange: (Bool) -> Void
    var hovering = false { didSet { needsDisplay = true } }

    init(title: String, on: Bool,
         width: CGFloat = SwitchRow.rowWidth, height: CGFloat = SwitchRow.rowHeight,
         onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        let w = width, h = height
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: h))

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.menuFont(ofSize: 0)
        label.sizeToFit()
        label.frame.origin = NSPoint(x: 24, y: (h - label.frame.height) / 2)
        addSubview(label)

        toggle.controlSize = .small
        toggle.state = on ? .on : .off
        toggle.target = self
        toggle.action = #selector(changed)
        let size = toggle.fittingSize
        toggle.frame = NSRect(x: w - size.width - 22, y: (h - size.height) / 2,
                              width: size.width, height: size.height)
        addSubview(toggle)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 3), xRadius: 8, yRadius: 8)
        NSColor.labelColor.withAlphaComponent(hovering ? 0.16 : 0.07).setFill()
        box.fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }

    // Clicks on the label and background go to the row; clicks on the switch go to the switch.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        return hit === toggle ? hit : self
    }

    override func mouseDown(with event: NSEvent) {
        toggle.state = toggle.state == .on ? .off : .on
        changed()
    }

    @objc func changed() { onChange(toggle.state == .on) }
}

// MARK: - SliderRow

/// "Brightness  ☼ ——●—— ☀  70%"
final class SliderRow: NSView {
    let slider = NSSlider(value: 0, minValue: 0.05, maxValue: 1.0, target: nil, action: nil)
    let readout = NSTextField(labelWithString: "")
    let onChange: (Float) -> Void

    init(value: Float, width: CGFloat = SwitchRow.rowWidth, onChange: @escaping (Float) -> Void) {
        self.onChange = onChange
        let w = width, h: CGFloat = 30
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: h))

        let label = NSTextField(labelWithString: "Brightness")
        label.font = NSFont.systemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize, weight: .light)
        label.sizeToFit()
        label.frame.origin = NSPoint(x: 24, y: (h - label.frame.height) / 2)
        addSubview(label)

        let readoutW: CGFloat = 40

        let small = NSImageView(image: makeSunIcon(size: 16, disk: 2.6, rayInner: 4.8, rayOuter: 5.6, rayWidth: 1.4))
        small.contentTintColor = .secondaryLabelColor
        small.frame = NSRect(x: label.frame.maxX + 14, y: (h - 16) / 2, width: 16, height: 16)
        addSubview(small)

        let large = NSImageView(image: makeSunIcon(size: 20, disk: 3.6, rayInner: 6.0, rayOuter: 8.8, rayWidth: 1.4))
        large.contentTintColor = .secondaryLabelColor
        large.frame = NSRect(x: w - 24 - readoutW - 6 - 20, y: (h - 20) / 2, width: 20, height: 20)
        addSubview(large)

        slider.doubleValue = Double(value)
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = self
        slider.action = #selector(moved)
        let sx = small.frame.maxX + 6
        slider.frame = NSRect(x: sx, y: (h - 16) / 2, width: large.frame.minX - 6 - sx, height: 16)
        addSubview(slider)

        readout.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        readout.textColor = .secondaryLabelColor
        readout.alignment = .right
        readout.frame = NSRect(x: w - 24 - readoutW, y: (h - 14) / 2, width: readoutW, height: 14)
        addSubview(readout)
        updateReadout()
    }
    required init?(coder: NSCoder) { fatalError() }

    func updateReadout() { readout.stringValue = "\(Int((slider.doubleValue * 100).rounded()))%" }

    @objc func moved() {
        updateReadout()
        onChange(Float(slider.doubleValue))
    }
}

// MARK: - DisplayCard

/// One display: dark rounded wrapper, type icon on the left, name + switch above the brightness slider.
final class DisplayCard: NSView {
    static let outer: CGFloat = 8          // gap between menu edge and card
    static let vgap: CGFloat = 3           // gap above and below the card
    static let iconColumn: CGFloat = 48
    static let pad: CGFloat = 4            // vertical padding inside the card
    static let headerHeight: CGFloat = 34
    static let sliderHeight: CGFloat = 30

    init(name: String, builtin: Bool, neverDim: Bool, brightness: Float,
         onNeverDim: @escaping (Bool) -> Void, onBrightness: @escaping (Float) -> Void) {
        let outer = DisplayCard.outer, vgap = DisplayCard.vgap, pad = DisplayCard.pad
        let cardH = DisplayCard.headerHeight + DisplayCard.sliderHeight + 2 * pad
        let w = SwitchRow.rowWidth
        let contentW = w - 2 * outer - DisplayCard.iconColumn
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: cardH + 2 * vgap))

        // Display type icon, centered vertically across the whole card
        let icon = NSImageView()
        let symbol = builtin ? "laptopcomputer" : "display"
        if #available(macOS 11.0, *),
           let img = NSImage(systemSymbolName: symbol, accessibilityDescription: name) {
            icon.image = img.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 22, weight: .regular))
        }
        icon.contentTintColor = .controlAccentColor
        icon.frame = NSRect(x: outer + (DisplayCard.iconColumn - 28) / 2,
                            y: vgap + (cardH - 28) / 2, width: 28, height: 28)
        addSubview(icon)

        let x = outer + DisplayCard.iconColumn
        let header = SwitchRow(title: name, on: neverDim, width: contentW,
                               height: DisplayCard.headerHeight, onChange: onNeverDim)
        header.frame.origin = NSPoint(x: x, y: vgap + pad + DisplayCard.sliderHeight)
        addSubview(header)

        let slider = SliderRow(value: brightness, width: contentW, onChange: onBrightness)
        slider.frame.origin = NSPoint(x: x, y: vgap + pad)
        addSubview(slider)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let r = NSRect(x: DisplayCard.outer, y: DisplayCard.vgap,
                       width: bounds.width - 2 * DisplayCard.outer,
                       height: bounds.height - 2 * DisplayCard.vgap)
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        NSColor.black.withAlphaComponent(dark ? 0.25 : 0.06).setFill()
        NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12).fill()
    }
}
