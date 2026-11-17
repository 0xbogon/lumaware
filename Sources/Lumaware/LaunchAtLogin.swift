import Foundation

// Launch at login via a per-user LaunchAgent that points at the app's executable.
// Because the path is recorded when the switch is turned on, moving the app means
// switching Launch at login off and on again.

let agentLabel = "com.0xbogon.lumaware"
let agentURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")

@Sendable func launchAtLoginEnabled() -> Bool {
    FileManager.default.fileExists(atPath: agentURL.path)
}

@Sendable func setLaunchAtLogin(_ on: Bool) {
    if on {
        let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": [exe],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],   // Quit from the menu stays quit
        ]
        try? FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? (plist as NSDictionary).write(to: agentURL)
    } else {
        try? FileManager.default.removeItem(at: agentURL)
    }
}
