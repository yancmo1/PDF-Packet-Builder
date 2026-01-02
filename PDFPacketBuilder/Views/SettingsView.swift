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
    @State private var showingQuickStart = false

    @FocusState private var senderFocus: SenderFocus?
    @State private var showingSavedToast = false
    @State private var savedToastMessage: String = ""
    @State private var lastToastedSenderSnapshot: String = ""

    private enum SenderFocus: Hashable {
        case name
        case email
    }

#if DEBUG
    @State private var debugForceFreeTier = false
    @State private var debugForcePro = false
    @AppStorage("debug_useMailSimulator") private var debugUseMailSimulator = false
    @State private var showingResetAllDataConfirm = false
#endif

    private var appVersionDisplay: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        let s = (short ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let b = (build ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !s.isEmpty, !b.isEmpty {
            return "\(s) (\(b))"
        }
        if !s.isEmpty {
            return s
        }
        if !b.isEmpty {
            return "Build \(b)"
        }
        return ""
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

                Section(header: Text("Sender")) {
                    TextField(
                        "Sender name",
                        text: Binding(
                            get: { appState.senderName },
                            set: { newValue in
                                appState.saveSenderName(newValue)
                            }
                        )
                    )
                    .textInputAutocapitalization(.words)
                    .focused($senderFocus, equals: .name)
                    .submitLabel(.done)
                    .onSubmit {
                        senderFocus = nil
                        toastSenderSavedIfChanged()
                    }

                    TextField(
                        "Sender email",
                        text: Binding(
                            get: { appState.senderEmail },
                            set: { newValue in
                                appState.saveSenderEmail(newValue)
                            }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .focused($senderFocus, equals: .email)
                    .submitLabel(.done)
                    .onSubmit {
                        senderFocus = nil
                        toastSenderSavedIfChanged()
                    }
                }

                Section(header: Text("Help")) {
                    NavigationLink {
                        HowToUseView()
                    } label: {
                        Label("How to Use", systemImage: "questionmark.circle")
                    }

                    Button {
                        showingQuickStart = true
                    } label: {
                        Label("Quick Start", systemImage: "sparkles")
                    }
                }

#if DEBUG
                Section(header: Text("Testing")) {
                    Toggle("Simulate Free Tier", isOn: $debugForceFreeTier)
                        .onChange(of: debugForceFreeTier) { newValue in
                            iapManager.setDebugForceFreeTier(newValue)
                            if newValue {
                                debugForcePro = false
                            }
                        }

                    Toggle("Simulate Pro (dev)", isOn: $debugForcePro)
                        .onChange(of: debugForcePro) { newValue in
                            iapManager.setDebugForcePro(newValue)
                            if newValue {
                                debugForceFreeTier = false
                            }
                        }

                    Toggle("Use Mail Simulator", isOn: $debugUseMailSimulator)

                    Text("When enabled, the app will show an in-app mail simulator on devices that cannot send Mail (for example, the iOS Simulator).")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Use this to test Free-tier limits even if the current Apple ID owns Pro. This does not change real App Store entitlements.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(role: .destructive) {
                        showingResetAllDataConfirm = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
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
                        Text(appVersionDisplay)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                lastToastedSenderSnapshot = senderSnapshotKey()
            }
            .onChange(of: senderFocus) { _ in
                // When leaving a sender field, show a lightweight confirmation toast.
                if senderFocus == nil {
                    toastSenderSavedIfChanged()
                }
            }
            .overlay(alignment: .bottom) {
                if showingSavedToast {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(savedToastMessage)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: showingSavedToast)
                }
            }
            .sheet(isPresented: $showingPurchaseSheet) {
                PurchaseView()
            }
            .sheet(isPresented: $showingQuickStart) {
                QuickStartView()
            }
#if DEBUG
            .onAppear {
                debugForceFreeTier = iapManager.debugForceFreeTierEnabled()
                debugForcePro = iapManager.debugForceProEnabled()
            }
            .alert("Reset all data?", isPresented: $showingResetAllDataConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    appState.resetAllData()
                    debugForceFreeTier = false
                    iapManager.setDebugForceFreeTier(false)
                    debugForcePro = false
                    iapManager.setDebugForcePro(false)
                    debugUseMailSimulator = false
                }
            } message: {
                Text("This clears the current template, recipients, CSV import, mappings, logs, and sender info. It does not remove your Pro purchase and does not delete exported PDFs saved in Files.")
            }
#endif
        }
    }

    private func senderSnapshotKey() -> String {
        let name = appState.senderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = appState.senderEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(name)|\(email)"
    }

    private func toastSenderSavedIfChanged() {
        let snapshot = senderSnapshotKey()
        guard snapshot != lastToastedSenderSnapshot else { return }
        lastToastedSenderSnapshot = snapshot
        showSavedToast("Sender saved")
    }

    private func showSavedToast(_ message: String) {
        savedToastMessage = message
        showingSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showingSavedToast = false
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
