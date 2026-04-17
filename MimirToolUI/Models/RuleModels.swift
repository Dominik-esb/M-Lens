import Foundation

struct RuleNamespace: Identifiable {
    var id: String { name }
    let name: String
    var groups: [RuleGroup]
}

struct RuleGroup: Identifiable {
    var id: String { "\(namespace)/\(name)" }
    let namespace: String
    let name: String
    var rules: [Rule]
}

struct Rule: Identifiable {
    var id: String { "\(group)/\(ruleName)" }
    let group: String
    let ruleName: String
    let type: RuleType
    let yaml: String
    var namespace: String

    enum RuleType: String { case alerting, recording }
}
