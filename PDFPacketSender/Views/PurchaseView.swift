//
//  PurchaseView.swift
//  PDFPacketSender
//
//  View for In-App Purchases
//

import SwiftUI
import StoreKit

struct PurchaseView: View {
    @EnvironmentObject var iapManager: IAPManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isPurchasing = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Available Purchases")) {
                    if iapManager.products.isEmpty {
                        if iapManager.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("No products available")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(iapManager.products, id: \.id) { product in
                            ProductRow(product: product, isPurchased: iapManager.purchasedProductIDs.contains(product.id))
                                .onTapGesture {
                                    purchaseProduct(product)
                                }
                        }
                    }
                }
                
                Section {
                    Text("Purchases are tied to your Apple ID and will sync across your devices.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Purchases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isPurchasing {
                    ProgressView("Processing...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
    }
    
    private func purchaseProduct(_ product: Product) {
        isPurchasing = true
        Task {
            do {
                _ = try await iapManager.purchase(product)
            } catch {
                print("Purchase failed: \(error)")
            }
            isPurchasing = false
        }
    }
}

struct ProductRow: View {
    let product: Product
    let isPurchased: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .fontWeight(.semibold)
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Text(product.displayPrice)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        .opacity(isPurchased ? 0.6 : 1.0)
    }
}

struct PurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseView()
            .environmentObject(IAPManager())
    }
}
