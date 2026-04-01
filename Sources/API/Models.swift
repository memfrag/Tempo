import Foundation

// MARK: - API Response Models

struct UserRef: Codable, Identifiable, Hashable {
    let id: Int
    let email: String
    let firstName: String
    let lastName: String
    let profileImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, email
        case firstName = "first_name"
        case lastName = "last_name"
        case profileImageUrl = "profile_image_url"
    }

    var displayName: String {
        "\(firstName) \(lastName)"
    }
}

struct ProjectRef: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let billingIncrement: Int?
    let enabled: Bool?
    let billable: Bool?
    let color: String?

    enum CodingKeys: String, CodingKey {
        case id, name, color, enabled, billable
        case billingIncrement = "billing_increment"
    }
}

struct TagRef: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let billable: Bool
    let formattedName: String

    enum CodingKeys: String, CodingKey {
        case id, name, billable
        case formattedName = "formatted_name"
    }
}

// MARK: - Entry

struct NokoEntry: Codable, Identifiable, Hashable {
    let id: Int
    let date: String
    let minutes: Int
    let description: String?
    let project: ProjectRef?
    let tags: [TagRef]
    let user: UserRef
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, date, minutes, description, project, tags, user
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: date)
    }

    var hours: Double {
        Double(minutes) / 60.0
    }

    var formattedDuration: String {
        TimeFormatter.minutesToDisplay(minutes)
    }
}

// MARK: - Project

struct NokoProject: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let color: String?
    let billingIncrement: Int
    let enabled: Bool
    let billable: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, color, enabled, billable
        case billingIncrement = "billing_increment"
    }
}

// MARK: - User

struct NokoUser: Codable, Identifiable {
    let id: Int
    let email: String
    let firstName: String
    let lastName: String
    let profileImageUrl: String?
    let state: String

    enum CodingKeys: String, CodingKey {
        case id, email, state
        case firstName = "first_name"
        case lastName = "last_name"
        case profileImageUrl = "profile_image_url"
    }

    var displayName: String {
        "\(firstName) \(lastName)"
    }
}

// MARK: - Tag

struct NokoTag: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let billable: Bool
    let formattedName: String
    let entries: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, billable, entries
        case formattedName = "formatted_name"
    }
}

// MARK: - Create/Update payloads

struct CreateEntryPayload: Codable {
    let date: String
    let minutes: Int
    let projectId: Int?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case date, minutes, description
        case projectId = "project_id"
    }
}

struct UpdateEntryPayload: Codable {
    let date: String?
    let minutes: Int?
    let projectId: Int?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case date, minutes, description
        case projectId = "project_id"
    }
}

