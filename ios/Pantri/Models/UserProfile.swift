import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var email: String?
    var householdId: UUID?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(inverse: \HouseholdProfile.members)
    var household: HouseholdProfile?

    init(
        id: UUID = UUID(),
        displayName: String,
        email: String? = nil,
        householdId: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.householdId = householdId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
