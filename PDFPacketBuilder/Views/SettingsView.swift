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

#if DEBUG
    @State private var debugForceFreeTier = false
#endif
    
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
                    Section(header: Text("Free Plan Limits")) {
                        HStack {
                            Text("Templates")
                            Spacer()
                            Text("1 max")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Recipients per batch")
                            Spacer()
                            Text("10 max")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Log retention")
                            Spacer()
                            Text("7 days")
                                .foregroundColor(.secondary)
                        }
                    }
                    
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
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPurchaseSheet) {
                PurchaseView()
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
            .environmentObject(IAPManager())
    }
}
