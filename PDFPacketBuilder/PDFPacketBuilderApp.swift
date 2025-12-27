//
//  PDFPacketBuilderApp.swift
//  PDFPacketBuilder
//

import SwiftUI

@main
struct PDFPacketBuilderApp: App {
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
