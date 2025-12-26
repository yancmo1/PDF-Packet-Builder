//
//  SendLog.swift
//  PDFPacketSender
//
//  Model for tracking sent PDFs
//

import Foundation

struct SendLog: Codable, Identifiable {
    let id: UUID
    var recipientName: String
    var recipientEmail: String
    var pdfName: String
    var timestamp: Date
    var status: String
    var notes: String?
    
    init(id: UUID = UUID(), recipientName: String, recipientEmail: String, pdfName: String, timestamp: Date = Date(), status: String = "Sent", notes: String? = nil) {
        self.id = id
        self.recipientName = recipientName
        self.recipientEmail = recipientEmail
        self.pdfName = pdfName
        self.timestamp = timestamp
        self.status = status
        self.notes = notes
    }
}
