// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

// Vibrant+
//   VibrantPlus                  the menu bar app
//   VibrantPlus --hook           Claude Code hook (reads one event on stdin)
//   VibrantPlus --selftest       runs the self-test on APP_DATA in /tmp, exit 0 or 1
//   VibrantPlus --snapshot DIR   renders every screen to PNG in light and dark, then quits
//   APP_DATA=<dir>               use another data folder (tests)
@main
enum Entry {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--hook") { exit(HookCLI.run()) }
        VibrantPlusApp.main()
    }
}
