// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import RadminCore

private let panel = Color(red: 0.085, green: 0.11, blue: 0.15)

@main
struct RadminApp: App {
    @StateObject private var model = RuntimeModel()
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    var body: some Scene {
        let _ = appLanguage
        WindowGroup {
            RadminWindow(model: model).frame(minWidth: 340, minHeight: 420)
        }.defaultSize(width: 360, height: 500)
        Settings { RadminPreferences(model: model) }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(L("menu.system")) {
                Button(model.active ? L("menu.system.disconnect") : L("menu.system.connect")) { if model.active { model.disconnect() } else { model.connect() } }
                Divider()
                SettingsLink { Text(L("menu.system.settings")) }
            }
            CommandMenu(L("menu.network")) {
                Button(L("menu.network.create")) { model.showCreateNetwork = true }.keyboardShortcut("n").disabled(!model.serverConnected)
                Button(L("menu.network.join")) { model.showJoinNetwork = true }.keyboardShortcut("j").disabled(!model.serverConnected)
                Button(L("menu.network.retry_peers")) { model.retryPeers() }.disabled(!model.serverConnected)
            }
        }
    }
}
