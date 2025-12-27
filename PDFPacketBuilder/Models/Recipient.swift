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
        switch key.lowercased() {
        case "firstname": return firstName
        case "lastname": return lastName
        case "fullname", "name": return fullName
        case "email": return email
        case "phone", "phonenumber": return phoneNumber
        default: return customFields[key]
        }
    }
}
