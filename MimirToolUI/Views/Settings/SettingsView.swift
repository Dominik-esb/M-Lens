import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var envStore: EnvironmentStore
    @AppStorage("mimirtoolPath") private var mimirtoolPath: String = ""
    @AppStorage("logLevel") private var logLevel: String = "info"
    @AppStorage("verboseOutput") private var verboseOutput: Bool = false
    @AppStorage("tlsSkipVerify") private var tlsSkipVerify: Bool = false
    @AppStorage("caCertPath") private var caCertPath: String = ""
    @AppStorage("timeout") private var timeout: String = "30s"
    @AppStorage("retries") private var retries: Int = 3

    @State private var showAddEnv = false
    @State private var editingEnv: MimirEnvironment?
    @State private var newEnv = MimirEnvironment(name: "", url: "")
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: MimirEnvironment?

    private var detectedPath: String? { MimirtoolRunner().resolvedBinaryPath(override: nil) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                    .padding(.top, 20)

                // Environments
                settingsCard {
                    cardHeader("Environments") {
                        Button("+ Add Environment") {
                            newEnv = MimirEnvironment(name: "", url: "")
                            showAddEnv = true
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color(hex: "#7ab3f0"))
                        .font(.system(size: 12))
                    }
                    ForEach(envStore.environments) { env in
                        EnvironmentRowView(
                            environment: env,
                            isActive: envStore.activeEnvironment?.id == env.id,
                            onEdit: { editingEnv = env },
                            onDelete: { deleteTarget = env; showDeleteConfirm = true }
                        )
                    }
                    if envStore.environments.isEmpty {
                        Text("No environments yet.")
                            .font(.system(size: 13)).foregroundColor(Color(hex: "#444444"))
                            .padding(16)
                    }
                }

                // Binary
                settingsCard {
                    cardHeader("mimirtool Binary") {}
                    settingRow(label: "Binary Path", description: "Auto-detected or custom") {
                        HStack(spacing: 8) {
                            TextField("/path/to/mimirtool", text: $mimirtoolPath)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Color(hex: "#d0d0d0"))
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color(hex: "#272727"))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#333333"), lineWidth: 1))
                                .cornerRadius(7)
                            if detectedPath != nil && mimirtoolPath.isEmpty {
                                Text("✓ detected").font(.system(size: 11))
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Color(hex: "#142e14")).foregroundColor(Color(hex: "#4ade80"))
                                    .cornerRadius(4)
                            }
                            Button("Browse…") { pickFile { mimirtoolPath = $0 } }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }

                // TLS & Connection
                settingsCard {
                    cardHeader("TLS & Connection") {}
                    settingRow(label: "Skip TLS Verify", description: "Insecure — skip cert check") {
                        Toggle("", isOn: $tlsSkipVerify).labelsHidden()
                    }
                    settingRow(label: "CA Cert Path", description: "Custom CA certificate") {
                        HStack(spacing: 8) {
                            TextField("", text: $caCertPath)
                                .textFieldStyle(.plain)
                                .foregroundColor(Color(hex: "#d0d0d0"))
                                .font(.system(size: 13, design: .monospaced))
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color(hex: "#272727"))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#333333"), lineWidth: 1))
                                .cornerRadius(7)
                            Button("Browse…") { pickFile { caCertPath = $0 } }.buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    settingRow(label: "Timeout", description: "Request timeout") {
                        TextField("30s", text: $timeout)
                            .textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0"))
                            .frame(width: 100)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color(hex: "#272727"))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#333333"), lineWidth: 1))
                            .cornerRadius(7)
                    }
                    settingRow(label: "Retries", description: "Max retry attempts") {
                        TextField("3", value: $retries, format: .number)
                            .textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0"))
                            .frame(width: 100)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color(hex: "#272727"))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#333333"), lineWidth: 1))
                            .cornerRadius(7)
                    }
                }

                // General
                settingsCard {
                    cardHeader("General") {}
                    settingRow(label: "Log Level") {
                        Picker("", selection: $logLevel) {
                            Text("info").tag("info")
                            Text("debug").tag("debug")
                            Text("warn").tag("warn")
                            Text("error").tag("error")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .colorScheme(.dark)
                    }
                    settingRow(label: "Verbose Output", description: "Show raw mimirtool output") {
                        Toggle("", isOn: $verboseOutput).labelsHidden()
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(Color(hex: "#242424"))
        .sheet(isPresented: $showAddEnv) {
            EnvironmentFormSheet(environment: $newEnv, title: "Add Environment") {
                guard !newEnv.name.isEmpty && !newEnv.url.isEmpty else { return }
                envStore.add(newEnv)
            }
        }
        .sheet(item: $editingEnv) { env in
            let binding = Binding(
                get: { editingEnv ?? env },
                set: { editingEnv = $0 }
            )
            EnvironmentFormSheet(environment: binding, title: "Edit Environment") {
                if let updated = editingEnv { envStore.update(updated) }
            }
        }
        .alert("Delete Environment?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let t = deleteTarget { envStore.delete(t) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
    }

    @ViewBuilder
    private func cardHeader(_ title: String, @ViewBuilder action: () -> some View) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#555555")).tracking(0.7)
            Spacer()
            action()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(hex: "#1a1a1a"))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#272727")), alignment: .bottom)
    }

    @ViewBuilder
    private func settingRow<Content: View>(label: String, description: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 13)).foregroundColor(Color(hex: "#aaaaaa"))
                if let desc = description {
                    Text(desc).font(.system(size: 11)).foregroundColor(Color(hex: "#4a4a4a"))
                }
            }.frame(width: 160, alignment: .leading)
            content()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#252525")), alignment: .bottom)
    }

    private func pickFile(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { completion(url.path) }
    }
}
