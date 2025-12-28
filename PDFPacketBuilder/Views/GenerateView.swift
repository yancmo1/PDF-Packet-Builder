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
    @State private var showingMailComposer = false
    @State private var currentShareItem: ShareItem?
    @State private var currentMailItem: MailItem?
    @State private var showingPaywall = false
    @State private var showingMailUnavailableAlert = false
    
    private let pdfService = PDFService()
    
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
                                        Text("\(appState.recipients.count)")
                                            .fontWeight(.semibold)
                                    }
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            
                            if !appState.canGenerateWithRecipientCount(appState.recipients.count) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Free plan: 10 recipients max")
                                        .font(.caption)
                                    Spacer()
                                    Button("Upgrade") {
                                        showingPaywall = true
                                    }
                                    .font(.caption)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            Button(action: generatePDFs) {
                                Label("Generate PDFs", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(appState.canGenerateWithRecipientCount(appState.recipients.count) ? Color.blue : Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(isGenerating || !appState.canGenerateWithRecipientCount(appState.recipients.count))
                            
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
                ShareSheet(items: [item.url]) { completed in
                    if completed {
                        // Log the send only after successful share
                        logSend(recipientName: item.recipientName, templateName: item.templateName, fileName: item.fileName, method: .share)
                    }
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                if let mailItem = currentMailItem {
                    MailComposer(
                        subject: "\(mailItem.templateName) PDF",
                        recipient: mailItem.recipientEmail,
                        pdfData: mailItem.pdfData,
                        fileName: mailItem.fileName
                    ) { result in
                        if result == .sent {
                            // Log the send only after mail was sent
                            logSend(recipientName: mailItem.recipientName, templateName: mailItem.templateName, fileName: mailItem.fileName, method: .mail)
                        }
                        showingMailComposer = false
                        currentMailItem = nil
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PurchaseView()
            }
            .alert("Mail Not Available", isPresented: $showingMailUnavailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Mail is not configured on this device. Please set up Mail in Settings.")
            }
        }
    }
    
    private func generatePDFs() {
        guard let template = appState.pdfTemplate else { return }
        
        isGenerating = true
        generatedPDFs.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            var pdfs: [(Recipient, Data)] = []
            
            for recipient in appState.recipients {
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
        
        if let url = StorageService().savePDFToDocuments(data: item.pdfData, filename: fileName) {
            currentShareItem = ShareItem(
                url: url,
                recipientName: item.recipient.fullName,
                templateName: appState.pdfTemplate?.name ?? "document",
                fileName: fileName
            )
        }
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
        showingMailComposer = true
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
