import Foundation

enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let bool = try? value.decode(Bool.self) { self = .bool(bool) }
        else if let number = try? value.decode(Double.self) { self = .number(number) }
        else if let string = try? value.decode(String.self) { self = .string(string) }
        else if let array = try? value.decode([JSONValue].self) { self = .array(array) }
        else { self = .object(try value.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let item): try value.encode(item)
        case .number(let item): try value.encode(item)
        case .bool(let item): try value.encode(item)
        case .array(let item): try value.encode(item)
        case .object(let item): try value.encode(item)
        case .null: try value.encodeNil()
        }
    }

    var stringValue: String? { if case .string(let value) = self { return value }; return nil }
    var boolValue: Bool? { if case .bool(let value) = self { return value }; return nil }
    var numberValue: Double? { if case .number(let value) = self { return value }; return nil }
    var arrayValue: [JSONValue]? { if case .array(let value) = self { return value }; return nil }
    var objectValue: [String: JSONValue]? { if case .object(let value) = self { return value }; return nil }

    static func object<T: Encodable>(_ value: T) throws -> [String: JSONValue] {
        try JSONDecoder().decode([String: JSONValue].self, from: JSONEncoder().encode(value))
    }
}

struct OnlineRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let owner_id: UUID
    let kind: String
    let parent_id: UUID?
    var body: [String: JSONValue]
    let version: Int
    let created_at: String
    let updated_at: String

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(body))
    }
}

struct OnlinePage: Codable, Sendable {
    let records: [OnlineRecord]
    let next_cursor: String?
}

struct OnlineMutationReceipt: Codable, Sendable {
    let entity_id: UUID
    let version: Int
    let status: String
}

enum TotiBackendError: LocalizedError {
    case rolloutClosed, sessionRequired, accountChanged, invalidEmail, invalidCode, invalidAgreement
    case incompletePage, invalidResponse, pendingChange, localPersistence, deletionPending, deletionUnavailable
    case pendingPayloadUnavailable, morePendingOperations, secureSessionUnavailable, invalidMedia

    var errorDescription: String? {
        switch self {
        case .rolloutClosed: return "Online Guest access is not enabled in this build. Your previous local library has been preserved."
        case .sessionRequired: return "Sign in again to continue."
        case .accountChanged: return "Your account changed. Reopen this screen before continuing."
        case .invalidEmail: return "Enter a valid email address."
        case .invalidCode: return "Enter the verification code from your email."
        case .invalidAgreement: return "The current agreements are unavailable. Please try again later."
        case .incompletePage: return "More results are available. Load the next page to continue."
        case .invalidResponse: return "The service returned an unexpected response. Please try again."
        case .pendingChange: return "A previous change is awaiting confirmation. Use Retry pending changes before editing it again."
        case .morePendingOperations: return "Some changes were confirmed. Use Retry pending changes again to continue."
        case .pendingPayloadUnavailable: return "An older pending change needs its original content. Reopen that item and retry the same change to recover it."
        case .secureSessionUnavailable: return "Secure sign-in storage is unavailable. Restart Toti and try again."
        case .invalidMedia: return "Choose a JPEG photo up to 1 MB and 1,200 pixels per side. The service could not validate this photo."
        case .localPersistence: return "The secure retry record could not be saved. Check available storage and try again."
        case .deletionPending: return "Account cleanup is pending. You have been signed out."
        case .deletionUnavailable: return "Account deletion is not available yet. No data has been removed."
        }
    }
}
