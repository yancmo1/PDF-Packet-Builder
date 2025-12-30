//
//  SettingsView.swift
//  PDFPacketBuilder
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var iapManager: IAPManager
    @State private var showingPurchaseSheet = false
    @State private var isRestoring = false

    @State private var showingLoadSamplePackConfirm = false
    @State private var samplePackAlert: SamplePackAlert?

#if DEBUG
    @State private var debugForceFreeTier = false
#endif

    private struct SamplePackAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Plan")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        if iapManager.isProUnlocked {
                            Text("Pro")
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        } else {
                            Text("Free")
                                .foregroundColor(.secondary)
                        }
                    }
                }

#if DEBUG
                Section(header: Text("Testing")) {
                    Toggle("Simulate Free Tier", isOn: $debugForceFreeTier)
                        .onChange(of: debugForceFreeTier) { newValue in
                            iapManager.setDebugForceFreeTier(newValue)
                        }

                    Text("Use this to test Free-tier limits even if the current Apple ID owns Pro. This does not change real App Store entitlements.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
#endif
                
                if !iapManager.isProUnlocked {
                    Section {
                        Button(action: {
                            showingPurchaseSheet = true
                        }) {
                            Label("Unlock Pro", systemImage: "star.fill")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: restorePurchases) {
                            HStack {
                                Label("Restore", systemImage: "arrow.clockwise")
                                if isRestoring {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isRestoring)
                    }
                }
                
                Section(header: Text("Data")) {
                    HStack {
                        Text("Templates")
                        Spacer()
                        Text("\(appState.pdfTemplate != nil ? 1 : 0)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Recipients")
                        Spacer()
                        Text("\(appState.recipients.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Logs")
                        Spacer()
                        Text("\(appState.sendLogs.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Help")) {
                    Button {
                        if appState.pdfTemplate != nil || !appState.recipients.isEmpty || !appState.sendLogs.isEmpty {
                            showingLoadSamplePackConfirm = true
                        } else {
                            loadSamplePackClearingData()
                        }
                    } label: {
                        Label("Load Sample Pack", systemImage: "shippingbox")
                    }

                    Text("This loads a sample fillable PDF template plus a small recipients CSV so you can try the full workflow quickly.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reviewer steps")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("1) Tap ‘Load Sample Pack’")
                        Text("2) Go to Templates → Map Fields")
                        Text("3) Review auto-mapped fields, then Generate")
                        Text("4) Preview any recipient (Free)")
                        Text("5) Share or Mail a filled PDF")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Section(header: Text("Pro includes")) {
                    Text("• Batch Export Folder")
                    Text("• Message Templates (tokens + preview)")
                    Text("• Export Logs (CSV)")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPurchaseSheet) {
                PurchaseView()
            }
            .alert("Load Sample Pack?", isPresented: $showingLoadSamplePackConfirm) {
                Button("Load (clears my data)", role: .destructive) {
                    loadSamplePackClearingData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear your current template, recipients, and logs, then load the built-in sample template and sample recipients.")
            }
            .alert(item: $samplePackAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
#if DEBUG
            .onAppear {
                debugForceFreeTier = iapManager.debugForceFreeTierEnabled()
            }
#endif
        }
    }
    
    private func restorePurchases() {
        isRestoring = true
        Task {
            await iapManager.restorePurchases()
            isRestoring = false
        }
    }

    private func loadSamplePackClearingData() {
        Task {
            do {
                await MainActor.run {
                    appState.clearAllData()
                }

                try await MainActor.run {
                    try SamplePackService().loadSamplePack(into: appState)
                }

                await MainActor.run {
                    samplePackAlert = SamplePackAlert(
                        title: "Sample Pack Loaded",
                        message: "A sample template and sample recipients were added. Head to Generate to try preview/share/mail."
                    )
                }
            } catch {
                await MainActor.run {
                    samplePackAlert = SamplePackAlert(
                        title: "Couldn’t Load Sample Pack",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
            .environmentObject(IAPManager())
    }
}
