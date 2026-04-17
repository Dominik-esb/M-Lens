import SwiftUI

struct ConfigSummaryView: View {
    let yaml: String

    private var receivers: [String] {
        yaml.components(separatedBy: "\n")
            .filter { $0.contains("name:") && !$0.contains("alertname") }
            .compactMap { line -> String? in
                let parts = line.components(separatedBy: "name:")
                guard parts.count > 1 else { return nil }
                return parts[1]
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CONFIG SUMMARY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#555555"))
                .tracking(0.7)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#1a1a1a"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summarySection("Receivers") {
                        ForEach(receivers, id: \.self) { name in
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: "#7ab3f0")).frame(width: 6, height: 6)
                                Text(name).font(.system(size: 12)).foregroundColor(Color(hex: "#c0c0c0"))
                            }
                        }
                        if receivers.isEmpty {
                            Text("—").font(.system(size: 12)).foregroundColor(Color(hex: "#444444"))
                        }
                    }
                }
                .padding(14)
            }
        }
        .background(Color(hex: "#1e1e1e"))
        .frame(width: 220)
    }

    @ViewBuilder
    private func summarySection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "#555555"))
                .tracking(0.6)
            content()
        }
    }
}
