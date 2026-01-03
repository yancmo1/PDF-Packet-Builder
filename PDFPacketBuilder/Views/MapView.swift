//
//  MapView.swift
//  PDFPacketBuilder
//

import SwiftUI

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var iapManager: IAPManager
    @State private var fieldMappings: [String: String] = [:]
    @State private var showingCSVImport = false
    @State private var showUsedCSVColumnsInPickers = false

    @State private var showingSaveToast = false
    @State private var saveToastMessage: String = ""

    private let computedOptions: [MappingOption] = [
        MappingOption(value: ComputedMappingValue.today.rawValue, label: "Today (MM-DD-YY)", normalized: .from("today date"), kind: .computed)
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

                        Section(header: mappingHeader(template: template), footer: mappingFooter) {
                            if template.fields.isEmpty {
                                Text("No fields found in PDF")
                                    .foregroundColor(.secondary)
                            } else {
                                if appState.csvImport == nil {
                                    Text("Import a CSV to enable mapping.")
                                        .foregroundColor(.secondary)
                                }

                                let csvOptionsAll = csvHeaderOptions().sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }

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

                                            if appState.csvImport != nil {
                                                let used = usedCSVHeaderValues(excludingPDFFieldName: field.name)
                                                let csvOptionsForField = showUsedCSVColumnsInPickers
                                                    ? csvOptionsAll
                                                    : csvOptionsAll.filter { !used.contains($0.value) }

                                                if !csvOptionsForField.isEmpty {
                                                    ForEach(csvOptionsForField) { option in
                                                        Text(option.label).tag(option.value)
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
                        ToolbarItem(placement: .navigationBarLeading) {
#if DEBUG
                            Button("Auto Map (Dev)") {
                                autoMap(template, allowWhenNotPro: true)
                            }
                            .disabled(template.fields.isEmpty || appState.csvImport == nil)
#else
                            EmptyView()
#endif
                        }
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
                        if appState.csvImport != nil {
                            fieldMappings = sanitizedMappings(fieldMappings)
                        }
                    }
                    .onChange(of: appState.csvImport?.reference.localPath ?? "") { _ in
                        // Mappings are user-owned. When the CSV changes, keep existing selections only if still valid.
                        fieldMappings = sanitizedMappings(fieldMappings)
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
        .overlay(alignment: .bottom) {
            if showingSaveToast {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(saveToastMessage)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 5)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: showingSaveToast)
            }
        }
    }
    
    private func saveMapping() {
        guard var template = appState.pdfTemplate else {
            showSaveToast("Nothing to save")
            return
        }
        template.fieldMappings = fieldMappings
        appState.saveTemplate(template)
        showSaveToast("Mappings saved")
    }

    private func showSaveToast(_ message: String) {
        saveToastMessage = message
        showingSaveToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showingSaveToast = false
        }
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

    private var mappingFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if appState.csvImport != nil {
                Button(showUsedCSVColumnsInPickers ? "Hide used columns" : "Show used columns") {
                    showUsedCSVColumnsInPickers.toggle()
                }

                Text(showUsedCSVColumnsInPickers
                     ? "Used CSV columns are shown in the pickers."
                     : "Used CSV columns are hidden from other pickers to prevent duplicate mappings."
                )
                .font(.footnote)
                .foregroundColor(.secondary)
            }
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

    private func usedCSVHeaderValues(excludingPDFFieldName: String) -> Set<String> {
        var used = Set<String>()
        used.reserveCapacity(fieldMappings.count)

        for (pdfField, mapping) in fieldMappings {
            if pdfField == excludingPDFFieldName { continue }

            let trimmed = mapping.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Computed values can be reused across multiple PDF fields.
            if trimmed == ComputedMappingValue.today.rawValue { continue }

            used.insert(trimmed)
        }

        return used
    }

    private func autoMap(_ template: PDFTemplate, allowWhenNotPro: Bool) {
        if !allowWhenNotPro, !iapManager.isProUnlocked {
            showSaveToast("Auto mapping is available in Pro")
            return
        }

        guard appState.csvImport != nil else {
            showSaveToast("Import a CSV first")
            return
        }

        let candidates = csvHeaderOptions()
        if candidates.isEmpty {
            showSaveToast("No CSV columns available")
            return
        }

        var used = usedCSVHeaderValues(excludingPDFFieldName: "")
        var updated = fieldMappings
        var newlyMapped = 0

        for field in template.fields {
            let current = (updated[field.name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard current.isEmpty else { continue }

            let pdfNorm = NormalizedName.from(field.name)
            guard let suggestion = AutoMapper.suggest(pdfField: pdfNorm, candidates: candidates) else { continue }

            // Keep mappings one-to-one by default.
            guard !used.contains(suggestion) else { continue }

            updated[field.name] = suggestion
            used.insert(suggestion)
            newlyMapped += 1
        }

        fieldMappings = updated

        if newlyMapped > 0 {
            showSaveToast("Auto-mapped \(newlyMapped) fields")
        } else {
            showSaveToast("No safe auto-maps found")
        }
    }

    private func sanitizedMappings(_ mappings: [String: String]) -> [String: String] {
        guard let csvImport = appState.csvImport else { return mappings }

        let allowedHeaders = Set(
            csvImport.headers
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        var cleaned: [String: String] = [:]
        cleaned.reserveCapacity(mappings.count)

        for (pdfField, mapping) in mappings {
            let trimmed = mapping.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Allow the single supported computed value.
            if trimmed == ComputedMappingValue.today.rawValue {
                cleaned[pdfField] = trimmed
                continue
            }

            // Otherwise allow only exact CSV headers.
            if allowedHeaders.contains(trimmed) {
                cleaned[pdfField] = trimmed
            }
        }

        return cleaned
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
            .environmentObject(AppState())
            .environmentObject(IAPManager())
    }
}
