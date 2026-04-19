import SwiftUI
import AppKit

struct RemoteReadView: View {
    let environment: MimirEnvironment
    @StateObject private var vm: RemoteReadViewModel
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    @State private var showMetricBrowser = false
    @State private var showTimeSelector = false

    init(environment: MimirEnvironment) {
        self.environment = environment
        _vm = StateObject(wrappedValue: RemoteReadViewModel(
            runner: MimirtoolRunner.fromAppStorage(),
            environment: environment
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Remote Read").font(.system(size: 20, weight: .semibold)).foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }
                    .padding(.horizontal, 20).padding(.bottom, 8)
            }

            // Query form card
            VStack(spacing: 10) {
                // SELECTOR row
                HStack(spacing: 12) {
                    Text("SELECTOR")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        .tracking(0.7).frame(width: 80, alignment: .leading)
                    TextField("{job=\"node-exporter\"}", text: $vm.selector)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(t.textBody)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(t.inputBg)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(t.borderSub, lineWidth: 1))
                        .cornerRadius(7)
                    Button {
                        showMetricBrowser = true
                        Task { await vm.loadMetrics() }
                    } label: {
                        Image(systemName: "list.bullet.magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(t.iconColor)
                            .frame(width: 30, height: 30)
                            .background(t.inputBg)
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(t.borderSub, lineWidth: 1))
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .help("Browse available metrics")
                    .popover(isPresented: $showMetricBrowser) {
                        MetricBrowserPopover(vm: vm, isPresented: $showMetricBrowser)
                    }
                }

                // TIME RANGE row
                HStack(spacing: 12) {
                    Text("TIME")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        .tracking(0.7).frame(width: 80, alignment: .leading)
                    Button {
                        showTimeSelector.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(t.iconColor)
                            Text(vm.timeRangeLabel)
                                .font(.system(size: 13))
                                .foregroundColor(t.textBody)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(t.textMuted)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(t.inputBg)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(t.borderSub, lineWidth: 1))
                        .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTimeSelector) {
                        TimeRangeSelectorPopover(vm: vm, isPresented: $showTimeSelector)
                    }
                }

                HStack {
                    Spacer()
                    Button { exportCSV() } label: {
                        Label("Export CSV", systemImage: "arrow.down").font(.system(size: 12))
                    }.buttonStyle(SecondaryButtonStyle())
                    Button { Task { await vm.runQuery() } } label: {
                        Label(vm.isLoading ? "Running…" : "Run Query", systemImage: "play.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(vm.isLoading)
                }
            }
            .padding(16)
            .background(t.surface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 12)

            // Results card
            VStack(spacing: 0) {
                HStack {
                    Text("RESULTS").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary).tracking(0.7)
                    Spacer()
                    if !vm.results.isEmpty {
                        Text("\(vm.results.count) series").font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(t.surfaceAlt)
                .overlay(Rectangle().frame(height: 1).foregroundColor(t.headerLine), alignment: .bottom)

                HStack {
                    Text("METRIC").tableHeader().frame(width: 180, alignment: .leading)
                    Text("LABELS").tableHeader()
                    Spacer()
                    Text("VALUE").tableHeader().frame(width: 80, alignment: .trailing)
                    Text("TIMESTAMP").tableHeader().frame(width: 140, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(t.surface)
                .overlay(Rectangle().frame(height: 1).foregroundColor(t.headerLine), alignment: .bottom)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.results) { r in
                            HStack {
                                Text(r.metricName)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(hex: "#7ab3f0"))
                                    .frame(width: 180, alignment: .leading).lineLimit(1)
                                Text(r.labels.sorted { $0.key < $1.key }.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: ", "))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Text(r.latestValue)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(hex: "#4ade80"))
                                    .frame(width: 80, alignment: .trailing)
                                Text(r.timestamp)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 140, alignment: .trailing)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .overlay(Rectangle().frame(height: 1).foregroundColor(t.divider), alignment: .bottom)
                        }
                        if vm.results.isEmpty && !vm.isLoading {
                            Text("Run a query to see results")
                                .foregroundStyle(.tertiary).padding(32)
                        }
                    }
                }

                StatusBarView(environment: environment,
                              statusText: vm.queryDuration.map { "Queried in \($0)" } ?? "")
            }
            .background(t.surface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(t.bg)
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "remote-read-export.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? vm.exportCSV(to: url)
        }
    }
}

// MARK: - Metric Browser Popover

private struct MetricBrowserPopover: View {
    @ObservedObject var vm: RemoteReadViewModel
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(t.textMuted)
                TextField("Search metrics…", text: $vm.metricSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(t.inputBg)
            .overlay(Rectangle().frame(height: 1).foregroundColor(t.borderSub), alignment: .bottom)

            if vm.isFetchingMetrics {
                VStack {
                    Spacer()
                    ProgressView("Loading metrics…").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                }
            } else if vm.filteredMetrics.isEmpty {
                VStack {
                    Spacer()
                    Text(vm.availableMetrics.isEmpty ? "No metrics found" : "No matches")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.filteredMetrics, id: \.self) { name in
                            Button {
                                vm.selector = "{__name__=\"\(name)\"}"
                                vm.metricSearchText = ""
                                isPresented = false
                            } label: {
                                HStack {
                                    Text(name)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(t.textBody)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .overlay(Rectangle().frame(height: 1).foregroundColor(t.divider), alignment: .bottom)
                        }
                    }
                }
            }
        }
        .frame(width: 280, height: 320)
        .background(t.surface)
    }
}

// MARK: - Time Range Selector Popover

private struct TimeRangeSelectorPopover: View {
    @ObservedObject var vm: RemoteReadViewModel
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    private var t: Theme { Theme(colorScheme) }

    private let presets: [(label: String, hours: Double)] = [
        ("Last 15m", 0.25),
        ("Last 1h",  1),
        ("Last 6h",  6),
        ("Last 24h", 24),
        ("Last 7d",  168)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK RANGES")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.7)

            // Preset grid
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(presets, id: \.label) { preset in
                    Button {
                        let now = Date()
                        vm.toDate = now
                        vm.fromDate = Date(timeIntervalSinceNow: -preset.hours * 3600)
                        isPresented = false
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(t.surfaceAlt)
                            .foregroundColor(t.textSub)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(t.border, lineWidth: 1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Text("CUSTOM RANGE")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.7)

            HStack(spacing: 8) {
                Text("From").font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 32, alignment: .trailing)
                DatePicker("", selection: $vm.fromDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            HStack(spacing: 8) {
                Text("To").font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 32, alignment: .trailing)
                DatePicker("", selection: $vm.toDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(t.surface)
    }
}
