//
//  PurchaseView.swift
//  PDFPacketBuilder
//

import SwiftUI
import StoreKit

struct PurchaseView: View {
    @EnvironmentObject var iapManager: IAPManager
    @Environment(\.dismiss) var dismiss

    @State private var purchaseErrorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Unlock Pro")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Removes limits:")
                        .font(.headline)

                    Text("• Unlimited recipients per batch")
                    Text("• Full send history")
                    Text("• Export logs as CSV")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

                if let product = iapManager.products.first {
                    Button {
                        Task { await buy(product) }
                    } label: {
                        Text("Unlock Pro")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(iapManager.isLoading)
                } else {
                    Text("Product not available")
                        .foregroundColor(.secondary)
                }

                Button("Restore Purchases") {
                    Task { await iapManager.restorePurchases() }
                }
                .disabled(iapManager.isLoading)

                if let purchaseErrorMessage {
                    Text(purchaseErrorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if iapManager.isLoading {
                    ProgressView()
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .onAppear {
                if iapManager.products.isEmpty {
                    iapManager.loadProducts()
                }
            }
        }
    }

    private func buy(_ product: Product) async {
        purchaseErrorMessage = nil
        do {
            _ = try await iapManager.purchase(product)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                purchaseErrorMessage = "Purchase failed."
            }
        }
    }
}
