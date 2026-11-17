import Cocoa

// MARK: - DisplayServices (private API, the same path the brightness keys use)

typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

/// Resolved at runtime; nil if Apple ever removes or renames the symbols.
let displayServices: (get: GetFn, set: SetFn)? = {
    guard let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
          let g = dlsym(h, "DisplayServicesGetBrightness"),
          let s = dlsym(h, "DisplayServicesSetBrightness") else { return nil }
    return (unsafeBitCast(g, to: GetFn.self), unsafeBitCast(s, to: SetFn.self))
}()

func readBrightness(_ id: CGDirectDisplayID) -> Float? {
    guard let ds = displayServices else { return nil }
    var b: Float = 0
    return ds.get(id, &b) == 0 ? b : nil     // 0 = supported
}

// MARK: - Display identity

let idKey = NSDeviceDescriptionKey("NSScreenNumber")

@Sendable func displayID(_ sc: NSScreen) -> CGDirectDisplayID {
    sc.deviceDescription[idKey] as! CGDirectDisplayID
}

/// Stable per-display key (display IDs can change between boots, UUIDs don't).
@Sendable func displayKey(_ id: CGDirectDisplayID) -> String {
    if let u = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() {
        return CFUUIDCreateString(nil, u) as String
    }
    return "id-\(id)"
}

// MARK: - Persisted settings

let defaults = UserDefaults.standard
var enabled = defaults.object(forKey: "enabled") as? Bool ?? true
var excluded = Set(defaults.stringArray(forKey: "excluded") ?? [])

@Sendable func saveSettings() {
    defaults.set(enabled, forKey: "enabled")
    defaults.set(Array(excluded), forKey: "excluded")
}

// MARK: - Runtime state

var normal: [CGDirectDisplayID: Float] = [:]     // brightness to return to when active
var current: [CGDirectDisplayID: Float] = [:]    // brightness we last set
var lastSeen: [CGDirectDisplayID: Date] = [:]    // last time the mouse was on (or forced active)
var lastSet: [CGDirectDisplayID: Date] = [:]     // last time we wrote brightness
var keys: [CGDirectDisplayID: String] = [:]
var paused = false
var wakeGen = 0
var tickCount = 0

/// Single place where we write brightness, so we always know when we last touched it.
@Sendable func setBrightness(_ id: CGDirectDisplayID, _ v: Float) {
    current[id] = v
    lastSet[id] = Date()
    _ = displayServices?.set(id, v)
}

/// Learn about any displays we haven't seen yet. Known displays keep their saved brightness.
@Sendable func rescan() {
    for sc in NSScreen.screens {
        let id = displayID(sc)
        guard normal[id] == nil, let b = readBrightness(id) else { continue }
        normal[id] = b > 0.05 ? b : 0.8
        current[id] = b
        lastSeen[id] = Date()
        lastSet[id] = Date()
        keys[id] = displayKey(id)
        print("managing display \(id) (\(sc.localizedName)), normal brightness \(normal[id]!)")
    }
}

@Sendable func restoreAll() {
    for (id, b) in normal { setBrightness(id, b) }
}

// MARK: - Sleep / wake

/// Sleep: put brightness back to normal so nothing is stuck dark across a sleep/wake cycle.
@Sendable func suspend() {
    wakeGen += 1          // cancels any pending wake work
    paused = true
    restoreAll()
}

/// Wake: Thunderbolt displays can take a few seconds to come back through the adapters,
/// so reset twice, then resume dimming.
@Sendable func resume() {
    wakeGen += 1
    let gen = wakeGen
    paused = true
    for (delay, last) in [(1.0, false), (4.0, true)] {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard gen == wakeGen else { return }
            rescan()
            let now = Date()
            for (id, b) in normal {
                setBrightness(id, b)
                lastSeen[id] = now
            }
            if last { paused = false }
        }
    }
}

// MARK: - Menu labels

/// Strip macOS's "(1)"/"(2)" suffixes, and when several displays share a name, label them by
/// position. Side-by-side displays get left/right, stacked get top/bottom.
func menuLabels() -> [CGDirectDisplayID: String] {
    let screens = NSScreen.screens.filter { keys[displayID($0)] != nil }
    func base(_ sc: NSScreen) -> String {
        sc.localizedName.replacingOccurrences(of: #"\s*\(\d+\)$"#, with: "", options: .regularExpression)
    }
    var labels: [CGDirectDisplayID: String] = [:]
    for name in Set(screens.map(base)) {
        let group = screens.filter { base($0) == name }
        if group.count == 1 { labels[displayID(group[0])] = name; continue }

        // Which way are they arranged? Compare the spread of the display centers.
        let xs = group.map { $0.frame.midX }
        let ys = group.map { $0.frame.midY }
        let horizontal = (xs.max()! - xs.min()!) >= (ys.max()! - ys.min()!)

        // AppKit's y axis points up, so the top display has the largest midY.
        let ordered = horizontal ? group.sorted { $0.frame.midX < $1.frame.midX }
                                 : group.sorted { $0.frame.midY > $1.frame.midY }
        let words = horizontal ? ["left", "center", "right"] : ["top", "middle", "bottom"]

        for (i, sc) in ordered.enumerated() {
            let pos: String
            switch (ordered.count, i) {
            case (2, 0), (3, 0): pos = words[0]
            case (3, 1):         pos = words[1]
            case (2, 1), (3, 2): pos = words[2]
            default:             pos = "\(i + 1)"
            }
            labels[displayID(sc)] = "\(name) (\(pos))"
        }
    }
    return labels
}
