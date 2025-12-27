//
//  PurchaseView.swift
//  PDFPacketBuilder
//

import SwiftUI
import StoreKit

struct PurchaseView: View {
    @EnvironmentObject var iapManager: IAPManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isPurchasing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Unlock Pro")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Remove all limits")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "doc.fill", text: "Unlimited templates")
                    FeatureRow(icon: "person.2.fill", text: "Unlimited recipients")
                    FeatureRow(icon: "calendar", text: "Unlimited log retention")
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                if iapManager.products.isEmpty {
                    if iapManager.isLoading {
                        ProgressView()
                    } else {
                        Text("Product unavailable")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(iapManager.products, id: \.id) { product in
                        Button(action: {
                            purchaseProduct(product)
                        }) {
                            VStack(spacing: 8) {
                                Text("Unlock Pro")
                                    .fontWeight(.semibold)
                                Text(product.displayPrice)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                
                Text("One-time purchase")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            .navigationTitle("Upgrade")
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
                dismiss()
            } catch {
                print("Purchase failed: \(error)")
            }
            isPurchasing = false
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
        }
    }
}

struct PurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseView()
            .environmentObject(IAPManager())
    }
}
