//
//  CSVImportPreviewView.swift
//  PDFPacketBuilder
//

import SwiftUI
import UniformTypeIdentifiers

struct CSVImportPreviewView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var showingDocumentPicker = false
    @State private var isProcessing = false

    @State private var fileName: String?
    @State private var headers: [String] = []
    @State private var rows: [[String]] = []
    @State private var errorMessage: String?
    @State private var showingNoEmailDetectedAlert = false

    private let csvService = CSVService()
    private let storageService = StorageService()

    var body: some View {
        NavigationView {
            Group {
                if headers.isEmpty && rows.isEmpty && fileName == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("Import CSV")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Select a CSV file")
                            .foregroundColor(.secondary)

                        Button {
                            showingDocumentPicker = true
                        } label: {
                            Label("Select CSV", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                } else {
                    List {
                        if let fileName {
                            Section {
                                HStack {
                                    Text("File")
                                    Spacer()
                                    Text(fileName)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }

                        Section(header: Text("Headers")) {
                            if headers.isEmpty {
                                Text("No headers")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                                    HStack {
                                        Text("\(index + 1)")
                                            .foregroundColor(.secondary)
                                            .frame(width: 28, alignment: .trailing)
                                        Text(header.isEmpty ? "(empty)" : header)
                                    }
                                }
                            }
                        }

                        Section(header: Text("Preview")) {
                            if rows.isEmpty {
                                Text("No rows")
                                    .foregroundColor(.secondary)
                            } else {
                                CSVPreviewTable(headers: headers, rows: rows)
                                    .frame(minHeight: 200)
                            }
                        }
                    }
                }
            }
            .navigationTitle("CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingDocumentPicker = true
                        } label: {
                            Label("Select CSV", systemImage: "folder")
                        }

                        if appState.csvImport != nil {
                            Button(role: .destructive) {
                                appState.clearCSVImport()
                                fileName = nil
                                headers = []
                                rows = []
                                errorMessage = nil
                            } label: {
                                Label("Clear", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(
                    contentTypes: [.commaSeparatedText, .plainText],
                    onSelected: handleCSVSelected
                )
            }
            .overlay {
                if isProcessing {
                    ProgressView("Reading CSV...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .alert("No email column detected", isPresented: $showingNoEmailDetectedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("No email column detected. You need to manually select email recipients.")
            }
            .onAppear {
                if let csvImport = appState.csvImport {
                    loadPreview(from: csvImport.reference.url, fileName: csvImport.reference.originalFileName)
                }
            }
        }
    }

    private func handleCSVSelected(url: URL) {
        errorMessage = nil
        isProcessing = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let reference = try storageService.importCSVToDocuments(from: url)
                let csvText = try String(contentsOf: reference.url, encoding: .utf8)
                let preview = csvService.parsePreview(data: csvText, maxRows: 25)
                let recipients = csvService.parseCSV(data: csvText)

                let normalized = preview.headers.map { NormalizedName.from($0) }
                let snapshot = CSVImportSnapshot(reference: reference, headers: preview.headers, normalizedHeaders: normalized)

                DispatchQueue.main.async {
                    appState.saveCSVImport(snapshot)

                    // Replace previously CSV-imported recipients, but keep manual/contacts.
                    let preserved = appState.recipients.filter { $0.source != .csv }
                    appState.saveRecipients(preserved + recipients)

                    // Auto-select a CSV email column if we can detect exactly one.
                    let emailDetection = csvService.detectEmailColumn(preview: preview)
                    if let detected = emailDetection.selectedHeader {
                        appState.saveCSVEmailColumn(detected)
                    } else {
                        appState.saveCSVEmailColumn(nil)
                        showingNoEmailDetectedAlert = true
                    }

                    // Presentation-only: default a display-name column when possible.
                    let displayNameDetection = csvService.detectDisplayNameColumn(preview: preview)
                    if let detected = displayNameDetection.selectedHeader {
                        appState.saveCSVDisplayNameColumn(detected)
                    } else {
                        appState.saveCSVDisplayNameColumn(nil)
                    }

                    fileName = reference.originalFileName
                    headers = preview.headers
                    rows = preview.rows
                    isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    errorMessage = "Could not read this file."
                }
            }
        }
    }

    private func loadPreview(from url: URL, fileName: String) {
        errorMessage = nil
        isProcessing = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let csvText = try String(contentsOf: url, encoding: .utf8)
                let preview = csvService.parsePreview(data: csvText, maxRows: 25)

                DispatchQueue.main.async {
                    self.fileName = fileName
                    self.headers = preview.headers
                    self.rows = preview.rows
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = "Could not open saved CSV."
                }
            }
        }
    }
}

private struct CSVPreviewTable: View {
    let headers: [String]
    let rows: [[String]]

    private let columnWidth: CGFloat = 160

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 8) {
                headerRow
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    rowView(row)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var headerRow: some View {
        LazyHStack(alignment: .top, spacing: 12) {
            ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                Text(header.isEmpty ? "(empty)" : header)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: columnWidth, alignment: .leading)
                    .lineLimit(1)
            }
        }
    }

    private func rowView(_ row: [String]) -> some View {
        LazyHStack(alignment: .top, spacing: 12) {
            ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: columnWidth, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}
