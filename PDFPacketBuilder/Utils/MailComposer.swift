//
//  MailComposer.swift
//  PDFPacketBuilder
//
//  UIKit wrapper for mail composer
//

import SwiftUI
import MessageUI

struct MailComposer: UIViewControllerRepresentable {
    let subject: String
    let recipient: String?
    let pdfData: Data
    let fileName: String
    let onComplete: (MFMailComposeResult, Error?) -> Void

    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        
        if let recipient = recipient, !recipient.isEmpty {
            composer.setToRecipients([recipient])
        }
        
        composer.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: fileName)
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposer
        
        init(_ parent: MailComposer) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.onComplete(result, error)
            parent.dismiss()
        }
    }
}

// Helper to check if mail is available
extension MFMailComposeViewController {
    static var isAvailable: Bool {
        canSendMail()
    }
}
