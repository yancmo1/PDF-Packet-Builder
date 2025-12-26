//
//  PDFPacketSenderApp.swift
//  PDFPacketSender
//
//  Main application entry point
//

import SwiftUI

@main
struct PDFPacketSenderApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var iapManager = IAPManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(iapManager)
                .onAppear {
                    iapManager.loadProducts()
                }
        }
    }
}
