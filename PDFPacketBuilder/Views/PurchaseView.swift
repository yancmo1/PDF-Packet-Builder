//
//  PurchaseView.swift
//  PDFPacketBuilder
//

import SwiftUI
import StoreKit

struct PurchaseView: View {
    @EnvironmentObject var iapManager: IAPManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("Unlock Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Remove all limits")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 20) {
                        FeatureRow(icon: "doc.on.doc.fill", title: "Unlimited Templates", description: "Import as many PDF templates as you need")
                        FeatureRow(icon: "person.3.fill", title: "Unlimited Recipients", description: "Generate PDFs for any number of recipients")
                        FeatureRow(icon: "clock.fill", title: "Full History", description: "Keep all your generation logs forever")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    
                    // Price
                    if let product = iapManager.products.first {
                        VStack(spacing: 15) {
                            Button(action: {
                                purchase(product)
                            }) {
                                HStack {
                                    Text("Unlock Pro")
                                    Spacer()
                                    Text(product.displayPrice)
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .disabled(isPurchasing)
                            
                            if isPurchasing {
                                ProgressView()
                            }
                        }
                    } else {
                        ProgressView("Loading...")
                    }
                    
                    // Restore
                    Button(action: restore) {
                        Text("Restore Purchase")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if iapManager.products.isEmpty {
                    iapManager.loadProducts()
                }
            }
        }
    }
    
    private func purchase(_ product: Product) {
        isPurchasing = true
        Task {
            do {
                if let transaction = try await iapManager.purchase(product) {
                    await transaction.finish()
                    appState.updateProStatus(iapManager.isPro)
                }
            } catch {
                print("Purchase failed: \(error)")
            }
            isPurchasing = false
        }
    }
    
    private func restore() {
        Task {
            await iapManager.restorePurchases()
            appState.updateProStatus(iapManager.isPro)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseView()
            .environmentObject(IAPManager())
            .environmentObject(AppState())
    }
}
