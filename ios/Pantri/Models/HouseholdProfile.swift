import Foundation
import SwiftData

@Model
final class HouseholdProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var memberCount: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship
    var members: [UserProfile]?

    init(
        id: UUID = UUID(),
        name: String = "My Household",
        memberCount: Int = 1,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.memberCount = memberCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
