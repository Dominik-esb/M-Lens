import SwiftUI

struct EnvironmentFormSheet: View {
    @Binding var environment: MimirEnvironment
    let title: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("Save") { onSave(); dismiss() }.buttonStyle(AccentButtonStyle())
            }
            .padding(16)
            .background(Color(hex: "#1a1a1a"))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#272727")), alignment: .bottom)

            ScrollView {
                VStack(spacing: 12) {
                    formSection("Connection") {
                        formRow("Name") {
                            TextField("Production", text: $environment.name)
                                .inputStyle()
                        }
                        formRow("URL") {
                            TextField("https://mimir.example.com", text: $environment.url)
                                .inputStyle()
                                .font(.system(size: 13, design: .monospaced))
                        }
                        formRow("Org / Tenant ID") {
                            TextField("optional", text: Binding(
                                get: { environment.orgID ?? "" },
                                set: { environment.orgID = $0.isEmpty ? nil : $0 }
                            )).inputStyle()
                        }
                    }

                    formSection("TLS") {
                        formRow("Skip TLS Verify") {
                            Toggle("", isOn: $environment.tlsSkipVerify).labelsHidden()
                        }
                        formRow("CA Cert Path") {
                            HStack(spacing: 8) {
                                TextField("", text: Binding(
                                    get: { environment.caCertPath ?? "" },
                                    set: { environment.caCertPath = $0.isEmpty ? nil : $0 }
                                )).inputStyle()
                                    .font(.system(size: 13, design: .monospaced))
                                Button("Browse…") { pickFile { environment.caCertPath = $0 } }
                                    .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }

                    formSection("Connection Options") {
                        formRow("Timeout") {
                            TextField("30s", text: $environment.timeout)
                                .inputStyle()
                                .frame(width: 100)
                        }
                        formRow("Retries") {
                            TextField("3", value: $environment.retries, format: .number)
                                .inputStyle()
                                .frame(width: 100)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 500, height: 480)
        .background(Color(hex: "#1e1e1e"))
    }

    @ViewBuilder
    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#555555"))
                    .tracking(0.7)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color(hex: "#1a1a1a"))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#272727")), alignment: .bottom)

            content()
        }
        .background(Color(hex: "#1e1e1e"))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
    }

    @ViewBuilder
    private func formRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#aaaaaa"))
                .frame(width: 130, alignment: .leading)
            content()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#252525")), alignment: .bottom)
    }

    private func pickFile(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { completion(url.path) }
    }
}

private extension TextField {
    func inputStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .foregroundColor(Color(hex: "#d0d0d0"))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(hex: "#272727"))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#383838"), lineWidth: 1))
            .cornerRadius(6)
    }
}
