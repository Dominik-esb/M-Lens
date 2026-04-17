import SwiftUI

struct EnvironmentFormSheet: View {
    @Binding var environment: MimirEnvironment
    let title: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("Save") { onSave(); dismiss() }.buttonStyle(AccentButtonStyle())
            }
            .padding(16).background(Color(hex: "#1a1a1a"))

            Form {
                Section("Connection") {
                    formRow("Name") {
                        TextField("Production", text: $environment.name)
                            .textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0"))
                    }
                    formRow("URL") {
                        TextField("https://mimir.example.com", text: $environment.url)
                            .textFieldStyle(.plain)
                            .foregroundColor(Color(hex: "#d0d0d0"))
                            .font(.system(size: 13, design: .monospaced))
                    }
                    formRow("Org / Tenant ID") {
                        TextField("", text: Binding(
                            get: { environment.orgID ?? "" },
                            set: { environment.orgID = $0.isEmpty ? nil : $0 }
                        )).textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0"))
                    }
                }
                Section("TLS") {
                    Toggle("Skip TLS Verify", isOn: $environment.tlsSkipVerify)
                    formRow("CA Cert Path") {
                        HStack {
                            TextField("", text: Binding(
                                get: { environment.caCertPath ?? "" },
                                set: { environment.caCertPath = $0.isEmpty ? nil : $0 }
                            )).textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0"))
                            Button("Browse…") { pickFile { environment.caCertPath = $0 } }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
                Section("Connection Options") {
                    formRow("Timeout") {
                        TextField("30s", text: $environment.timeout)
                            .textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0"))
                    }
                    formRow("Retries") {
                        TextField("3", value: $environment.retries, format: .number)
                            .textFieldStyle(.plain).foregroundColor(Color(hex: "#d0d0d0"))
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#1e1e1e"))
        }
        .frame(width: 480, height: 520)
        .background(Color(hex: "#1e1e1e"))
    }

    @ViewBuilder
    private func formRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).foregroundColor(Color(hex: "#aaaaaa")).frame(width: 130, alignment: .leading)
            content()
        }
    }

    private func pickFile(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { completion(url.path) }
    }
}
