import Foundation

// MARK: - Device

struct Device: Codable, Hashable, Identifiable {
    var id: String { udid }
    let udid: String
    let connectionType: String
    let isUsb: Bool
    let isNetwork: Bool

    enum CodingKeys: String, CodingKey {
        case udid
        case connectionType = "connection_type"
        case isUsb = "is_usb"
        case isNetwork = "is_network"
    }
}

// MARK: - Audit

enum Severity: String, Codable, CaseIterable {
    case info, low, medium, high, critical
}

enum FindingCategory: String, Codable {
    case priorCompromise = "prior_compromise"
    case posture
    case privacyLeak = "privacy_leak"
    case network
    case physical
    case informational
}

struct Finding: Codable, Identifiable, Hashable {
    var id: String
    let severity: Severity
    let category: FindingCategory
    let title: String
    let description: String
    let evidence: AnyCodable?
    let suggestedPayloads: [String]

    enum CodingKeys: String, CodingKey {
        case id, severity, category, title, description, evidence
        case suggestedPayloads = "suggested_payloads"
    }
}

struct AuditReport: Codable, Hashable {
    let udid: String
    let deviceModel: String
    let iosVersion: String
    let findings: [Finding]

    enum CodingKeys: String, CodingKey {
        case udid, findings
        case deviceModel = "device_model"
        case iosVersion = "ios_version"
    }

    var maxSeverity: Severity {
        let order: [Severity: Int] = [.info: 0, .low: 1, .medium: 2, .high: 3, .critical: 4]
        return findings.max(by: { (order[$0.severity] ?? 0) < (order[$1.severity] ?? 0) })?.severity ?? .info
    }
}

// MARK: - Recommendation

struct PayloadRecommendation: Codable, Hashable {
    let payloadType: String
    let rationale: String
    let fields: [String: AnyCodable]
    let addressesFindingIds: [String]

    enum CodingKeys: String, CodingKey {
        case payloadType = "payload_type"
        case rationale, fields
        case addressesFindingIds = "addresses_finding_ids"
    }
}

struct HardeningRecommendation: Codable, Hashable {
    let summary: String
    let riskLevel: String
    let payloads: [PayloadRecommendation]
    let userActions: [String]
    let deferredFindings: [String]

    enum CodingKeys: String, CodingKey {
        case summary, payloads
        case riskLevel = "risk_level"
        case userActions = "user_actions"
        case deferredFindings = "deferred_findings"
    }
}

// MARK: - Diff

struct DiffReport: Codable, Hashable {
    let resolved: [Finding]
    let unchanged: [Finding]
    let new: [Finding]
}

// MARK: - Build/install result

struct BuildProfileResult: Codable, Hashable {
    let profilePath: String
    let archivePath: String?
    let removalPassword: String
    let sizeBytes: Int

    enum CodingKeys: String, CodingKey {
        case profilePath = "profile_path"
        case archivePath = "archive_path"
        case removalPassword = "removal_password"
        case sizeBytes = "size_bytes"
    }
}

// MARK: - AnyCodable (for unstructured `evidence` blobs)

struct AnyCodable: Codable, Hashable {
    let value: Any?

    init(_ value: Any?) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = nil
        } else if let b = try? container.decode(Bool.self) {
            self.value = b
        } else if let i = try? container.decode(Int.self) {
            self.value = i
        } else if let d = try? container.decode(Double.self) {
            self.value = d
        } else if let s = try? container.decode(String.self) {
            self.value = s
        } else if let arr = try? container.decode([AnyCodable].self) {
            self.value = arr.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            self.value = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case nil: try container.encodeNil()
        case let b as Bool: try container.encode(b)
        case let i as Int: try container.encode(i)
        case let d as Double: try container.encode(d)
        case let s as String: try container.encode(s)
        case let arr as [Any?]: try container.encode(arr.map { AnyCodable($0) })
        case let dict as [String: Any?]: try container.encode(dict.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}
