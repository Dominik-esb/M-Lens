import SwiftUI
import AppKit

struct RemoteReadView: View {
    let environment: MimirEnvironment
    @StateObject private var vm: RemoteReadViewModel

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
                Text("Remote Read").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            if let err = vm.errorMessage {
                ErrorBannerView(message: err) { vm.errorMessage = nil }
                    .padding(.horizontal, 20).padding(.bottom, 8)
            }

            // Query form card
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Text("SELECTOR")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#555555"))
                        .tracking(0.7).frame(width: 80, alignment: .leading)
                    TextField("{job=\"node-exporter\"}", text: $vm.selector)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(hex: "#d0d0d0"))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(hex: "#272727"))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#333333"), lineWidth: 1))
                        .cornerRadius(7)
                }
                HStack(spacing: 12) {
                    Text("FROM")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#555555"))
                        .tracking(0.7).frame(width: 80, alignment: .leading)
                    DatePicker("", selection: $vm.fromDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden().colorScheme(.dark)
                    Text("TO")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "#555555"))
                        .tracking(0.7).frame(width: 30, alignment: .center)
                    DatePicker("", selection: $vm.toDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden().colorScheme(.dark)
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
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 12)

            // Results card
            VStack(spacing: 0) {
                HStack {
                    Text("RESULTS").font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#555555")).tracking(0.7)
                    Spacer()
                    if !vm.results.isEmpty {
                        Text("\(vm.results.count) series").font(.system(size: 11)).foregroundColor(Color(hex: "#444444"))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(hex: "#1a1a1a"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

                HStack {
                    Text("METRIC").tableHeader().frame(width: 180, alignment: .leading)
                    Text("LABELS").tableHeader()
                    Spacer()
                    Text("VALUE").tableHeader().frame(width: 80, alignment: .trailing)
                    Text("TIMESTAMP").tableHeader().frame(width: 140, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(hex: "#1e1e1e"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#2a2a2a")), alignment: .bottom)

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
                                    .foregroundColor(Color(hex: "#888888"))
                                    .lineLimit(1)
                                Spacer()
                                Text(r.latestValue)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(hex: "#a8d8a8"))
                                    .frame(width: 80, alignment: .trailing)
                                Text(r.timestamp)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(hex: "#555555"))
                                    .frame(width: 140, alignment: .trailing)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#252525")), alignment: .bottom)
                        }
                        if vm.results.isEmpty && !vm.isLoading {
                            Text("Run a query to see results")
                                .foregroundColor(Color(hex: "#444444")).padding(32)
                        }
                    }
                }

                StatusBarView(environment: environment,
                              statusText: vm.queryDuration.map { "Queried in \($0)" } ?? "")
            }
            .background(Color(hex: "#1e1e1e"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2e2e2e"), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
            .padding(.horizontal, 20).padding(.bottom, 16)
        }
        .background(Color(hex: "#242424"))
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
