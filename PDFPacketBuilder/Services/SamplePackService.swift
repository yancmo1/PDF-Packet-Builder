//
//  SamplePackService.swift
//  PDFPacketBuilder
//
//  Loads bundled sample assets into the user's workspace (template + recipients).
//

import Foundation

struct SamplePackService {
    enum SamplePackError: Error {
        case missingResource(String)
        case unableToReadResource(String)
    }

    private let storage: StorageService
    private let csvService: CSVService
    private let pdfService: PDFService

    init(
        storage: StorageService = StorageService(),
        csvService: CSVService = CSVService(),
        pdfService: PDFService = PDFService()
    ) {
        self.storage = storage
        self.csvService = csvService
        self.pdfService = pdfService
    }

    /// Loads the sample PDF template and sample recipients into AppState.
    /// - Important: Callers should clear/confirm before invoking if user data already exists.
    func loadSamplePack(into appState: AppState) throws {
        // 1) Template PDF
        guard let pdfURL = Bundle.main.url(forResource: "SampleTemplate", withExtension: "pdf") else {
            throw SamplePackError.missingResource("SampleTemplate.pdf")
        }

        let pdfData: Data
        do {
            pdfData = try Data(contentsOf: pdfURL)
        } catch {
            throw SamplePackError.unableToReadResource("SampleTemplate.pdf")
        }

        let fields = pdfService.extractFields(from: pdfData)
        let templateID = UUID()
        let relativePath = storage.saveTemplatePDFData(pdfData, templateID: templateID)

        let template = PDFTemplate(
            id: templateID,
            name: "SampleTemplate",
            pdfFilePath: relativePath,
            pdfData: pdfData,
            fields: fields,
            fieldMappings: [:],
            messageTemplate: nil,
            createdAt: Date()
        )

        appState.saveTemplate(template)

        // 2) Sample recipients CSV
        guard let csvURL = Bundle.main.url(forResource: "SampleRecipients", withExtension: "csv") else {
            throw SamplePackError.missingResource("SampleRecipients.csv")
        }

        let csvString: String
        do {
            csvString = try String(contentsOf: csvURL, encoding: .utf8)
        } catch {
            throw SamplePackError.unableToReadResource("SampleRecipients.csv")
        }

        let recipients = csvService.parseCSV(data: csvString)

        // Store a copy in Documents/Imports so mapping + preview have a stable local reference.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SampleRecipients.csv")
        try csvString.write(to: tempURL, atomically: true, encoding: .utf8)

        let fileRef = try storage.importCSVToDocuments(from: tempURL)
        let preview = csvService.parsePreview(data: csvString)
        let normalizedHeaders = preview.headers.map { NormalizedName.from($0) }

        let snapshot = CSVImportSnapshot(
            reference: fileRef,
            headers: preview.headers,
            normalizedHeaders: normalizedHeaders
        )

        // Append sample recipients; do not overwrite existing recipients.
        var merged = appState.recipients
        merged.append(contentsOf: recipients)
        appState.saveRecipients(merged)

        // Enable mapping/preview flow by saving snapshot.
        appState.saveCSVImport(snapshot)

        // Pick sensible defaults for the sample.
        // These are safe for a fresh start; callers who don't clear should avoid overwriting user choices.
        appState.saveCSVEmailColumn("Email")
        appState.saveCSVDisplayNameColumn("Full Name")
    }
}
