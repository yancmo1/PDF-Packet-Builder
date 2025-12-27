//
//  GenerateView.swift
//  PDFPacketBuilder
//

import SwiftUI

struct GenerateView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var iapManager: IAPManager
    @State private var isGenerating = false
    @State private var generatedPDFs: [(recipient: Recipient, pdfData: Data)] = []
    @State private var showingShareSheet = false
    @State private var currentShareItem: ShareItem?
    @State private var showingPaywall = false
    
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
                                            Button(action: {
                                                sharePDF(item)
                                            }) {
                                                Image(systemName: "square.and.arrow.up")
                                                    .foregroundColor(.blue)
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
                ShareSheet(items: [item.url])
            }
            .sheet(isPresented: $showingPaywall) {
                PurchaseView()
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
            currentShareItem = ShareItem(url: url)
            
            // Log the send
            let log = SendLog(
                recipientName: item.recipient.fullName,
                recipientEmail: item.recipient.email,
                pdfName: fileName,
                status: "Shared"
            )
            appState.addSendLog(log)
        }
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
}

struct GenerateView_Previews: PreviewProvider {
    static var previews: some View {
        GenerateView()
            .environmentObject(AppState())
    }
}
