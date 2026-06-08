import Foundation

struct Appliance: Decodable, Identifiable {
    let id: String
    let nickname: String
    let type: String
    let aircon: Aircon?

    var isAircon: Bool {
        type.uppercased() == "AC" && aircon != nil
    }
}

struct RemoDevice: Decodable, Identifiable {
    let id: String
    let name: String
    let newestEvents: [String: SensorEvent]?

    var roomTemperature: Double? {
        newestEvents?["te"]?.val
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case newestEvents = "newest_events"
    }
}

struct SensorEvent: Decodable {
    let val: Double?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case val
        case createdAt = "created_at"
    }
}

struct Aircon: Decodable {
    let range: AirconRange?
    let tempUnit: String?
    let settings: AirconSettings?

    enum CodingKeys: String, CodingKey {
        case range
        case tempUnit = "tempUnit"
        case settings
    }
}

struct AirconSettings: Decodable {
    let temp: String?
    let mode: String?
    let button: String?

    enum CodingKeys: String, CodingKey {
        case temp
        case mode
        case button
    }
}

struct AirconRange: Decodable {
    let modes: [String: AirconModeRange]?

    enum CodingKeys: String, CodingKey {
        case modes
    }
}

struct AirconModeRange: Decodable {
    let temp: [String]?

    enum CodingKeys: String, CodingKey {
        case temp
    }
}

enum OperationMode: String, CaseIterable {
    case cool
    case dry
    case warm

    var title: String {
        switch self {
        case .cool: "冷房"
        case .dry: "ドライ"
        case .warm: "暖房"
        }
    }
}
