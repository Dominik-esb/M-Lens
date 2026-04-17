import Foundation
import Combine

@MainActor
final class AlertsViewModel: ObservableObject {
    enum AlertFilter { case all, firing, pending }

    @Published var alerts: [MimirAlert] = []
    @Published var filter: AlertFilter = .all
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefreshed: Date?
    @Published var autoRefresh: Bool = false

    private let service: any AlertsFetching
    private let environment: MimirEnvironment
    private var autoRefreshTask: Task<Void, Never>?

    init(service: any AlertsFetching = AlertsService(), environment: MimirEnvironment) {
        self.service = service
        self.environment = environment
    }

    var filtered: [MimirAlert] {
        alerts.filter { alert in
            let stateMatch: Bool = {
                switch filter {
                case .all: return true
                case .firing: return alert.state == .firing
                case .pending: return alert.state == .pending
                }
            }()
            let searchMatch = searchText.isEmpty ||
                alert.labels.contains { k, v in
                    "\(k)=\(v)".localizedCaseInsensitiveContains(searchText)
                }
            return stateMatch && searchMatch
        }
    }

    var firingCount: Int { alerts.filter { $0.state == .firing }.count }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            alerts = try await service.fetch(for: environment)
            lastRefreshed = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func setAutoRefresh(_ enabled: Bool) {
        autoRefresh = enabled
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        guard enabled else { return }
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.load()
            }
        }
    }
}
