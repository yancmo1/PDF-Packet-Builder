//
//  TemplateView.swift
//  PDFPacketBuilder
//

import SwiftUI
import UniformTypeIdentifiers

struct TemplateView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingDocumentPicker = false
    @State private var isProcessing = false
    
    private let pdfService = PDFService()
    
    var body: some View {
        NavigationView {
            VStack {
                if let template = appState.pdfTemplate {
                    ScrollView {
                        VStack(spacing: 20) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
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
                            }
                            
                            Button(action: {
                                showingDocumentPicker = true
                            }) {
                                Label("Replace Template", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
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
                DocumentPicker(onPDFSelected: handlePDFImport)
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
        }
    }
    
    private func handlePDFImport(url: URL) {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                let fields = pdfService.extractFields(from: data)
                let fileName = url.deletingPathExtension().lastPathComponent
                
                let template = PDFTemplate(
                    name: fileName,
                    pdfData: data,
                    fields: fields
                )
                
                DispatchQueue.main.async {
                    appState.saveTemplate(template)
                    isProcessing = false
                }
            } catch {
                print("Error importing PDF: \(error)")
                DispatchQueue.main.async {
                    isProcessing = false
                }
            }
        }
    }
}

struct TemplateView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateView()
            .environmentObject(AppState())
    }
}
