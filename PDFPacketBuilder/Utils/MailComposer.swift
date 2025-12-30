//
//  MailComposer.swift
//  PDFPacketBuilder
//
//  UIKit wrapper for mail composer
//

import SwiftUI
import MessageUI

struct MailComposer: UIViewControllerRepresentable {
    static let mailSimulatorDefaultsKey = "debug_useMailSimulator"

    let subject: String
    let body: String
    let recipient: String
    let pdfData: Data
    let fileName: String
    let onComplete: (MFMailComposeResult, Error?) -> Void

    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIViewController {
#if DEBUG
        if shouldUseMailSimulator {
            let simulated = SimulatedMailComposerView(
                subject: subject,
                messageBody: body,
                recipient: recipient,
                fileName: fileName,
                attachmentBytes: pdfData.count,
                onComplete: onComplete
            )
            return UIHostingController(rootView: simulated)
        }
#endif

        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)

        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBody.isEmpty {
            composer.setMessageBody(body, isHTML: false)
        }

        if !recipient.isEmpty {
            composer.setToRecipients([recipient])
        }

        composer.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: fileName)

        return composer
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
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

    private var shouldUseMailSimulator: Bool {
#if DEBUG
        if MFMailComposeViewController.canSendMail() {
            return false
        }
        return UserDefaults.standard.bool(forKey: Self.mailSimulatorDefaultsKey)
#else
        return false
#endif
    }
}

#if DEBUG
private struct SimulatedMailComposerView: View {
    let subject: String
    let messageBody: String
    let recipient: String
    let fileName: String
    let attachmentBytes: Int
    let onComplete: (MFMailComposeResult, Error?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Message")) {
                    LabeledContent("To", value: recipient.isEmpty ? "(none)" : recipient)
                    LabeledContent("Subject", value: subject.isEmpty ? "(none)" : subject)
                }

                Section(header: Text("Body")) {
                    Text(messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(empty)" : messageBody)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                Section(header: Text("Attachment")) {
                    LabeledContent("File", value: fileName)
                    LabeledContent("Size", value: formattedBytes(attachmentBytes))
                }

                Section {
                    Button("Send") {
                        onComplete(.sent, nil)
                        dismiss()
                    }

                    Button("Save Draft") {
                        onComplete(.saved, nil)
                        dismiss()
                    }

                    Button("Fail") {
                        onComplete(.failed, MailSimulatorError())
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Mail Simulator")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete(.cancelled, nil)
                        dismiss()
                    }
                }
            }
        }
    }

    private func formattedBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(max(0, bytes)))
    }
}

private struct MailSimulatorError: LocalizedError {
    var errorDescription: String? {
        "Simulated mail failure."
    }
}
#endif

// Helper to check if mail is available
extension MFMailComposeViewController {
    static var isAvailable: Bool {
        if canSendMail() {
            return true
        }

#if DEBUG
        return UserDefaults.standard.bool(forKey: MailComposer.mailSimulatorDefaultsKey)
#else
        return false
#endif
    }
}
