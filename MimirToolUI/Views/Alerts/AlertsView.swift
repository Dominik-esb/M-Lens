import SwiftUI

struct AlertsView: View {
    let environment: MimirEnvironment
    @StateObject private var vm: AlertsViewModel
    @State private var selectedAlert: MimirAlert?
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    init(environment: MimirEnvironment) {
        self.environment = environment
        _vm = StateObject(wrappedValue: AlertsViewModel(environment: environment))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text("Alerts")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(.primary)
                Spacer()
                Toggle("Auto-refresh", isOn: Binding(
                    get: { vm.autoRefresh },
                    set: { vm.setAutoRefresh($0) }
                ))
                .toggleStyle(.switch)
                .font(.system(size: 12)).foregroundStyle(.secondary)
                Button { Task { await vm.load() } } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(t.iconColor)
                        .rotationEffect(.degrees(vm.isLoading ? 360 : 0))
                        .animation(vm.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.isLoading)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            // Filter bar
            HStack(spacing: 8) {
                filterChip("All", count: vm.alerts.count, active: vm.filter == .all,
                           color: t.navActiveBg, fg: Color(hex: "#7ab3f0")) { vm.filter = .all }
                filterChip("Firing", count: vm.alerts.filter { $0.state == .firing }.count,
                           active: vm.filter == .firing,
                           color: t.tagAlertBg, fg: Color(hex: "#f87171")) { vm.filter = .firing }
                filterChip("Pending", count: vm.alerts.filter { $0.state == .pending }.count,
                           active: vm.filter == .pending,
                           color: t.tagPendBg, fg: Color(hex: "#fbbf24")) { vm.filter = .pending }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(t.textFaint).font(.system(size: 12))
                    TextField("Filter by label…", text: $vm.searchText)
                        .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(t.searchBg)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(t.borderSub, lineWidth: 1))
                .frame(width: 220)
            }
            .padding(.horizontal, 20).padding(.bottom, 12)

            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }
                    .padding(.horizontal, 20).padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Table
            VStack(spacing: 0) {
                HStack {
                    Text("ALERT NAME").tableHeader().frame(width: 200, alignment: .leading)
                    Text("STATE").tableHeader().frame(width: 80, alignment: .leading)
                    Text("LABELS").tableHeader()
                    Spacer()
                    Text("DURATION").tableHeader().frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(t.surfaceAlt)
                .overlay(Rectangle().frame(height: 1).foregroundColor(t.headerLine), alignment: .bottom)

                ScrollView {
                    VStack(spacing: 0) {
                        if vm.isLoading && vm.alerts.isEmpty {
                            ProgressView().padding(40)
                        } else if !vm.isLoading && vm.filtered.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bell.slash").font(.system(size: 28))
                                    .foregroundStyle(.tertiary)
                                Text(vm.alerts.isEmpty ? "No alerts found." : "No alerts match the current filter.")
                                    .foregroundStyle(.secondary).font(.system(size: 13))
                            }
                            .padding(40)
                        } else {
                            ForEach(vm.filtered, id: \.uniqueID) { alert in
                                AlertRowView(alert: alert) {
                                    withAnimation(.easeOut(duration: 0.15)) { selectedAlert = alert }
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: vm.filtered.count)
                }

                StatusBarView(
                    environment: environment,
                    statusText: vm.lastRefreshed.map { "Refreshed \(timeAgo($0))" } ?? ""
                )
            }
            .background(t.surface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(t.bg)
        .task { await vm.load() }
        .sheet(item: $selectedAlert) { alert in
            AlertDetailSheet(alert: alert)
        }
    }

    @ViewBuilder
    private func filterChip(_ label: String, count: Int, active: Bool, color: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label).font(.system(size: 12))
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(active ? fg.opacity(0.2) : t.inputBg)
                    .foregroundColor(active ? fg : t.textMuted)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(active ? color : t.inputBg)
            .foregroundColor(active ? fg : t.textMuted)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(active ? fg.opacity(0.25) : t.borderSub, lineWidth: 1))
            .cornerRadius(16)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.15), value: active)
        }.buttonStyle(.plain)
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(-date.timeIntervalSinceNow)
        if s < 10 { return "just now" }
        if s < 60 { return "\(s)s ago" }
        return "\(s / 60)m ago"
    }
}

// MARK: - Alert Row

private struct AlertRowView: View {
    let alert: MimirAlert
    let onTap: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 0) {
                Text(alert.labels["alertname"] ?? "unknown")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 200, alignment: .leading)
                    .lineLimit(1)

                TagView(text: alert.state.rawValue, style: alert.state == .firing ? .firing : .pending)
                    .frame(width: 80, alignment: .leading)

                FlowLayout(spacing: 4) {
                    ForEach(
                        alert.labels.filter { $0.key != "alertname" }.sorted { $0.key < $1.key },
                        id: \.key
                    ) { pair in
                        Text("\(pair.key)=\(pair.value)")
                            .font(.system(size: 10, design: .monospaced))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(t.inputBg)
                            .foregroundColor(t.textMuted)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(t.borderSub, lineWidth: 1))
                            .cornerRadius(4)
                    }
                }

                Spacer(minLength: 8)

                Text(durationString(from: alert.activeAt))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(t.textFaint)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(isHovered ? t.rowHover : Color.clear)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.1), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .overlay(Rectangle().frame(height: 1).foregroundColor(t.rowLine), alignment: .bottom)
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

// MARK: - Alert Detail Sheet

private struct AlertDetailSheet: View {
    let alert: MimirAlert
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(alert.labels["alertname"] ?? "Alert")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary)
                    TagView(text: alert.state.rawValue, style: alert.state == .firing ? .firing : .pending)
                }
                Spacer()
                Button("Close") { dismiss() }.buttonStyle(SecondaryButtonStyle())
            }
            .padding(20)
            .background(t.surfaceAlt)
            .overlay(Rectangle().frame(height: 1).foregroundColor(t.sectionLine), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let activeAt = alert.activeAt,
                       let date = ISO8601DateFormatter().date(from: activeAt) {
                        detailSection("Timeline") {
                            detailRow("Active since", value: formatDate(date))
                            detailRow("Duration", value: durationString(from: alert.activeAt))
                        }
                    }

                    detailSection("Labels") {
                        let sorted = alert.labels.sorted { $0.key < $1.key }
                        ForEach(sorted, id: \.key) { pair in
                            HStack(spacing: 0) {
                                Text(pair.key)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 160, alignment: .leading)
                                Text(pair.value)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(t.textSub)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .overlay(Rectangle().frame(height: 1).foregroundColor(t.divider), alignment: .bottom)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 520, height: 440)
        .background(t.surface)
    }

    @ViewBuilder
    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.7)
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

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
            Text(value).font(.system(size: 12)).foregroundColor(t.textSub).textSelection(.enabled)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .overlay(Rectangle().frame(height: 1).foregroundColor(t.divider), alignment: .bottom)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    private func durationString(from activeAt: String?) -> String {
        guard let str = activeAt,
              let date = ISO8601DateFormatter().date(from: str) else { return "—" }
        let s = Int(-date.timeIntervalSinceNow)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(s % 60)s" }
        return "\(s / 3600)h \((s % 3600) / 60)m"
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width { y += rowH + spacing; x = 0; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: max(y + rowH, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}

// MARK: - MimirAlert helpers

extension MimirAlert {
    var uniqueID: String {
        let sorted = labels.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        return "\(state.rawValue)|\(sorted)"
    }
}
