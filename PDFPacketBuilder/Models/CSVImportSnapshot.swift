//
//  CSVImportSnapshot.swift
//  PDFPacketBuilder
//

import Foundation

struct CSVFileReference: Codable, Hashable {
    var originalFileName: String
    var localPath: String
    var importedAt: Date

    var url: URL {
        URL(fileURLWithPath: localPath)
    }
}

struct CSVImportSnapshot: Codable, Hashable {
    var reference: CSVFileReference
    var headers: [String]
}
