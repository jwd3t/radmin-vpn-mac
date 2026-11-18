// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import SwiftUI
import RadminCore

enum RadminAppearance: String, CaseIterable {
    case light, dark, system
    var title: String { switch self { case .light: L("appearance.light"); case .dark: L("appearance.dark"); case .system: L("appearance.system") } }
    var scheme: ColorScheme? { switch self { case .light: .light; case .dark: .dark; case .system: nil } }
}

struct RadminColors {
    let dark: Bool
    static let teal = Color(red: 0.17, green: 0.73, blue: 0.82)
    var background: Color { dark ? Color(red: 0.055, green: 0.085, blue: 0.12) : Color(red: 0.94, green: 0.95, blue: 0.97) }
    var card: Color { dark ? Color(red: 0.135, green: 0.175, blue: 0.23) : .white }
    var selected: Color { dark ? Color(red: 0.17, green: 0.32, blue: 0.47) : Color.accentColor.opacity(0.17) }
}

struct RadminWindow: View {
    @ObservedObject var model: RuntimeModel
    @AppStorage("appearance") private var appearance = RadminAppearance.dark.rawValue
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    var body: some View {
        RadminWindowContent(model: model)
            .id(appLanguage)
            .preferredColorScheme(RadminAppearance(rawValue: appearance)?.scheme)
            .tint(RadminColors.teal)
    }
}

private struct RadminWindowContent: View {
    private struct PeerRowSelection: Equatable {
        let network: String
        let peer: UInt64
    }
    @ObservedObject var model: RuntimeModel
    @Environment(\.colorScheme) private var scheme
    @State private var collapsed: Set<String> = []
    @State private var selection: PeerRowSelection?
    @State private var leaving: EngineNetwork?
    @State private var showDetails = false
    private var colors: RadminColors { RadminColors(dark: scheme == .dark) }
    private var address: String { model.snapshot?.vip ?? "—" }
    private var status: String {
        if model.serverConnected { return model.snapshot?.interfaceReady == true ? L("status.online") : L("status.waiting_adapter") }
        switch model.phase {
        case "stopped": return L("status.offline")
        case "error": return L("status.connection_error")
        case "stopping": return L("status.disconnecting")
        case "provisioning": return L("status.registering")
        default: return L("status.connecting")
        }
    }
    private var phaseDetail: String {
        switch model.phase {
        case "provisioning": return L("phase.provisioning")
        case "connecting": return L("phase.connecting")
        case "storage": return L("phase.storage")
        case "stopping": return L("phase.stopping")
        case "stopped": return L("phase.stopped")
        case "online": return model.snapshot?.interfaceReady == true ? L("phase.online") : L("phase.waiting_adapter")
        case "reconnecting": return model.reconnectDelaySeconds.map { L("phase.reconnecting", Int64($0)) } ?? model.connectionDetail
        default: return model.connectionDetail
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                Menu(L("menu.system")) {
                    Button(model.active ? L("menu.system.disconnect") : L("menu.system.connect")) { power() }.disabled(model.phase == "stopping")
                    SettingsLink { Text(L("menu.system.settings")) }
                    Divider()
                    Button(L("menu.system.quit")) { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
                }
                Menu(L("menu.network")) {
                    Button(L("menu.network.create")) { model.showCreateNetwork = true }.disabled(!model.serverConnected)
                    Button(L("menu.network.join")) { model.showJoinNetwork = true }.disabled(!model.serverConnected)
                    Divider()
                    Button(L("menu.network.retry_peers")) { model.retryPeers() }.disabled(!model.serverConnected)
                }
                Menu(L("menu.help")) {
                    Button(L("menu.help.about")) { showDetails = true }
                }
                Spacer(minLength: 0)
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).tint(.primary).fixedSize(horizontal: false, vertical: true)
                .font(.system(size: 11)).padding(.horizontal, 14).frame(height: 29)

            HStack(spacing: 12) {
                Button(action: power) {
                    VStack(spacing: 1) {
                        Image(systemName: "power").font(.system(size: 22, weight: .medium))
                        Text(model.active ? "ON" : "OFF").font(.system(size: 9, weight: .bold))
                    }.foregroundStyle(model.active ? Color.white : Color.secondary)
                        .frame(width: 59, height: 59)
                        .background {
                            Circle().fill(LinearGradient(colors: model.active ? [RadminColors.teal.opacity(0.65), RadminColors.teal] : [colors.card, colors.background], startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                        .overlay(Circle().strokeBorder(.white.opacity(model.active ? 0.7 : 0.2), lineWidth: 1.5))
                        .padding(3).background(Circle().fill(.primary.opacity(0.12)))
                }.buttonStyle(.plain).disabled(model.engineURL == nil || model.phase == "stopping")
                    .accessibilityLabel(model.active ? L("power.disconnect") : L("power.connect"))
                    .help(model.active ? L("power.disconnect") : L("power.connect"))
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.deviceName).font(.system(size: 15, weight: .semibold)).foregroundStyle(RadminColors.teal).lineLimit(1)
                    Text(address).font(.system(size: 13, weight: .bold)).monospacedDigit().textSelection(.enabled)
                        .contextMenu { Button(L("peer.copy_ip")) { copy(address) } }
                    Text(status).font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(model.serverConnected ? Color.white : Color.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(model.serverConnected ? RadminColors.teal.opacity(0.7) : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                }
                Spacer(minLength: 0)
            }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
                .background(colors.card, in: RoundedRectangle(cornerRadius: 9)).padding(.horizontal, 10).padding(.bottom, 8)

            if let error = model.snapshot?.interfaceError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(error).lineLimit(3).textSelection(.enabled)
                    Spacer(minLength: 0)
                    Button(L("action.retry")) { model.retryInterface() }
                }.font(.system(size: 10)).padding(10)
            } else if model.active && model.snapshot?.interfaceReady != true {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    Text(model.snapshot == nil ? phaseDetail : L("status.confirm_adapter")).lineLimit(2)
                    Spacer(minLength: 0)
                }.font(.system(size: 10)).foregroundStyle(.secondary).padding(10)
            } else if model.phase == "error" {
                Text(phaseDetail).font(.system(size: 11)).foregroundStyle(.red).textSelection(.enabled).padding(10)
            }

            ScrollView {
                VStack(spacing: 5) {
                    if let snapshot = model.snapshot, !snapshot.networks.isEmpty {
                        ForEach(snapshot.networks) { network in networkCard(network, snapshot: snapshot) }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "network").font(.system(size: 25)).foregroundStyle(.tertiary)
                            Text(model.serverConnected ? L("empty.no_networks") : (model.active ? L("empty.waiting_connection") : L("empty.press_power")))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                            if model.serverConnected {
                                Button(L("menu.network.join")) { model.showJoinNetwork = true }.controlSize(.small)
                            }
                        }.frame(maxWidth: .infinity).padding(.top, 48)
                    }
                }.padding(.horizontal, 10).padding(.bottom, 10)
            }
            HStack(spacing: 5) {
                Text(model.operationMessage.isEmpty ? "" : model.operationMessage).lineLimit(1).help(model.operationMessage)
                Spacer(minLength: 0)
                Text("↓ \(rate(model.downloadRate))  ↑ \(rate(model.uploadRate))").monospacedDigit().fixedSize()
                Button { showDetails.toggle() } label: { Image(systemName: "info.circle") }.buttonStyle(.plain).padding(.leading, 3)
                    .help(L("status.connection_info"))
                    .popover(isPresented: $showDetails) { connectionDetails.padding(18).frame(width: 280) }
            }.font(.system(size: 9)).foregroundStyle(.secondary).padding(.horizontal, 11).frame(height: 25)
        }.background(colors.background).navigationTitle("Radmin VPN")
            .sheet(isPresented: $model.showJoinNetwork) { RadminNetworkSheet(model: model, creating: false) }
            .sheet(isPresented: $model.showCreateNetwork) { RadminNetworkSheet(model: model, creating: true) }
            .sheet(isPresented: $model.showBridgeSetup) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("bridge_setup.title")).font(.headline)
                    Text(L("bridge_setup.description"))
                    Text(L("bridge_setup.note"))
                        .font(.caption).foregroundStyle(.secondary)
                    if !model.bridgeInstallMessage.isEmpty { Text(model.bridgeInstallMessage).font(.caption).textSelection(.enabled) }
                    HStack {
                        Button(L("bridge_setup.later")) { model.showBridgeSetup = false }.disabled(model.bridgeInstallPending)
                        Spacer()
                        if model.bridgeInstallPending { ProgressView().controlSize(.small) }
                        Button(L("bridge_setup.install_and_connect")) { model.installBridgeService(connectAfter: true) }
                            .buttonStyle(.borderedProminent).disabled(model.bridgeInstallPending)
                    }
                }.padding(24).frame(width: 410).interactiveDismissDisabled(model.bridgeInstallPending)
            }
            .confirmationDialog(L("dialog.leave_network.title", leaving?.name ?? ""), isPresented: Binding(get: { leaving != nil }, set: { if !$0 { leaving = nil } }), titleVisibility: .visible) {
                if let network = leaving { Button(L("dialog.leave_network.confirm"), role: .destructive) { model.leave(network); leaving = nil } }
            } message: { Text(L("dialog.leave_network.message")) }
    }
    private func networkCard(_ network: EngineNetwork, snapshot: EngineSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                if !collapsed.insert(network.id).inserted { collapsed.remove(network.id) }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: collapsed.contains(network.id) ? "chevron.right" : "chevron.down").font(.system(size: 8, weight: .bold)).frame(width: 8)
                    Text(network.name).font(.system(size: 12, weight: .bold)).lineLimit(1)
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 3)
                .accessibilityLabel(collapsed.contains(network.id) ? L("a11y.network.expand", network.name) : L("a11y.network.collapse", network.name))
                .contextMenu { Button(L("network.leave")) { leaving = network }.disabled(model.operationPending) }
            if !collapsed.contains(network.id) {
                let peers = snapshot.sortedPeers.filter { $0.peer.networkIds.contains(network.id) }
                if peers.isEmpty { Text(L("network.no_peers")).font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.bottom, 3) }
                ForEach(peers) { peer in
                    Button {
                        selection = PeerRowSelection(network: network.id, peer: peer.id)
                    } label: {
                    HStack(spacing: 5) {
                        signal(peer)
                        Text(peer.peer.name).lineLimit(1)
                        Spacer(minLength: 3)
                        Text(peer.peer.vip).monospacedDigit().fixedSize()
                    }.font(.system(size: 10)).padding(.horizontal, 7).frame(height: 22)
                        .background(selection == PeerRowSelection(network: network.id, peer: peer.id) ? colors.selected : .clear, in: Capsule())
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .simultaneousGesture(TapGesture(count: 2).onEnded { model.ping(peer) })
                        .contextMenu {
                            Text(transport(peer))
                            Button(L("peer.ping")) { model.ping(peer) }.disabled(peer.status != "Connected")
                            Button(L("peer.copy_ip")) { copy(peer.peer.vip) }
                        }.help("\(transport(peer)) · \(qualityDescription(peer))")
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(peer.peer.name), \(peer.peer.vip), \(transport(peer)), \(qualityDescription(peer))")
                        .accessibilityValue(selection == PeerRowSelection(network: network.id, peer: peer.id) ? L("a11y.selected") : "")
                        .padding(.horizontal, 7)
                }
            }
        }.padding(.bottom, 7).background(colors.card, in: RoundedRectangle(cornerRadius: 8))
    }
    private func signal(_ peer: EnginePeerView) -> some View {
        let bars = peer.status == "Connected" ? model.peerQuality[peer.id]?.bars(at: ProcessInfo.processInfo.systemUptime) ?? 0 : 0
        return HStack(alignment: .center, spacing: 1) {
            Image(systemName: "xmark").font(.system(size: 6, weight: .bold)).foregroundStyle(.secondary)
                .frame(width: 6).opacity(peer.status == "Offline" ? 1 : 0)
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(0..<4) { i in RoundedRectangle(cornerRadius: 0.5).fill(i < bars ? Color.green : Color.secondary.opacity(0.25)).frame(width: 2, height: CGFloat(3 + i * 2)) }
            }
        }.frame(width: 18, height: 12).accessibilityHidden(true)
    }
    private func qualityDescription(_ peer: EnginePeerView) -> String {
        guard peer.status == "Connected" else { return transport(peer) }
        guard let quality = model.peerQuality[peer.id], let bars = quality.bars(at: ProcessInfo.processInfo.systemUptime) else { return L("quality.not_measured") }
        guard let rtt = quality.rttMilliseconds else { return L("quality.no_response") }
        return L("quality.ping", rtt, Int64(bars))
    }
    private var connectionDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("about.title")).font(.headline)
            LabeledContent(L("details.address"), value: address)
            LabeledContent(L("details.adapter"), value: model.snapshot?.interfaceReady == true ? L("details.adapter.connected") : L("details.adapter.disconnected"))
            LabeledContent(L("details.sent"), value: ByteCountFormatter.string(fromByteCount: Int64(clamping: model.snapshot?.traffic.sentBytes ?? 0), countStyle: .binary))
            LabeledContent(L("details.received"), value: ByteCountFormatter.string(fromByteCount: Int64(clamping: model.snapshot?.traffic.receivedBytes ?? 0), countStyle: .binary))
            LabeledContent(L("details.dropped_frames"), value: String(model.snapshot?.traffic.dropped ?? 0))
            if let traffic = model.snapshot?.traffic, traffic.congestionWaits != nil {
                LabeledContent(L("details.udp_congestion_waits"), value: String(traffic.congestionWaits ?? 0))
                LabeledContent(L("details.drops_in_adapter"), value: "\(traffic.receiveQueueDropped ?? 0) / \(traffic.interfaceDropped ?? 0)")
                LabeledContent(L("details.drops_queue_forward"), value: "\(traffic.forwardQueueDropped ?? 0) / \(traffic.forwardingDropped ?? 0)")
            }
            Divider()
            Text(L("details.footer")).font(.system(size: 10)).foregroundStyle(.secondary)
        }.font(.system(size: 11))
    }
    private func power() { if model.active { model.disconnect() } else { model.connect() } }
    private func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
    private func rate(_ value: Double) -> String {
        if value >= 1_048_576 { return L("rate.mb_s", value / 1_048_576) }
        if value >= 1024 { return L("rate.kb_s", value / 1024) }
        return L("rate.b_s", max(0, value))
    }
    private func transport(_ peer: EnginePeerView) -> String {
        switch peer.transport {
        case "DirectTcp": return L("transport.direct_tcp")
        case "DirectUdp": return L("transport.direct_udp")
        case "Relay": return L("transport.relay")
        default:
            switch peer.status {
            case "Offline": return L("status.offline")
            case "Connecting": return L("status.connecting")
            case "Failed", "Refused": return L("transport.no_connection")
            default: return L("status.online")
            }
        }
    }
}

struct RadminNetworkSheet: View {
    @ObservedObject var model: RuntimeModel
    let creating: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    private var valid: Bool {
        !model.networkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!(creating || model.privateNetwork) || (password.utf16.count >= 6 && password.utf16.count <= 256)) &&
        (!creating || password == confirmation)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text(creating ? L("sheet.network.create_title") : L("sheet.network.join_title")).font(.system(size: 16, weight: .semibold))
            if !creating {
                Picker(L("sheet.network.type"), selection: $model.privateNetwork) {
                    Text(L("sheet.network.private")).tag(true)
                    Text(L("sheet.network.gaming")).tag(false)
                }.pickerStyle(.segmented).labelsHidden()
            }
            Form {
                TextField(L("sheet.network.name"), text: $model.networkName)
                if creating || model.privateNetwork {
                    SecureField(L("sheet.network.password"), text: $password)
                    if creating { SecureField(L("sheet.network.confirm_password"), text: $confirmation) }
                }
            }.formStyle(.columns).disabled(model.operationPending)
            if !creating && !model.privateNetwork {
                Text(L("sheet.network.gaming_hint")).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if creating || model.privateNetwork {
                Text(creating && !confirmation.isEmpty && password != confirmation ? L("sheet.network.passwords_mismatch") : L("sheet.network.password_hint"))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if !model.operationMessage.isEmpty { Text(model.operationMessage).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled) }
            HStack {
                if model.operationPending { ProgressView().controlSize(.small) }
                Spacer()
                Button(L("action.cancel")) { dismiss() }.keyboardShortcut(.cancelAction).disabled(model.operationPending)
                Button(creating ? L("action.create") : L("action.connect")) {
                    if creating { model.createNetwork(name: model.networkName, password: password) }
                    else { model.networkPassword = password; model.join() }
                    password = ""; confirmation = ""
                }.keyboardShortcut(.defaultAction).disabled(!valid || model.operationPending)
            }
        }.padding(22).frame(width: 350).tint(RadminColors.teal)
            .onAppear { model.operationMessage = "" }
            .onDisappear { password = ""; confirmation = ""; model.networkPassword = "" }
    }
}
