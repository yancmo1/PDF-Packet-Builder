//
//  ContentView.swift
//  PDFPacketBuilder
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var iapManager: IAPManager
    @State private var selectedTab = 0

    @AppStorage("showQuickStartOnLaunch") private var showQuickStartOnLaunch = true
    @AppStorage("hasSeenQuickStart") private var hasSeenQuickStart = false
    @State private var showingQuickStart = false
    @State private var didEvaluateQuickStartThisSession = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TemplateView()
                .tabItem {
                    Label("Template", systemImage: "doc.fill")
                }
                .tag(0)
            
            RecipientsView()
                .tabItem {
                    Label("Recipients", systemImage: "person.2.fill")
                }
                .tag(1)
            
            MapView()
                .tabItem {
                    Label("Map", systemImage: "link")
                }
                .tag(2)
            
            GenerateView()
                .tabItem {
                    Label("Generate", systemImage: "doc.on.doc")
                }
                .tag(3)
            
            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }
                .tag(4)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(5)
        }
        .onAppear {
            guard !didEvaluateQuickStartThisSession else { return }
            didEvaluateQuickStartThisSession = true

            if !hasSeenQuickStart {
                showingQuickStart = true
                return
            }

            if showQuickStartOnLaunch {
                showingQuickStart = true
            }
        }
        .sheet(isPresented: $showingQuickStart, onDismiss: {
            hasSeenQuickStart = true
        }) {
            QuickStartView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
            .environmentObject(IAPManager())
    }
}
