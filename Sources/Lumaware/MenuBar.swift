import Cocoa

final class MenuController: NSObject, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    let icon = makeMenubarIcon()

    override init() {
        super.init()
        menu.delegate = self
        item.menu = menu
        updateIcon()
    }

    func updateIcon() {
        guard let button = item.button else { return }
        button.image = icon
        button.title = ""
        button.alphaValue = enabled ? 1.0 : 0.4     // faded icon = auto-dim off
    }

    func addSwitch(_ title: String, on: Bool, _ onChange: @escaping (Bool) -> Void) {
        let mi = NSMenuItem()
        mi.view = SwitchRow(title: title, on: on, onChange: onChange)
        menu.addItem(mi)
    }

    // Rebuilt each time the menu opens, so it always reflects the connected displays.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        addSwitch("Auto-dim", on: enabled) { [weak self] on in
            enabled = on
            saveSettings()
            self?.updateIcon()
        }

        menu.addItem(.separator())
        let header = NSMenuItem(title: "Displays (toggle to disable auto-dim, change active brightness)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let labels = menuLabels()
        for sc in NSScreen.screens {
            let id = displayID(sc)
            guard let key = keys[id] else { continue }
            let card = DisplayCard(
                name: labels[id] ?? sc.localizedName,
                builtin: CGDisplayIsBuiltin(id) != 0,
                neverDim: excluded.contains(key),
                brightness: normal[id] ?? 0.8,
                onNeverDim: { on in
                    if on { excluded.insert(key) } else { excluded.remove(key) }
                    saveSettings()
                },
                onBrightness: { v in
                    normal[id] = v          // the brightness this display returns to when active
                    setBrightness(id, v)    // apply now so you can see the change
                })
            let mi = NSMenuItem()
            mi.view = card
            menu.addItem(mi)
        }

        menu.addItem(.separator())
        addSwitch("Launch at login", on: launchAtLoginEnabled()) { on in setLaunchAtLogin(on) }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Lumaware", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc func toggleEnabled() {
        enabled.toggle()
        saveSettings()
        updateIcon()
    }

    @objc func quitApp() {
        restoreAll()
        exit(0)
    }
}
