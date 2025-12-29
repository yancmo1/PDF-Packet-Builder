//
//  Recipient.swift
//  PDFPacketSender
//
//  Model for recipient data
//

import Foundation
import Contacts

struct Recipient: Codable, Identifiable, Hashable {
    let id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String?
    var customFields: [String: String] // For CSV import with custom columns
    var source: RecipientSource
    
    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    enum RecipientSource: String, Codable {
        case contacts
        case csv
        case manual
    }
    
    init(id: UUID = UUID(), firstName: String, lastName: String, email: String, phoneNumber: String? = nil, customFields: [String: String] = [:], source: RecipientSource = .manual) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.customFields = customFields
        self.source = source
    }
    
    // Create recipient from CNContact
    static func fromContact(_ contact: CNContact) -> Recipient {
        Recipient(
            firstName: contact.givenName,
            lastName: contact.familyName,
            email: contact.emailAddresses.first?.value as String? ?? "",
            phoneNumber: contact.phoneNumbers.first?.value.stringValue,
            source: .contacts
        )
    }
    
    // Get value for a specific field key
    func value(forKey key: String) -> String? {
        let raw = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = raw.lowercased()

        // Built-in aliases (supports common CSV header variations too).
        switch lower {
        case "firstname", "first_name", "first name", "givenname", "given_name", "given name":
            return firstName
        case "lastname", "last_name", "last name", "surname", "familyname", "family_name", "family name":
            return lastName
        case "fullname", "full_name", "full name", "name":
            return fullName
        case "email", "emailaddress", "email_address", "email address", "e-mail", "e-mailaddress", "e-mail address":
            return email
        case "phone", "phonenumber", "phone_number", "phone number", "mobile", "tel", "telephone":
            return phoneNumber
        default:
            break
        }

        // Exact match (preserves predictability when mapping to a specific custom header).
        if let exact = customFields[raw] {
            return exact
        }

        // Deterministic case-insensitive match (only if unique).
        let caseInsensitiveMatches = customFields.filter { $0.key.lowercased() == lower }
        if caseInsensitiveMatches.count == 1 {
            return caseInsensitiveMatches.first?.value
        }

        // Normalized match (only if unique) to support headers like "Date 1" -> "Date".
        let target = NormalizedName.from(raw).tokenSet
        if !target.isEmpty {
            let normalizedMatches = customFields.keys.filter { NormalizedName.from($0).tokenSet == target }
            if normalizedMatches.count == 1 {
                return customFields[normalizedMatches[0]]
            }
        }

        // Ambiguous or missing.
        return nil
    }
}
