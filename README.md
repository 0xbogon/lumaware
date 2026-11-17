# Lumaware

A macOS menubar app that dims displays to 0% unless the mouse is on them, like the dim freezers
at a grocery store that light up when you walk up. The display under the cursor wakes instantly;
the others fade out after a short delay.

- Per-display brightness slider (the level a display returns to when active)
- Per-display "never dim" switch
- Auto-dim on/off switch, and Launch at login switch
- Restores brightness on sleep, wake, quit and Ctrl+C
- Picks up brightness-key changes and newly attached displays automatically

Works with displays that macOS exposes brightness for: Apple Thunderbolt Displays, LG UltraFine,
Studio Display, and built-in screens. Generic DDC monitors are not supported.

## Build

Requires Xcode or the Command Line Tools (`xcode-select --install`).

    make            # build/Lumaware.app, universal (arm64 + x86_64)
    make run        # build and launch
    make install    # copy to /Applications
    make verify     # architectures + signature check
    make zip        # build/Lumaware-<version>.zip

Useful overrides:

    make VERSION=1.2.0
    make SIGN_ID="Developer ID Application: Your Name (TEAMID)"
    make EXTRA_FLAGS=-suppress-warnings

The minimum macOS version is 10.15 on Intel and 11.0 on Apple Silicon (set `X86_MIN` and `ARM_MIN`
in the Makefile).

## Layout

    Makefile
    resources/Info.plist          bundle template (@NAME@, @BUNDLE_ID@, @VERSION@ filled in by make)
    scripts/make-icon.swift       draws AppIcon.icns at build time
    Sources/Lumaware/
        main.swift                app entry point, signals, sleep/wake and hotplug observers
        Config.swift              tuning constants (delays, fade time)
        Displays.swift            DisplayServices bridge, state, settings, sleep/wake, labels
        Dimmer.swift              the per-tick dimming logic
        MenuBar.swift             status item and menu
        Views.swift               switch rows, slider row, display cards, icons
        LaunchAtLogin.swift       per-user LaunchAgent helper

## Notes

- Brightness is controlled through Apple's private `DisplayServices` framework, loaded at runtime.
  That keeps it out of the App Store but works for direct distribution. If the symbols are ever
  missing, the app shows an alert and exits.
- Settings live in the `com.0xbogon.lumaware` defaults domain
  (`defaults read com.0xbogon.lumaware`).
- Launch at login writes `~/Library/LaunchAgents/com.0xbogon.lumaware.plist` pointing at the app's
  current path. If you move the app, switch it off and on again.
- Ad-hoc signed builds (the default) run fine on the Mac that built them. Sharing with other Macs
  needs a Developer ID signature and notarization, otherwise Gatekeeper will block it.
- The app needs no special macOS permissions: it only reads the cursor position and sets display
  brightness.
