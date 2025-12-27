//
//  IAPManager.swift
//  PDFPacketSender
//
//  In-App Purchase management for one-time purchase and Pro features
//

import Foundation
import StoreKit

class IAPManager: NSObject, ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs = Set<String>()
    @Published var isLoading = false
    
    // Product IDs - UPDATE THESE WITH YOUR ACTUAL APP STORE PRODUCT IDS
    static let fullAppProductID = "com.yourcompany.pdfpacketsender.fullapp"
    static let proFeaturesProductID = "com.yourcompany.pdfpacketsender.pro"
    
    private var updateListenerTask: Task<Void, Error>?
    
    override init() {
        super.init()
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // Listen for transaction updates
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // Load products from App Store
    @MainActor
    func loadProducts() {
        isLoading = true
        Task {
            do {
                let products = try await Product.products(for: [
                    Self.fullAppProductID,
                    Self.proFeaturesProductID
                ])
                self.products = products.sorted { $0.price < $1.price }
                await updatePurchasedProducts()
            } catch {
                print("Failed to load products: \(error)")
            }
            isLoading = false
        }
    }
    
    // Purchase a product
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return transaction
            
        case .userCancelled, .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    // Restore purchases
    @MainActor
    func restorePurchases() async {
        isLoading = true
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
        isLoading = false
    }
    
    // Update purchased products
    @MainActor
    private func updatePurchasedProducts() async {
        var purchasedIDs = Set<String>()
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchasedIDs.insert(transaction.productID)
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
    }
    
    // Check if user has purchased the full app
    var hasFullApp: Bool {
        return purchasedProductIDs.contains(Self.fullAppProductID)
    }
    
    // Check if user has Pro features
    var hasPro: Bool {
        return purchasedProductIDs.contains(Self.proFeaturesProductID)
    }
    
    // Verify transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw IAPError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum IAPError: Error {
    case failedVerification
}
