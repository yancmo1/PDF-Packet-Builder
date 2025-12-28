//
//  TemplateView.swift
//  PDFPacketBuilder
//

import SwiftUI
import UniformTypeIdentifiers

struct TemplateView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var iapManager: IAPManager
    @State private var showingDocumentPicker = false
    @State private var isProcessing = false
    @State private var showingPaywall = false
    @State private var showingReplaceConfirmation = false
    @State private var showingRemoveConfirmation = false
    @State private var showingImportError = false
    @State private var importErrorMessage: String?
    @State private var pendingPDFUrl: URL?
    
    private let pdfService = PDFService()
    
    var body: some View {
        NavigationView {
            VStack {
                if let template = appState.pdfTemplate {
                    ScrollView {
                        VStack(spacing: 20) {
                            // PDF Preview
                            PDFPreviewView(pdfData: template.pdfData)
                                .frame(height: 300)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                            
                            Text(template.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("\(template.fields.count) fields")
                                .foregroundColor(.secondary)
                            
                            Divider()
                                .padding(.vertical)
                            
                            if !template.fields.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Fields in PDF:")
                                        .font(.headline)
                                    
                                    ForEach(template.fields) { field in
                                        HStack {
                                            Image(systemName: "textformat")
                                                .foregroundColor(.blue)
                                            Text(field.name)
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)
                                    
                                    Text("This version supports fillable PDFs (AcroForm).")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                                // Free users can replace (with confirmation), Pro can add more
                                showingDocumentPicker = true
                            }) {
                                Label("Replace Template", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                showingRemoveConfirmation = true
                            }) {
                                Label("Remove Template", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        Text("No Template")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Import a fillable PDF to get started")
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showingDocumentPicker = true
                        }) {
                            Label("Import PDF", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Template")
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(
                    onPDFSelected: handlePDFImport,
                    onFailure: handlePickerFailure
                )
            }
            .sheet(isPresented: $showingPaywall) {
                PurchaseView()
            }
            .overlay {
                if isProcessing {
                    ProgressView("Processing...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .alert("Replace template?", isPresented: $showingReplaceConfirmation) {
                Button("Cancel", role: .cancel) {
                    pendingPDFUrl = nil
                }
                Button("Replace", role: .destructive) {
                    if let url = pendingPDFUrl {
                        processPDFImport(url: url, isReplacement: true)
                    }
                }
            } message: {
                Text("Replacing will reset mapping and history for the free version.")
            }
            .alert("Remove template?", isPresented: $showingRemoveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    appState.removeTemplate()
                }
            } message: {
                Text("This will remove the template and clear mapping and history.")
            }
            .alert("Import failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) {
                    importErrorMessage = nil
                }
            } message: {
                Text(importErrorMessage ?? "Unable to import the PDF.")
            }
        }
    }
    
    private func handlePDFImport(url: URL) {
        // Check if this is a replacement (template exists and user is not pro)
        if appState.pdfTemplate != nil && !iapManager.isProUnlocked {
            pendingPDFUrl = url
            showingReplaceConfirmation = true
        } else if appState.pdfTemplate != nil && iapManager.isProUnlocked {
            // Pro users can add more templates, just process it
            processPDFImport(url: url, isReplacement: false)
        } else {
            // No template exists, just import it
            processPDFImport(url: url, isReplacement: false)
        }
    }
    
    private func processPDFImport(url: URL, isReplacement: Bool) {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                let fields = pdfService.extractFields(from: data)
                let fileName = url.deletingPathExtension().lastPathComponent
                
                // Save a copy to Documents directory
                let storageService = StorageService()
                let savedFileName = "\(fileName).pdf"
                if storageService.savePDFToDocuments(data: data, filename: savedFileName) == nil {
                    print("Warning: Failed to save PDF to Documents directory")
                }
                
                let template = PDFTemplate(
                    name: fileName,
                    pdfData: data,
                    fields: fields
                )
                
                DispatchQueue.main.async {
                    if isReplacement {
                        appState.replaceTemplate(template)
                    } else {
                        appState.saveTemplate(template)
                    }
                    isProcessing = false
                    pendingPDFUrl = nil
                }
            } catch {
                print("Error importing PDF: \(error)")
                DispatchQueue.main.async {
                    importErrorMessage = "Could not read the selected PDF. Please try again or pick a different file."
                    showingImportError = true
                    isProcessing = false
                    pendingPDFUrl = nil
                }
            }
        }
    }

    private func handlePickerFailure(_ error: Error) {
        importErrorMessage = "Access to the selected file was denied. Please choose a file stored locally or grant permission."
        showingImportError = true
    }
}

struct TemplateView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateView()
            .environmentObject(AppState())
            .environmentObject(IAPManager())
    }
}
