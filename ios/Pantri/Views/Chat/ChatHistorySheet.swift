import SwiftUI

struct ChatHistorySheet: View {
    let sessions: [ChatSession]
    let onSelect: (ChatSession) -> Void
    let onDelete: (ChatSession) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.pantriGreen.opacity(0.35))
                        Text("No conversations yet")
                            .font(.headline)
                            .foregroundStyle(Color.pantriText)
                        Text("Your chat history will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(Color.pantriSecondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedSessions, id: \.key) { group in
                            Section(group.key) {
                                ForEach(group.sessions) { session in
                                    sessionRow(session)
                                }
                                .onDelete { offsets in
                                    for offset in offsets {
                                        onDelete(group.sessions[offset])
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.pantriBackground.ignoresSafeArea())
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.pantriGreen)
                }
            }
        }
    }

    private func sessionRow(_ session: ChatSession) -> some View {
        Button {
            onSelect(session)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pantriText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(session.messages.count) messages")
                        .font(.caption)
                        .foregroundStyle(Color.pantriSecondaryText)

                    Text("·")
                        .foregroundStyle(Color.pantriTertiaryText)

                    Text(session.date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(Color.pantriTertiaryText)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Grouping

    private struct SessionGroup: Identifiable {
        let key: String
        let sessions: [ChatSession]
        var id: String { key }
    }

    private var groupedSessions: [SessionGroup] {
        let calendar = Calendar.current
        let now = Date.now

        var today: [ChatSession] = []
        var yesterday: [ChatSession] = []
        var thisWeek: [ChatSession] = []
        var older: [ChatSession] = []

        for session in sessions {
            if calendar.isDateInToday(session.date) {
                today.append(session)
            } else if calendar.isDateInYesterday(session.date) {
                yesterday.append(session)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      session.date >= weekAgo {
                thisWeek.append(session)
            } else {
                older.append(session)
            }
        }

        var groups: [SessionGroup] = []
        if !today.isEmpty { groups.append(SessionGroup(key: "Today", sessions: today)) }
        if !yesterday.isEmpty { groups.append(SessionGroup(key: "Yesterday", sessions: yesterday)) }
        if !thisWeek.isEmpty { groups.append(SessionGroup(key: "This Week", sessions: thisWeek)) }
        if !older.isEmpty { groups.append(SessionGroup(key: "Older", sessions: older)) }
        return groups
    }
}
