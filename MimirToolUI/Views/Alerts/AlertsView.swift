import SwiftUI

struct AlertsView: View {
    let environment: MimirEnvironment
    @StateObject private var vm: AlertsViewModel

    init(environment: MimirEnvironment) {
        self.environment = environment
        _vm = StateObject(wrappedValue: AlertsViewModel(environment: environment))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Alerts").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Toggle("Auto-refresh", isOn: Binding(
                    get: { vm.autoRefresh },
                    set: { vm.setAutoRefresh($0) }
                ))
                .toggleStyle(.switch)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#888888"))
                Button { Task { await vm.load() } } label: {
                    Image(systemName: "arrow.clockwise").foregroundColor(Color(hex: "#666666"))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            HStack(spacing: 8) {
                filterChip("All (\(vm.alerts.count))",
                           active: vm.filter == .all,
                           color: Color(hex: "#2b3f5c"),
                           fg: Color(hex: "#7ab3f0")) { vm.filter = .all }
                filterChip("Firing (\(vm.alerts.filter { $0.state == .firing }.count))",
                           active: vm.filter == .firing,
                           color: Color(hex: "#2e1515"),
                           fg: Color(hex: "#f87171")) { vm.filter = .firing }
                filterChip("Pending (\(vm.alerts.filter { $0.state == .pending }.count))",
                           active: vm.filter == .pending,
                           color: Color(hex: "#2a2000"),
                           fg: Color(hex: "#fbbf24")) { vm.filter = .pending }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(Color(hex: "#555555"))
                    TextField("Filter by label…", text: $vm.searchText)
                        .textFieldStyle(.plain).font(.system(size: 13)).foregroundColor(Color(hex: "#c8c8c8"))
                }
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(Color(hex: "#1e1e1e"))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#333333"), lineWidth: 1))
                .frame(width: 200)
            }
            .padding(.horizontal, 20).padding(.bottom, 12)

            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }
                    .padding(.horizontal, 20).padding(.bottom, 8)
            }

            VStack(spacing: 0) {
                HStack {
                    Text("ALERT NAME").tableHeader().frame(width: 180, alignment: .leading)
                    Text("STATE").tableHeader().frame(width: 90, alignment: .leading)
                    Text("LABELS").tableHeader()
                    Spacer()
                    Text("DURATION").tableHeader().frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(hex: "#1e1e1e"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.filtered) { alert in
                            AlertRowView(alert: alert)
                        }
                        if vm.isLoading {
                            ProgressView().padding(32)
                        }
                        if !vm.isLoading && vm.alerts.isEmpty {
                            Text("No alerts found.")
                                .foregroundColor(Color(hex: "#444444")).padding(32)
                        }
                    }
                }

                StatusBarView(environment: environment,
                              statusText: vm.lastRefreshed.map { "Last refreshed: \(timeAgo($0))" } ?? "")
            }
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(Color(hex: "#242424"))
        .task { await vm.load() }
    }

    @ViewBuilder
    private func filterChip(_ label: String, active: Bool, color: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 12)).padding(.horizontal, 12).padding(.vertical, 4)
                .background(active ? color : Color(hex: "#2a2a2a"))
                .foregroundColor(active ? fg : Color(hex: "#888888"))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(active ? fg.opacity(0.3) : Color(hex: "#333333"), lineWidth: 1))
                .cornerRadius(16)
        }.buttonStyle(.plain)
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(-date.timeIntervalSinceNow)
        if s < 10 { return "just now" }
        if s < 60 { return "\(s)s ago" }
        return "\(s / 60)m ago"
    }
}

private struct AlertRowView: View {
    let alert: MimirAlert

    var body: some View {
        HStack(alignment: .top) {
            Text(alert.labels["alertname"] ?? "unknown")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#c8c8c8"))
                .frame(width: 180, alignment: .leading)

            TagView(text: alert.state.rawValue, style: alert.state == .firing ? .firing : .pending)
                .frame(width: 90, alignment: .leading)

            FlowLayout(spacing: 4) {
                ForEach(
                    alert.labels.filter { $0.key != "alertname" }.sorted { $0.key < $1.key },
                    id: \.key
                ) { pair in
                    Text("\(pair.key)=\(pair.value)")
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Color(hex: "#252525"))
                        .foregroundColor(Color(hex: "#666666"))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#303030"), lineWidth: 1))
                        .cornerRadius(4)
                }
            }

            Spacer()
            Text(durationString(from: alert.activeAt))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#666666"))
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#252525")), alignment: .bottom)
    }

    private func durationString(from activeAt: String?) -> String {
        guard let str = activeAt,
              let date = ISO8601DateFormatter().date(from: str) else { return "—" }
        let s = Int(-date.timeIntervalSinceNow)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}
