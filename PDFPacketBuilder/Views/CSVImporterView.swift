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
    
    private let csvService = CSVService()
    
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
                        
                        Text("Required columns: Email\nOptional: FirstName, LastName, Phone")
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
                                Text(recipient.fullName)
                                    .fontWeight(.semibold)
                                Text(recipient.email)
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
        }
    }
    
    private func handleCSVImport(url: URL) {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let csvText = try String(contentsOf: url, encoding: .utf8)
                let recipients = csvService.parseCSV(data: csvText)
                
                DispatchQueue.main.async {
                    self.importedRecipients = recipients
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
        var allRecipients = appState.recipients
        allRecipients.append(contentsOf: importedRecipients)
        appState.saveRecipients(allRecipients)
        dismiss()
    }

    private func handlePickerFailure(_ error: Error) {
        importErrorMessage = "Access to the selected file was denied. Please choose a file stored locally (On My iPhone) or grant permission in the file provider."
        showingImportError = true
    }
}
