//
//  CSVService.swift
//  PDFPacketSender
//
//  Service for importing recipients from CSV
//

import Foundation

class CSVService {
    
    // Parse CSV data into recipients
    func parseCSV(data: String) -> [Recipient] {
        var recipients: [Recipient] = []
        let lines = data.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        guard lines.count > 1 else { return [] }
        
        // Parse header
        let headers = parseCSVLine(lines[0])
        
        // Parse rows
        for i in 1..<lines.count {
            let values = parseCSVLine(lines[i])
            guard values.count == headers.count else { continue }
            
            var firstName = ""
            var lastName = ""
            var email = ""
            var phoneNumber: String?
            var customFields: [String: String] = [:]
            
            for (index, header) in headers.enumerated() {
                let value = values[index]
                let headerLower = header.lowercased().trimmingCharacters(in: .whitespaces)
                
                switch headerLower {
                case "firstname", "first_name", "first name":
                    firstName = value
                case "lastname", "last_name", "last name":
                    lastName = value
                case "email", "email address", "e-mail":
                    email = value
                case "phone", "phonenumber", "phone_number", "phone number":
                    phoneNumber = value
                default:
                    customFields[header] = value
                }
            }
            
            // Only create recipient if email is present
            if !email.isEmpty {
                let recipient = Recipient(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    phoneNumber: phoneNumber,
                    customFields: customFields,
                    source: .csv
                )
                recipients.append(recipient)
            }
        }
        
        return recipients
    }
    
    // Parse a single CSV line (handles quoted values with commas)
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        return fields
    }
    
    // Export recipients as CSV
    func exportToCSV(recipients: [Recipient]) -> String {
        var csv = "First Name,Last Name,Email,Phone Number\n"
        
        for recipient in recipients {
            let phone = recipient.phoneNumber ?? ""
            csv += "\(recipient.firstName),\(recipient.lastName),\(recipient.email),\(phone)\n"
        }
        
        return csv
    }
}
