import Cocoa

/// Runs every `tick` seconds: wakes the display under the mouse instantly, fades the others out.
@Sendable func dimTick() {
    if paused { return }
    tickCount += 1
    let checkNow = tickCount % checkEvery == 0
    let mouse = NSEvent.mouseLocation
    let now = Date()

    for sc in NSScreen.screens {
        let id = displayID(sc)
        guard let full = normal[id], let cur = current[id] else { continue }

        // Disabled or excluded displays are treated as permanently "active": they stay at
        // full brightness, and lastSeen keeps refreshing so re-enabling gets a normal grace period.
        let alwaysOn = !enabled || excluded.contains(keys[id] ?? "")
        if alwaysOn || NSMouseInRect(mouse, sc.frame, false) { lastSeen[id] = now }
        let active = alwaysOn || now.timeIntervalSince(lastSeen[id] ?? .distantPast) < dimDelay

        if active {
            if cur != full {                       // instant wake
                setBrightness(id, full)
            } else if checkNow, now.timeIntervalSince(lastSet[id] ?? .distantPast) > settleTime {
                // Already at full and settled: has the user changed it with the brightness keys?
                if let actual = readBrightness(id), actual > 0.05, abs(actual - full) > changeThreshold {
                    normal[id] = actual
                    current[id] = actual
                    print("display \(id) normal brightness changed to \(actual)")
                }
            }
        } else if cur > 0 {                        // slow fade out
            let step = full / Float(fadeOutSeconds / tick)
            setBrightness(id, max(0, cur - step))
        }
    }
}
