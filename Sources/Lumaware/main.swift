import Cocoa

// Menubar-only app: no Dock icon (also set via LSUIElement in Info.plist),
// but connects to the window server.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

guard displayServices != nil else {
    let alert = NSAlert()
    alert.messageText = "Lumaware can't control display brightness"
    alert.informativeText = "The system brightness API it relies on wasn't found on this version of macOS."
    alert.runModal()
    exit(1)
}

rescan()
let menuController = MenuController()   // global so it stays alive

// Keep references alive, otherwise the handlers are deallocated and never fire.
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM, SIGHUP] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler { restoreAll(); exit(0) }
    src.resume()
    signalSources.append(src)
}

let wsNC = NSWorkspace.shared.notificationCenter
wsNC.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in suspend() }
wsNC.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in suspend() }
wsNC.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in resume() }
wsNC.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in resume() }

// Hotplug: pick up newly attached displays.
NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                       object: nil, queue: .main) { _ in
    if !paused { rescan() }
}

let dimTimer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { _ in dimTick() }
app.run()
