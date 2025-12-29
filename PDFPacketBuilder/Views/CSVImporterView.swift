//
//  CSVImporterView.swift
//  PDFPacketSender
//
//  View for importing recipients from CSV
//

import SwiftUI
import UniformTypeIdentifiers

struct CSVImporterView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var showingDocumentPicker = false
    @State private var importedRecipients: [Recipient] = []
    @State private var isProcessing = false
    @State private var showingImportError = false
    @State private var importErrorMessage: String?
    @State private var showingNoEmailDetectedAlert = false
    
    private let csvService = CSVService()
    private let storageService = StorageService()
    
    var body: some View {
        NavigationView {
            VStack {
                if importedRecipients.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Import CSV File")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Select a CSV file with recipient data")
                            .foregroundColor(.secondary)
                        
                        Text("Recommended columns: Email\nOptional: FirstName, LastName, Phone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showingDocumentPicker = true
                        }) {
                            Label("Select CSV File", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding()
                    }
                    .padding()
                } else {
                    VStack {
                        Text("Found \(importedRecipients.count) recipients")
                            .font(.headline)
                            .padding()
                        
                        List(importedRecipients) { recipient in
                            VStack(alignment: .leading) {
                                Text(displayName(for: recipient))
                                    .fontWeight(.semibold)
                                Text(displayEmail(for: recipient))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        importRecipients()
                    }
                    .disabled(importedRecipients.isEmpty)
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(
                    contentTypes: [.commaSeparatedText, .plainText],
                    onSelected: handleCSVImport,
                    onFailure: handlePickerFailure
                )
            }
            .overlay {
                if isProcessing {
                    ProgressView("Processing CSV...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .alert("Import failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) {
                    importErrorMessage = nil
                }
            } message: {
                Text(importErrorMessage ?? "Unable to import the file.")
            }
            .alert("No email column detected", isPresented: $showingNoEmailDetectedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("No email column detected. You need to manually select email recipients.")
            }
        }
    }
    
    private func handleCSVImport(url: URL) {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let reference = try storageService.importCSVToDocuments(from: url)
                let csvText = try String(contentsOf: reference.url, encoding: .utf8)

                let recipients = csvService.parseCSV(data: csvText)
                let preview = csvService.parsePreview(data: csvText, maxRows: 25)
                let snapshot = CSVImportSnapshot(
                    reference: reference,
                    headers: preview.headers,
                    normalizedHeaders: preview.headers.map { NormalizedName.from($0) }
                )
                
                DispatchQueue.main.async {
                    self.importedRecipients = recipients
                    appState.saveCSVImport(snapshot)

                    // Also load recipients immediately so Generate can use them without extra steps.
                    // Keep manual/contacts recipients, replace any prior CSV recipients.
                    let preserved = appState.recipients.filter { $0.source != .csv }
                    appState.saveRecipients(preserved + recipients)

                    // Default the email-column picker when possible.
                    let emailDetection = csvService.detectEmailColumn(preview: preview)
                    if let detected = emailDetection.selectedHeader {
                        appState.saveSelectedEmailColumn(detected)
                    } else {
                        appState.saveSelectedEmailColumn(nil)
                        showingNoEmailDetectedAlert = true
                    }

                    // Presentation-only: default a display-name column when possible.
                    let displayNameDetection = csvService.detectDisplayNameColumn(preview: preview)
                    if let detected = displayNameDetection.selectedHeader {
                        appState.saveSelectedDisplayNameColumn(detected)
                    } else {
                        appState.saveSelectedDisplayNameColumn(nil)
                    }

                    self.isProcessing = false
                }
            } catch {
                print("Error reading CSV: \(error)")
                DispatchQueue.main.async {
                    importErrorMessage = "Could not read the selected CSV. Please try again or pick a different file."
                    showingImportError = true
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func importRecipients() {
        // Recipients are already loaded on select; keep this as a no-op except dismiss.
        dismiss()
    }

    private func displayName(for recipient: Recipient) -> String {
        let fromColumn: String = {
            let column = appState.selectedDisplayNameColumn?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if column.isEmpty { return "" }
            return recipient.value(forKey: column)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }()

        if !fromColumn.isEmpty { return fromColumn }

        let fullName = recipient.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fullName.isEmpty { return fullName }

        let email = displayEmail(for: recipient)
        if !email.isEmpty { return email }
        return "Recipient"
    }

    private func displayEmail(for recipient: Recipient) -> String {
        let email = recipient.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.isEmpty { return email }

        let column = appState.selectedEmailColumn?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if column.isEmpty { return "" }
        return recipient.value(forKey: column)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func handlePickerFailure(_ error: Error) {
        importErrorMessage = "Access to the selected file was denied. Please choose a file stored locally (On My iPhone) or grant permission in the file provider."
        showingImportError = true
    }
}
