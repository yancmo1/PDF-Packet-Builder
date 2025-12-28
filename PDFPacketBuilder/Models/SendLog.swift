//
//  SendLog.swift
//  PDFPacketBuilder
//
//  Model for tracking sent PDFs
//

import Foundation

struct SendLog: Codable, Identifiable {
    let id: UUID
    var recipientName: String
    var templateName: String
    var outputFileName: String
    var sentDate: Date
    var method: SendMethod
    
    enum SendMethod: String, Codable {
        case share = "Share"
        case mail = "Mail"
    }
    
    init(id: UUID = UUID(), recipientName: String, templateName: String, outputFileName: String, sentDate: Date = Date(), method: SendMethod) {
        self.id = id
        self.recipientName = recipientName
        self.templateName = templateName
        self.outputFileName = outputFileName
        self.sentDate = sentDate
        self.method = method
    }
    
    // Helper to format sentDate as MM-DD-YY
    var formattedSentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yy"
        return formatter.string(from: sentDate)
    }
}
