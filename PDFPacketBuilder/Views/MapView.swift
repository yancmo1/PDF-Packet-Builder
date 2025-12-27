//
//  MapView.swift
//  PDFPacketBuilder
//

import SwiftUI

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @State private var fieldMappings: [String: String] = [:]
    
    var body: some View {
        NavigationView {
            Group {
                if let template = appState.pdfTemplate {
                    Form {
                        Section(header: Text("Map PDF fields to CSV columns")) {
                            if template.fields.isEmpty {
                                Text("No fields found in PDF")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(template.fields) { field in
                                    HStack {
                                        Text(field.name)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                        
                                        Picker("", selection: Binding(
                                            get: { fieldMappings[field.name] ?? "" },
                                            set: { newValue in
                                                if newValue.isEmpty {
                                                    fieldMappings.removeValue(forKey: field.name)
                                                } else {
                                                    fieldMappings[field.name] = newValue
                                                }
                                            }
                                        )) {
                                            Text("Not Mapped").tag("")
                                            Text("FirstName").tag("FirstName")
                                            Text("LastName").tag("LastName")
                                            Text("Email").tag("Email")
                                            Text("PhoneNumber").tag("PhoneNumber")
                                        }
                                        .pickerStyle(.menu)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Map Fields")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                saveMapping()
                            }
                            .disabled(template.fields.isEmpty)
                        }
                    }
                    .onAppear {
                        fieldMappings = template.fieldMappings
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Template")
                            .font(.title2)
                        Text("Import a PDF template first")
                            .foregroundColor(.secondary)
                    }
                    .navigationTitle("Map Fields")
                }
            }
        }
    }
    
    private func saveMapping() {
        guard var template = appState.pdfTemplate else { return }
        template.fieldMappings = fieldMappings
        appState.saveTemplate(template)
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
            .environmentObject(AppState())
    }
}
