import SwiftUI

struct EnvironmentFormSheet: View {
    @Binding var environment: MimirEnvironment
    let title: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("Save") { onSave(); dismiss() }.buttonStyle(AccentButtonStyle())
            }
            .padding(16)
            .background(t.surfaceAlt)
            .overlay(Rectangle().frame(height: 1).foregroundColor(t.sectionLine), alignment: .bottom)

            ScrollView {
                VStack(spacing: 12) {
                    formSection("Connection") {
                        formRow("Name") {
                            TextField("Production", text: $environment.name)
                                .inputStyle(t: t)
                        }
                        formRow("URL") {
                            TextField("https://mimir.example.com", text: $environment.url)
                                .inputStyle(t: t)
                                .font(.system(size: 13, design: .monospaced))
                        }
                        formRow("Org / Tenant ID") {
                            TextField("optional", text: Binding(
                                get: { environment.orgID ?? "" },
                                set: { environment.orgID = $0.isEmpty ? nil : $0 }
                            )).inputStyle(t: t)
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
                                )).inputStyle(t: t)
                                    .font(.system(size: 13, design: .monospaced))
                                Button("Browse…") { pickFile { environment.caCertPath = $0 } }
                                    .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }

                    formSection("Connection Options") {
                        formRow("Timeout") {
                            TextField("30s", text: $environment.timeout)
                                .inputStyle(t: t)
                                .frame(width: 100)
                        }
                        formRow("Retries") {
                            TextField("3", value: $environment.retries, format: .number)
                                .inputStyle(t: t)
                                .frame(width: 100)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 500, height: 480)
        .background(t.surface)
    }

    @ViewBuilder
    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.7)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(t.surfaceAlt)
            .overlay(Rectangle().frame(height: 1).foregroundColor(t.sectionLine), alignment: .bottom)

            content()
        }
        .background(t.surface)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(t.border, lineWidth: 1))
    }

    @ViewBuilder
    private func formRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(t.labelText)
                .frame(width: 130, alignment: .leading)
            content()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 1).foregroundColor(t.divider), alignment: .bottom)
    }

    private func pickFile(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { completion(url.path) }
    }
}

private extension TextField {
    func inputStyle(t: Theme) -> some View {
        self
            .textFieldStyle(.plain)
            .foregroundColor(t.textBody)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(t.inputBg)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(t.borderSub, lineWidth: 1))
            .cornerRadius(6)
    }
}
