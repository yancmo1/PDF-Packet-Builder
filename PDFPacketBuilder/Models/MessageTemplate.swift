import Foundation

struct MessageTemplate: Codable, Hashable {
    var subject: String
    var body: String
    var isEnabled: Bool
    var lastEdited: Date?
    /// Optional per-template overrides that bind a token name to a CSV header.
    /// When empty, CSV-derived tokens default to their matching header.
    var tokenBindings: [String: String]

    init(subject: String = "", body: String = "", isEnabled: Bool = false, lastEdited: Date? = nil, tokenBindings: [String: String] = [:]) {
        self.subject = subject
        self.body = body
        self.isEnabled = isEnabled
        self.lastEdited = lastEdited
        self.tokenBindings = tokenBindings
    }

    var hasAnyContent: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var emptyDisabled: MessageTemplate {
        MessageTemplate(subject: "", body: "", isEnabled: false, lastEdited: nil, tokenBindings: [:])
    }

    static var starterEnabled: MessageTemplate {
        MessageTemplate(
            subject: "Permission Slip – {{recipient_name}}",
            body: "Dear Parent,\n\nPlease see the attached permission slip for {{recipient_name}}.\nFill it out and return it promptly.\n\nThank you,\n{{sender_name}}",
            isEnabled: true,
            lastEdited: Date(),
            tokenBindings: [:]
        )
    }
}
