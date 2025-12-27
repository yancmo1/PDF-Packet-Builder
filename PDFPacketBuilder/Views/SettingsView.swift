//
//  SettingsView.swift
//  PDFPacketSender
//
//  Settings view with IAP and app info
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var iapManager: IAPManager
    @State private var showingPurchaseSheet = false
    @State private var isRestoring = false
    
    var body: some View {
        NavigationView {
            List {
                // App Status Section
                Section(header: Text("App Status")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Full App")
                        Spacer()
                        if iapManager.hasFullApp {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Text("Not Purchased")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Pro Features")
                        Spacer()
                        if iapManager.hasPro {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Text("Not Purchased")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Purchase Section
                if !iapManager.hasFullApp || !iapManager.hasPro {
                    Section(header: Text("In-App Purchases")) {
                        Button(action: {
                            showingPurchaseSheet = true
                        }) {
                            Label("View Available Purchases", systemImage: "cart")
                        }
                        
                        Button(action: restorePurchases) {
                            HStack {
                                Label("Restore Purchases", systemImage: "arrow.clockwise")
                                if isRestoring {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isRestoring)
                    }
                }
                
                // Data Section
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
                        Text("Send Logs")
                        Spacer()
                        Text("\(appState.sendLogs.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // About Section
                Section(header: Text("About")) {
                    Link(destination: URL(string: "https://github.com/yancmo1/PDF-Packet-Sender")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Terms of Service")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPurchaseSheet) {
                PurchaseView()
            }
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
