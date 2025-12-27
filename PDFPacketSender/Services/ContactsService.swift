//
//  ContactsService.swift
//  PDFPacketSender
//
//  Service for accessing device contacts
//

import Foundation
import Contacts

class ContactsService {
    private let store = CNContactStore()
    
    // Request contact access permission
    func requestAccess() async -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            print("Error requesting contacts access: \(error)")
            return false
        }
    }
    
    // Fetch all contacts with email addresses
    func fetchContacts() async -> [Recipient] {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        
        var recipients: [Recipient] = []
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                // Only include contacts with email addresses
                if !contact.emailAddresses.isEmpty {
                    recipients.append(Recipient.fromContact(contact))
                }
            }
        } catch {
            print("Error fetching contacts: \(error)")
        }
        
        return recipients
    }
    
    // Check current authorization status
    func authorizationStatus() -> CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }
}
