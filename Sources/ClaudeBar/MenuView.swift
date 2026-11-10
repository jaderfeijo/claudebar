import SwiftUI
import ServiceManagement

struct MenuView: View {
    @ObservedObject var model: UsageModel
    @State private var code = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.connected {
                usage
            } else {
                connect
            }
            Divider().padding(.horizontal, 17)
            footer
        }
        .frame(width: 280)
    }

    // MARK: - Connected

    private var usage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Claude Usage").font(.headline)
                if model.stale {
                    Circle().fill(.secondary).frame(width: 5, height: 5)
                        .help("Couldn't reach Anthropic — showing last known data")
                }
                Spacer()
            }
            if model.windows.isEmpty {
                Text("Loading…").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(model.windows) { w in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(w.label).font(.subheadline)
                        Spacer()
                        Text("\(Int(w.utilization.rounded()))%")
                            .font(.subheadline.monospacedDigit().weight(.medium))
                            .foregroundStyle(w.utilization >= 70 ? w.color : .primary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            // never narrower than a dot, so 0% still reads as a bar
                            Capsule().fill(w.color)
                                .frame(width: max(geo.size.height, geo.size.width * min(w.utilization, 100) / 100))
                        }
                    }
                    .frame(height: 5)
                    if let reset = w.resetText {
                        Text(reset).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 17)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    // MARK: - Connect

    private var connect: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Claude Usage").font(.headline)
            Text("Connect your Claude account to see your session and weekly limits.")
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.pendingAuth == nil {
                Button("Connect Claude Account") { model.startConnect() }
                    .controlSize(.large)
            } else {
                Text("Approve in your browser, then paste the code:")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("Paste code", text: $code)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { submit() }
                    Button("Connect") { submit() }
                        .disabled(code.isEmpty)
                }
            }
            if let err = model.lastError {
                Text(err).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 17)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    private func submit() {
        let c = code
        code = ""
        Task { await model.finishConnect(code: c) }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                launchAtLogin.toggle()
                try? launchAtLogin ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(.primary.opacity(0.22))
                        if launchAtLogin {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy))
                        }
                    }
                    .frame(width: 15, height: 15)
                    Text("Launch at login").font(.system(size: 9))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 14) {
                footerButton("Refresh") { Task { await model.refresh() } }
                footerButton("Dashboard") {
                    NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!)
                }
                if model.connected {
                    footerButton("Disconnect") { model.disconnect() }
                }
                Spacer()
                footerButton("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(.horizontal, 17)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .fixedSize()
    }
}
