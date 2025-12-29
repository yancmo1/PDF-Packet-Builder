//
//  MapView.swift
//  PDFPacketBuilder
//

import SwiftUI

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @State private var fieldMappings: [String: String] = [:]
    @State private var showingCSVImport = false

    private let builtInOptions: [MappingOption] = [
        MappingOption(value: "FirstName", label: "First Name", normalized: .from("first name"), kind: .builtIn),
        MappingOption(value: "LastName", label: "Last Name", normalized: .from("last name"), kind: .builtIn),
        MappingOption(value: "FullName", label: "Full Name", normalized: .from("full name"), kind: .builtIn),
        MappingOption(value: "Email", label: "Email", normalized: .from("email"), kind: .builtIn),
        MappingOption(value: "PhoneNumber", label: "Phone Number", normalized: .from("phone number"), kind: .builtIn)
    ]

    private let computedOptions: [MappingOption] = [
        MappingOption(value: ComputedMappingValue.initials.rawValue, label: "Initials", normalized: .from("initials"), kind: .computed),
        MappingOption(value: ComputedMappingValue.today.rawValue, label: "Today (MM-DD-YY)", normalized: .from("today date"), kind: .computed),
        MappingOption(value: ComputedMappingValue.blank.rawValue, label: "Blank", normalized: .from("blank"), kind: .computed)
    ]
    
    var body: some View {
        NavigationView {
            Group {
                if let template = appState.pdfTemplate {
                    Form {
                        Section(header: Text("CSV")) {
                            if let csvImport = appState.csvImport {
                                HStack {
                                    Text("Selected")
                                    Spacer()
                                    Text(csvImport.reference.originalFileName)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                HStack {
                                    Text("Columns")
                                    Spacer()
                                    Text("\(csvImport.headers.count)")
                                        .foregroundColor(.secondary)
                                }

                                Picker("Name column", selection: Binding(
                                    get: { appState.selectedDisplayNameColumn ?? "" },
                                    set: { newValue in
                                        let value = newValue.isEmpty ? nil : newValue
                                        appState.saveSelectedDisplayNameColumn(value)
                                    }
                                )) {
                                    Text("Use Recipient Name").tag("")
                                    let headers = csvImport.headers
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                        .filter { !$0.isEmpty }
                                    let uniqueHeaders = Array(Set(headers)).sorted()
                                    ForEach(uniqueHeaders, id: \.self) { header in
                                        Text(header).tag(header)
                                    }
                                }
                                .pickerStyle(.menu)

                                Picker("Email column", selection: Binding(
                                    get: { appState.selectedEmailColumn ?? "" },
                                    set: { newValue in
                                        let value = newValue.isEmpty ? nil : newValue
                                        appState.saveSelectedEmailColumn(value)
                                    }
                                )) {
                                    Text("Use Recipient Email").tag("")
                                    let headers = csvImport.headers
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                        .filter { !$0.isEmpty }
                                    let uniqueHeaders = Array(Set(headers)).sorted()
                                    ForEach(uniqueHeaders, id: \.self) { header in
                                        Text(header).tag(header)
                                    }
                                }
                                .pickerStyle(.menu)

                                Button("Preview Data") {
                                    showingCSVImport = true
                                }
                            } else {
                                Text("No CSV selected")
                                    .foregroundColor(.secondary)
                                Button("Import CSV") {
                                    showingCSVImport = true
                                }

                                Picker("Name column", selection: Binding(
                                    get: { appState.selectedDisplayNameColumn ?? "" },
                                    set: { newValue in
                                        let value = newValue.isEmpty ? nil : newValue
                                        appState.saveSelectedDisplayNameColumn(value)
                                    }
                                )) {
                                    Text("Use Recipient Name").tag("")
                                }
                                .pickerStyle(.menu)
                                .disabled(true)

                                Picker("Email column", selection: Binding(
                                    get: { appState.selectedEmailColumn ?? "" },
                                    set: { newValue in
                                        let value = newValue.isEmpty ? nil : newValue
                                        appState.saveSelectedEmailColumn(value)
                                    }
                                )) {
                                    Text("Use Recipient Email").tag("")
                                }
                                .pickerStyle(.menu)
                                .disabled(true)

                                Button("Preview Data") {
                                    showingCSVImport = true
                                }
                                .disabled(true)
                            }
                        }

                        Section(header: mappingHeader(template: template)) {
                            if template.fields.isEmpty {
                                Text("No fields found in PDF")
                                    .foregroundColor(.secondary)
                            } else {
                                if appState.csvImport == nil {
                                    Text("Import a CSV to enable mapping.")
                                        .foregroundColor(.secondary)
                                }

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

                                            if !computedOptions.isEmpty {
                                                ForEach(computedOptions) { option in
                                                    Text(option.label).tag(option.value)
                                                }
                                            }

                                            ForEach(builtInOptions) { option in
                                                Text(option.label).tag(option.value)
                                            }

                                            if let csvImport = appState.csvImport {
                                                let headers = csvImport.headers
                                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                                    .filter { !$0.isEmpty }
                                                let uniqueHeaders = Array(Set(headers)).sorted()
                                                if !uniqueHeaders.isEmpty {
                                                    ForEach(uniqueHeaders, id: \.self) { header in
                                                        Text(header).tag(header)
                                                    }
                                                }
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .disabled(appState.csvImport == nil)
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
                            .disabled(template.fields.isEmpty || appState.csvImport == nil)
                        }
                    }
                    .sheet(isPresented: $showingCSVImport) {
                        CSVImportPreviewView()
                            .environmentObject(appState)
                    }
                    .onAppear {
                        fieldMappings = template.fieldMappings
                        applyAutoMappingIfNeeded(template: template)
                    }
                    .onChange(of: appState.csvImport?.reference.localPath ?? "") { _ in
                        applyAutoMappingIfNeeded(template: template)
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

    private func mappingHeader(template: PDFTemplate) -> some View {
        let total = template.fields.count
        let mapped = template.fields.filter { field in
            let value = fieldMappings[field.name] ?? ""
            return !value.isEmpty
        }.count
        return HStack {
            Text("Map PDF fields")
            Spacer()
            Text("Mapped \(mapped) / \(total)")
                .foregroundColor(.secondary)
                .font(.footnote)
        }
    }

    private func applyAutoMappingIfNeeded(template: PDFTemplate) {
        guard appState.csvImport != nil else { return }

        let csvOptions = csvHeaderOptions()
        let allCandidates = (computedOptions + builtInOptions + csvOptions)

        var updated = fieldMappings
        for field in template.fields {
            let existing = updated[field.name] ?? ""
            guard existing.isEmpty else { continue }

            let normalizedPDF = field.normalized ?? NormalizedName.from(field.name)
            if let suggestion = AutoMapper.suggest(pdfField: normalizedPDF, candidates: allCandidates) {
                updated[field.name] = suggestion
            }
        }

        // Only mutate state if something changed (prevents unnecessary UI churn).
        if updated != fieldMappings {
            fieldMappings = updated
        }
    }

    private func csvHeaderOptions() -> [MappingOption] {
        guard let csvImport = appState.csvImport else { return [] }

        let headers = csvImport.headers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Snapshot may already include normalizedHeaders; fall back to on-the-fly normalization.
        let normalized = csvImport.normalizedHeaders
        var out: [MappingOption] = []
        out.reserveCapacity(headers.count)

        var seen = Set<String>()
        for (idx, header) in headers.enumerated() {
            if seen.contains(header) { continue }
            seen.insert(header)

            let norm: NormalizedName
            if let normalized, idx < normalized.count {
                norm = normalized[idx]
            } else {
                norm = NormalizedName.from(header)
            }

            out.append(MappingOption(value: header, label: header, normalized: norm, kind: .csvHeader))
        }

        return out
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
            .environmentObject(AppState())
    }
}
