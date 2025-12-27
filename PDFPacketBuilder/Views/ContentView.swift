//
//  ContentView.swift
//  PDFPacketSender
//
//  Main view with navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var iapManager: IAPManager
    @State private var selectedTab = 0
    
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
            
            SendView()
                .tabItem {
                    Label("Send", systemImage: "paperplane.fill")
                }
                .tag(2)
            
            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
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
