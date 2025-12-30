//
//  ExportService.swift
//  PDFPacketBuilder
//
//  Pro feature: batch export a folder bundle containing PDFs and optional message text.
//

import Foundation

struct ExportService {
    struct GeneratedItem {
        var recipient: Recipient
        var pdfData: Data
    }

    enum ExportError: Error {
        case invalidDestination
        case unableToCreateDirectory
        case unableToWriteFile
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Exports a bundle folder under `parentFolderURL`.
    ///
    /// Structure:
    /// - <BundleName>/
    ///   - Summary.csv
    ///   - <Recipient Folder>/
    ///       - Packet.pdf
    ///       - Message.txt (optional)
    func exportBundle(
        items: [GeneratedItem],
        templateName: String,
        parentFolderURL: URL,
        messageProvider: ((Recipient, String) -> String?)? = nil
    ) throws -> URL {
        guard parentFolderURL.isFileURL else { throw ExportError.invalidDestination }

        let didStartSecurity = parentFolderURL.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurity {
                parentFolderURL.stopAccessingSecurityScopedResource()
            }
        }

        let bundleFolderName = "Export-\(safeFileComponent(templateName))-\(timestampComponent())"
        let bundleURL = parentFolderURL.appendingPathComponent(bundleFolderName, isDirectory: true)

        do {
            try createDirectoryIfNeeded(bundleURL)
        } catch {
            throw ExportError.unableToCreateDirectory
        }

        var summaryRows: [String] = []
        summaryRows.append("Recipient Name,Email,Folder,PDF File,Message File")

        for item in items {
            let recipientFolderName = safeRecipientFolderName(item.recipient)
            let recipientFolderURL = bundleURL.appendingPathComponent(recipientFolderName, isDirectory: true)
            try createDirectoryIfNeeded(recipientFolderURL)

            let pdfURL = recipientFolderURL.appendingPathComponent("Packet.pdf")
            do {
                try item.pdfData.write(to: pdfURL, options: [.atomic])
            } catch {
                throw ExportError.unableToWriteFile
            }

            var messageFileName: String? = nil
            if let messageProvider {
                let outputFileName = "Packet.pdf"
                if let messageText = messageProvider(item.recipient, outputFileName), !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let messageURL = recipientFolderURL.appendingPathComponent("Message.txt")
                    do {
                        try messageText.write(to: messageURL, atomically: true, encoding: .utf8)
                        messageFileName = "Message.txt"
                    } catch {
                        throw ExportError.unableToWriteFile
                    }
                }
            }

            let recipientName = escapeCSV(displayName(item.recipient))
            let email = escapeCSV(item.recipient.email)
            let folder = escapeCSV(recipientFolderName)
            let pdf = escapeCSV("Packet.pdf")
            let message = escapeCSV(messageFileName ?? "")
            summaryRows.append("\(recipientName),\(email),\(folder),\(pdf),\(message)")
        }

        let summaryURL = bundleURL.appendingPathComponent("Summary.csv")
        do {
            try summaryRows.joined(separator: "\n").write(to: summaryURL, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.unableToWriteFile
        }

        return bundleURL
    }

    private func createDirectoryIfNeeded(_ url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            return
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func timestampComponent() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func safeRecipientFolderName(_ recipient: Recipient) -> String {
        let base = displayName(recipient)
        let name = safeFileComponent(base)
        let shortID = recipient.id.uuidString.prefix(8)
        return name.isEmpty ? "Recipient-\(shortID)" : "\(name)-\(shortID)"
    }

    private func displayName(_ recipient: Recipient) -> String {
        let full = recipient.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !full.isEmpty { return full }
        let email = recipient.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.isEmpty { return email }
        return "Recipient"
    }

    private func safeFileComponent(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let mapped = String(trimmed.unicodeScalars.map { scalar -> Character in
            if allowed.contains(scalar) {
                return Character(scalar)
            }
            return "_"
        })

        let collapsed = mapped
            .replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " _"))

        if collapsed.count > 60 {
            return String(collapsed.prefix(60))
        }
        return collapsed
    }

    private func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
