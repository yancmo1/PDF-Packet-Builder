//
//  SampleAssets.swift
//  PDFPacketBuilder
//
//  Loads bundled sample assets for first-run experience.
//

import Foundation

enum SampleAssets {

    /// Loads the bundled sample PDF template data.
    static func loadSamplePDF() -> Data? {
        guard let url = Bundle.main.url(forResource: "SampleTemplate", withExtension: "pdf") else {
            print("SampleAssets: SampleTemplate.pdf not found in bundle")
            return nil
        }
        return try? Data(contentsOf: url)
    }

    /// Loads the bundled sample CSV and parses it into recipients.
    static func loadSampleRecipients() -> [Recipient] {
        guard let url = Bundle.main.url(forResource: "SampleRecipients", withExtension: "csv"),
              let csvString = try? String(contentsOf: url, encoding: .utf8) else {
            print("SampleAssets: SampleRecipients.csv not found in bundle")
            return []
        }

        let csvService = CSVService()
        return csvService.parseCSV(data: csvString)
    }

    /// Name to display for the sample template.
    static let sampleTemplateName = "Sports Permission Slip"
}
