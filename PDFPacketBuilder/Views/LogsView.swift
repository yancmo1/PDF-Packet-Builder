//
//  LogsView.swift
//  PDFPacketBuilder
//
//  View for displaying send logs
//

import SwiftUI

struct LogsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var iapManager: IAPManager
    @State private var showingExportOptions = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingPurchaseSheet = false
    
    var body: some View {
        NavigationView {
            Group {
                if appState.sendLogs.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        Text("No send history")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Sent PDFs will appear here")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(appState.sendLogs) { log in
                            LogRow(log: log)
                        }
                        .onDelete(perform: deleteLogs)
                    }
                }
            }
            .navigationTitle("Logs (\(appState.sendLogs.count))")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if iapManager.isProUnlocked {
                            Button(action: exportAsCSV) {
                                Label("Export Logs", systemImage: "square.and.arrow.up")
                            }
                        } else {
                            Button(action: { showingPurchaseSheet = true }) {
                                Label("Unlock Pro", systemImage: "star.fill")
                            }
                        }
                        if !appState.sendLogs.isEmpty {
                            Divider()
                            Button(role: .destructive, action: clearAllLogs) {
                                Label("Clear All", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(appState.sendLogs.isEmpty)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingPurchaseSheet) {
                PurchaseView()
            }
        }
    }
    
    private func deleteLogs(at offsets: IndexSet) {
        var logs = appState.sendLogs
        logs.remove(atOffsets: offsets)
        appState.sendLogs = logs
        StorageService().saveLogs(logs)
    }
    
    private func clearAllLogs() {
        appState.sendLogs = []
        StorageService().saveLogs([])
    }
    
    private func exportAsCSV() {
        let csv = appState.exportLogsAsCSV()
        let fileName = "pdf_send_logs_\(Date().ISO8601Format()).csv"
        
        if let url = writeToTempFile(csv, filename: fileName) {
            exportURL = url
            showingShareSheet = true
        }
    }
    
    private func writeToTempFile(_ content: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error writing to temp file: \(error)")
            return nil
        }
    }
}

struct LogRow: View {
    let log: SendLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(log.recipientName)
                    .fontWeight(.semibold)
                Spacer()
                Text(log.method.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(methodColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            Text(log.templateName)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(log.outputFileName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(log.formattedSentDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var methodColor: Color {
        switch log.method {
        case .share:
            return .blue
        case .mail:
            return .green
        }
    }
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        LogsView()
            .environmentObject(AppState())
    }
}
