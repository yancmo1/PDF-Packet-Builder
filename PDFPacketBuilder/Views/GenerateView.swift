//
//  GenerateView.swift
//  PDFPacketBuilder
//

import SwiftUI
import MessageUI

struct GenerateView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var iapManager: IAPManager
    @State private var isGenerating = false
    @State private var generatedPDFs: [(recipient: Recipient, pdfData: Data)] = []
    @State private var showingShareSheet = false
    @State private var currentShareItem: ShareItem?
    @State private var currentMailItem: MailItem?
    @State private var showingPaywall = false
    @State private var showingMailUnavailableAlert = false
    @State private var showingMailFailedAlert = false
    @State private var mailFailedMessage: String = ""
    @State private var showingRecipientLimitAlert = false
    @State private var showingNoRecipientsSelectedAlert = false
    @State private var showingShareErrorAlert = false

    @State private var selectedRecipientIDs: Set<UUID> = []
    
    private let pdfService = PDFService()

    private var selectedRecipients: [Recipient] {
        appState.recipients.filter { selectedRecipientIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if appState.pdfTemplate == nil {
                    EmptyStateView(
                        icon: "doc.badge.plus",
                        title: "No Template",
                        message: "Import a PDF template first"
                    )
                } else if appState.recipients.isEmpty {
                    EmptyStateView(
                        icon: "person.2.badge.plus",
                        title: "No Recipients",
                        message: "Add recipients to send PDFs"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            VStack(spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Template")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(appState.pdfTemplate?.name ?? "")
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                }
                                
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Recipients")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(selectedRecipientIDs.count) selected of \(appState.recipients.count)")
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)

                            // Recipient selection
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Choose Recipients")
                                        .font(.headline)
                                    Spacer()
                                    Button("All") {
                                        selectedRecipientIDs = Set(appState.recipients.map { $0.id })
                                    }
                                    .font(.subheadline)
                                    Button("None") {
                                        selectedRecipientIDs.removeAll()
                                    }
                                    .font(.subheadline)
                                }

                                ForEach(appState.recipients) { recipient in
                                    Button {
                                        if selectedRecipientIDs.contains(recipient.id) {
                                            selectedRecipientIDs.remove(recipient.id)
                                        } else {
                                            selectedRecipientIDs.insert(recipient.id)
                                        }
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(recipient.fullName)
                                                    .foregroundColor(.primary)
                                                Text(recipient.email)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: selectedRecipientIDs.contains(recipient.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedRecipientIDs.contains(recipient.id) ? .blue : .secondary)
                                        }
                                        .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)

                                    Divider()
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            
                            Button(action: attemptGenerate) {
                                Label("Generate PDFs", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(isGenerating)
                            
                            // Generated PDFs list
                            if !generatedPDFs.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Generated PDFs")
                                        .font(.headline)
                                    
                                    ForEach(generatedPDFs, id: \.recipient.id) { item in
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(item.recipient.fullName)
                                                    .fontWeight(.semibold)
                                                Text(item.recipient.email)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            
                                            // Mail button
                                            Button(action: {
                                                sendMail(item)
                                            }) {
                                                Label("Mail", systemImage: "envelope")
                                                    .font(.caption)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color.green)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(6)
                                            }
                                            
                                            // Share button
                                            Button(action: {
                                                sharePDF(item)
                                            }) {
                                                Label("Share", systemImage: "square.and.arrow.up")
                                                    .font(.caption)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color.blue)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(6)
                                            }
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Generate PDFs")
            .onAppear {
                // Default to all recipients selected.
                if selectedRecipientIDs.isEmpty {
                    selectedRecipientIDs = Set(appState.recipients.map { $0.id })
                }
            }
            .onChange(of: appState.recipients) { newRecipients in
                // Remove IDs that no longer exist, and auto-select new recipients.
                let newIDs = Set(newRecipients.map { $0.id })
                selectedRecipientIDs = selectedRecipientIDs.intersection(newIDs)
                selectedRecipientIDs.formUnion(newIDs)
            }
            .overlay {
                if isGenerating {
                    ProgressView("Generating PDFs...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .sheet(item: $currentShareItem) { item in
                ShareSheet(
                    items: [item.url],
                    excludedActivityTypes: [
                        .assignToContact,
                        .saveToCameraRoll,
                        .markupAsPDF,
                        .openInIBooks,
                        .addToReadingList,
                        .postToFacebook,
                        .postToTwitter,
                        .postToWeibo,
                        .postToTencentWeibo
                    ]
                ) { completed in
                    if completed {
                        // Log the send only after successful share
                        logSend(recipientName: item.recipientName, templateName: item.templateName, fileName: item.fileName, method: .share)
                    }
                }
            }
            .sheet(item: $currentMailItem) { mailItem in
                MailComposer(
                    subject: "\(mailItem.templateName) PDF",
                    recipient: mailItem.recipientEmail,
                    pdfData: mailItem.pdfData,
                    fileName: mailItem.fileName
                ) { result, error in
                    if result == .sent {
                        // Log the send only after mail was sent
                        logSend(recipientName: mailItem.recipientName, templateName: mailItem.templateName, fileName: mailItem.fileName, method: .mail)
                    } else if result == .failed || error != nil {
                        mailFailedMessage = error?.localizedDescription ?? "Mail could not be sent. Please try again."
                        showingMailFailedAlert = true
                    }

                    // Dismiss sheet and clear state
                    currentMailItem = nil
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PurchaseView()
            }
            .alert("Limit reached", isPresented: $showingRecipientLimitAlert) {
                Button("OK", role: .cancel) { }
                Button("Unlock Pro") {
                    showingPaywall = true
                }
            } message: {
                Text("Free version supports 10 recipients per batch. Unlock Pro to remove limits.")
            }
            .alert("No recipients selected", isPresented: $showingNoRecipientsSelectedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Select at least one recipient to generate PDFs.")
            }
            .alert("Mail Not Available", isPresented: $showingMailUnavailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Mail is not configured on this device. Please set up Mail in Settings.")
            }
            .alert("Mail Failed", isPresented: $showingMailFailedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(mailFailedMessage)
            }
            .alert("Unable to share", isPresented: $showingShareErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("We could not prepare the PDF for sharing. Please try again.")
            }
        }
    }

    private func attemptGenerate() {
        if selectedRecipientIDs.isEmpty {
            showingNoRecipientsSelectedAlert = true
            return
        }

        if !iapManager.isProUnlocked && selectedRecipientIDs.count > AppState.freeMaxRecipients {
            showingRecipientLimitAlert = true
            return
        }

        generatePDFs()
    }
    
    private func generatePDFs() {
        guard let template = appState.pdfTemplate else { return }

        // Snapshot inputs on the main thread to avoid races while generating.
        let recipientsToGenerate = selectedRecipients
        
        isGenerating = true
        generatedPDFs.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            var pdfs: [(Recipient, Data)] = []
            
            for recipient in recipientsToGenerate {
                if let pdfData = pdfService.generatePersonalizedPDF(template: template, recipient: recipient) {
                    pdfs.append((recipient, pdfData))
                }
            }
            
            DispatchQueue.main.async {
                self.generatedPDFs = pdfs
                self.isGenerating = false
            }
        }
    }
    
    private func sharePDF(_ item: (recipient: Recipient, pdfData: Data)) {
        let fileName = "\(appState.pdfTemplate?.name ?? "document")_\(item.recipient.fullName).pdf"
        
        guard let url = StorageService().savePDFToDocuments(data: item.pdfData, filename: fileName) else {
            showingShareErrorAlert = true
            return
        }

        currentShareItem = ShareItem(
            url: url,
            recipientName: item.recipient.fullName,
            templateName: appState.pdfTemplate?.name ?? "document",
            fileName: fileName
        )
    }
    
    private func sendMail(_ item: (recipient: Recipient, pdfData: Data)) {
        guard MFMailComposeViewController.isAvailable else {
            showingMailUnavailableAlert = true
            return
        }
        
        let fileName = "\(appState.pdfTemplate?.name ?? "document")_\(item.recipient.fullName).pdf"
        
        currentMailItem = MailItem(
            recipientName: item.recipient.fullName,
            recipientEmail: item.recipient.email,
            templateName: appState.pdfTemplate?.name ?? "document",
            fileName: fileName,
            pdfData: item.pdfData
        )
    }
    
    private func logSend(recipientName: String, templateName: String, fileName: String, method: SendLog.SendMethod) {
        let log = SendLog(
            recipientName: recipientName,
            templateName: templateName,
            outputFileName: fileName,
            sentDate: Date(),
            method: method
        )
        appState.addSendLog(log)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(.gray)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(message)
                .foregroundColor(.secondary)
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
    let recipientName: String
    let templateName: String
    let fileName: String
}

struct MailItem: Identifiable {
    let id = UUID()
    let recipientName: String
    let recipientEmail: String
    let templateName: String
    let fileName: String
    let pdfData: Data
}

struct GenerateView_Previews: PreviewProvider {
    static var previews: some View {
        GenerateView()
            .environmentObject(AppState())
    }
}
