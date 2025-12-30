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

    struct EmailColumnDetection {
        var selectedHeader: String?
        var confidenceByHeader: [String: Double]
    }

    struct DisplayNameColumnDetection {
        var selectedHeader: String?
        var confidenceByHeader: [String: Double]
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

            // Create a recipient even if email is missing; mailing can be disabled / warned later.
            // Avoid importing completely empty rows.
            let hasAnyValue = !firstName.isEmpty || !lastName.isEmpty || !email.isEmpty || (phoneNumber?.isEmpty == false) || customFields.values.contains { !$0.isEmpty }
            guard hasAnyValue else { continue }

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

    func detectEmailColumn(preview: CSVPreview, sampleLimit: Int = 25) -> EmailColumnDetection {
        let headers = preview.headers
        let rows = Array(preview.rows.prefix(sampleLimit))

        var scores: [String: Double] = [:]
        scores.reserveCapacity(headers.count)

        for (idx, headerRaw) in headers.enumerated() {
            let header = headerRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !header.isEmpty else { continue }

            let headerTokens = NormalizedName.from(header).tokens
            let headerScore = headerSignalScore(tokens: headerTokens)
            let headerPenalty = headerNegativePenalty(tokens: headerTokens)

            let sampleValues: [String] = rows.compactMap { row in
                guard idx < row.count else { return nil }
                let value = row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }

            let valueScore = emailValueScore(sampleValues: sampleValues)

            // Value shape is the strongest signal: allows detection even when headers are generic.
            // Clamp to 0...1 after applying penalties.
            let combined = max(0.0, min(1.0, (0.90 * valueScore) + (0.10 * headerScore) + headerPenalty))
            scores[header] = combined
        }

        // Decision rule: select exactly one "winner" above threshold.
        // If ambiguous or none, return nil (user must choose).
        let threshold = 0.85
        let winners = scores
            .filter { $0.value >= threshold }
            .sorted { $0.value > $1.value }

        guard let best = winners.first else {
            return EmailColumnDetection(selectedHeader: nil, confidenceByHeader: scores)
        }

        if winners.count >= 2 {
            let second = winners[1]
            // Require clear separation; otherwise it's ambiguous.
            if (best.value - second.value) < 0.15 {
                return EmailColumnDetection(selectedHeader: nil, confidenceByHeader: scores)
            }
        }

        return EmailColumnDetection(selectedHeader: best.key, confidenceByHeader: scores)
    }

    // Presentation-only: detect a "display name" column to show in lists.
    // This must remain separate from routing (email) and mapping (PDF field mapping).
    func detectDisplayNameColumn(preview: CSVPreview, sampleLimit: Int = 25) -> DisplayNameColumnDetection {
        let headers = preview.headers
        let rows = Array(preview.rows.prefix(sampleLimit))

        var scores: [String: Double] = [:]
        scores.reserveCapacity(headers.count)

        for (idx, headerRaw) in headers.enumerated() {
            let header = headerRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !header.isEmpty else { continue }

            let headerTokens = NormalizedName.from(header).tokens
            let headerScore = displayNameHeaderSignalScore(tokens: headerTokens)
            let headerPenalty = displayNameHeaderNegativePenalty(tokens: headerTokens)

            let sampleValues: [String] = rows.compactMap { row in
                guard idx < row.count else { return nil }
                let value = row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }

            let valueScore = displayNameValueScore(sampleValues: sampleValues)

            // Both header and value shape matter here.
            let combined = max(0.0, min(1.0, (0.70 * valueScore) + (0.30 * headerScore) + headerPenalty))
            scores[header] = combined
        }

        // Decision rule: pick exactly one winner above threshold.
        // If ambiguous, return nil and fall back to other presentation options.
        let threshold = 0.60
        let winners = scores
            .filter { $0.value >= threshold }
            .sorted { $0.value > $1.value }

        guard let best = winners.first else {
            return DisplayNameColumnDetection(selectedHeader: nil, confidenceByHeader: scores)
        }

        if winners.count >= 2 {
            let second = winners[1]
            if (best.value - second.value) < 0.12 {
                return DisplayNameColumnDetection(selectedHeader: nil, confidenceByHeader: scores)
            }
        }

        return DisplayNameColumnDetection(selectedHeader: best.key, confidenceByHeader: scores)
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

    private func headerSignalScore(tokens: [String]) -> Double {
        let set = Set(tokens)
        if set.contains("email") { return 1.0 }
        if set.contains("emailaddress") { return 1.0 }
        if set.contains("e") && set.contains("mail") { return 1.0 }
        return 0.0
    }

    private func headerNegativePenalty(tokens: [String]) -> Double {
        let set = Set(tokens)
        if set.contains("cc") || set.contains("bcc") || set.contains("reply") || set.contains("subject") {
            return -0.30
        }
        return 0.0
    }

    private func displayNameHeaderSignalScore(tokens: [String]) -> Double {
        let set = Set(tokens)
        // Strong positives.
        if set.contains("name") && (set.contains("student") || set.contains("parent") || set.contains("guardian")) {
            return 1.0
        }
        if set.contains("fullname") || (set.contains("full") && set.contains("name")) {
            return 0.95
        }
        if set.contains("name") {
            return 0.80
        }
        // Weak positives.
        if set.contains("first") || set.contains("firstname") {
            return 0.55
        }
        if set.contains("last") || set.contains("lastname") {
            return 0.45
        }
        return 0.0
    }

    private func displayNameHeaderNegativePenalty(tokens: [String]) -> Double {
        let set = Set(tokens)

        // Not person names.
        if set.contains("email") || set.contains("emailaddress") || (set.contains("e") && set.contains("mail")) {
            return -0.50
        }
        if set.contains("phone") || set.contains("phonenumber") || set.contains("tel") || set.contains("telephone") {
            return -0.40
        }
        if set.contains("date") || set.contains("time") {
            return -0.35
        }
        if set.contains("team") || set.contains("club") || set.contains("org") || set.contains("organization") || set.contains("school") {
            return -0.35
        }
        if set.contains("address") || set.contains("city") || set.contains("state") || set.contains("zip") || set.contains("postal") {
            return -0.35
        }
        if set.contains("id") {
            return -0.25
        }
        return 0.0
    }

    private func displayNameValueScore(sampleValues: [String]) -> Double {
        // If we have too little data, don't guess.
        guard sampleValues.count >= 3 else { return 0.0 }

        let scores = sampleValues.map { NameScoring.personNameScore($0) }
        let total = scores.reduce(0.0, +)
        return total / Double(scores.count)
    }

    private func emailValueScore(sampleValues: [String]) -> Double {
        // If we have too little data, don't guess.
        guard sampleValues.count >= 3 else { return 0.0 }

        let validCount = sampleValues.filter { looksLikeEmail($0) }.count
        return Double(validCount) / Double(sampleValues.count)
    }

    private func looksLikeEmail(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return false }
        if value.contains(" ") { return false }

        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        if parts.count != 2 { return false }
        let local = parts[0]
        let domain = parts[1]
        if local.isEmpty || domain.isEmpty { return false }

        // Basic dot check in domain (must be after @ and not last).
        if !domain.contains(".") { return false }
        if domain.hasSuffix(".") { return false }

        return true
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
