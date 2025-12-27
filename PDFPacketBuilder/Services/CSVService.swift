//
//  CSVService.swift
//  PDFPacketSender
//
//  Service for importing recipients from CSV
//

import Foundation

class CSVService {

    struct CSVPreview: Hashable {
        var headers: [String]
        var rows: [[String]]
    }
    
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

    // Parse CSV for header + sample rows preview.
    // Keeps parsing intentionally small while supporting quotes, commas, escaped quotes, and mixed line endings.
    func parsePreview(data: String, maxRows: Int = 20) -> CSVPreview {
        let allRows = parseRows(data)
        guard let headerRow = allRows.first else {
            return CSVPreview(headers: [], rows: [])
        }

        let headers = headerRow
        let sample = Array(allRows.dropFirst().prefix(maxRows))

        let maxColumns = max(headers.count, sample.map { $0.count }.max() ?? 0)
        let normalizedHeaders: [String] = (0..<maxColumns).map { idx in
            if idx < headers.count {
                return headers[idx]
            }
            return ""
        }
        let normalizedRows: [[String]] = sample.map { row in
            (0..<maxColumns).map { idx in
                if idx < row.count {
                    return row[idx]
                }
                return ""
            }
        }

        return CSVPreview(headers: normalizedHeaders, rows: normalizedRows)
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

    private func parseRows(_ data: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false

        func commitField() {
            row.append(field.trimmingCharacters(in: .whitespacesAndNewlines))
            field = ""
        }

        func commitRow() {
            // Skip completely empty trailing rows.
            if row.count == 1 && row[0].isEmpty {
                row.removeAll(keepingCapacity: true)
                return
            }
            if !row.isEmpty {
                rows.append(row)
            }
            row.removeAll(keepingCapacity: true)
        }

        var index = data.startIndex
        while index < data.endIndex {
            let ch = data[index]

            if insideQuotes {
                if ch == "\"" {
                    let next = data.index(after: index)
                    if next < data.endIndex, data[next] == "\"" {
                        field.append("\"")
                        index = data.index(after: next)
                        continue
                    } else {
                        insideQuotes = false
                        index = data.index(after: index)
                        continue
                    }
                } else {
                    field.append(ch)
                    index = data.index(after: index)
                    continue
                }
            }

            switch ch {
            case "\"":
                insideQuotes = true
                index = data.index(after: index)
            case ",":
                commitField()
                index = data.index(after: index)
            case "\n":
                commitField()
                commitRow()
                index = data.index(after: index)
            case "\r":
                commitField()
                commitRow()
                let next = data.index(after: index)
                if next < data.endIndex, data[next] == "\n" {
                    index = data.index(after: next)
                } else {
                    index = next
                }
            default:
                field.append(ch)
                index = data.index(after: index)
            }
        }

        if insideQuotes {
            // Best-effort: treat the remaining buffer as a field.
            insideQuotes = false
        }

        if !field.isEmpty || !row.isEmpty {
            commitField()
            commitRow()
        }

        return rows
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
