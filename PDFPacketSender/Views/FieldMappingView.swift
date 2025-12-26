//
//  FieldMappingView.swift
//  PDFPacketSender
//
//  View for mapping PDF fields to recipient properties
//

import SwiftUI

struct FieldMappingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var template: PDFTemplate
    @State private var fieldMappings: [String: String]
    
    // Available recipient properties for mapping
    private let availableProperties = [
        "FirstName",
        "LastName",
        "FullName",
        "Email",
        "PhoneNumber"
    ]
    
    init(template: PDFTemplate) {
        self.template = template
        _fieldMappings = State(initialValue: template.fieldMappings)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Map PDF fields to recipient data")) {
                    ForEach(template.fields) { field in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(field.name)
                                .fontWeight(.semibold)
                            
                            Picker("Map to", selection: Binding(
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
                                ForEach(availableProperties, id: \.self) { property in
                                    Text(property).tag(property)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Field Mapping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMapping()
                    }
                }
            }
        }
    }
    
    private func saveMapping() {
        var updatedTemplate = template
        updatedTemplate.fieldMappings = fieldMappings
        appState.saveTemplate(updatedTemplate)
        dismiss()
    }
}
