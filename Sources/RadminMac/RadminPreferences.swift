// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

struct RadminPreferences: View {
    @ObservedObject var model: RuntimeModel
    @AppStorage("appearance") private var appearance = RadminAppearance.dark.rawValue
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    @State private var section = 0
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                item(L("prefs.section.appearance"), image: "paintpalette", index: 0)
                item(L("prefs.section.connection"), image: "server.rack", index: 1)
                item(L("prefs.section.about"), image: "info.circle", index: 2)
                Spacer()
            }.padding(10).frame(width: 175).background(.quaternary.opacity(0.35))
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                switch section {
                case 0:
                    Text(L("prefs.appearance.title")).font(.headline)
                    Picker(L("prefs.section.appearance"), selection: $appearance) {
                        ForEach(RadminAppearance.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }.pickerStyle(.radioGroup).labelsHidden()
                case 1:
                    Text(L("prefs.connection.title")).font(.headline)
                    LabeledContent(L("prefs.connection.device"), value: model.deviceName)
                    Toggle(L("prefs.connection.force_relay"), isOn: $model.forceRelay).disabled(model.active)
                    Text(model.active ? L("prefs.connection.relay_locked_hint") : L("prefs.connection.relay_hint"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Divider()
                    Text(model.bridgeServiceInstalled ? L("prefs.connection.bridge_installed") : L("prefs.connection.bridge_not_installed")).font(.system(size: 12, weight: .medium))
                    Button(model.bridgeServiceInstalled ? L("prefs.connection.bridge_update") : L("prefs.connection.bridge_install")) { model.installBridgeService() }
                        .disabled(model.active || model.bridgeInstallPending)
                    Text(model.bridgeInstallMessage.isEmpty ? L("prefs.connection.bridge_hint") : model.bridgeInstallMessage)
                        .font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
                    Divider()
                    Picker(L("prefs.connection.language"), selection: $appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language.rawValue)
                        }
                    }
                    Text(L("prefs.connection.unsupported_note"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                default:
                    Text(L("about.title")).font(.headline)
                    Text(L("prefs.about.version"))
                    Text(L("prefs.about.description"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Link(L("prefs.about.openrad_link"), destination: URL(string: "https://github.com/gringoestrangeiro/openrad")!)
                    Text(L("prefs.about.licenses"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }.id(appLanguage).frame(width: 510, height: 420).navigationTitle(L("prefs.title"))
            .preferredColorScheme(RadminAppearance(rawValue: appearance)?.scheme).tint(RadminColors.teal)
    }
    private func item(_ title: String, image: String, index: Int) -> some View {
        Button { section = index } label: {
            HStack(spacing: 8) {
                Image(systemName: image).font(.system(size: 15)).frame(width: 20).foregroundStyle(RadminColors.teal)
                Text(title).font(.system(size: 12)).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
            }.padding(.horizontal, 8).frame(height: 34).contentShape(Rectangle())
                .background(section == index ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain)
    }
}
