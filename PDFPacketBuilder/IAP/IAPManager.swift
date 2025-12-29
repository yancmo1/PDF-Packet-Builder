//
//  IAPManager.swift
//  PDFPacketBuilder
//

import Foundation
import StoreKit

class IAPManager: NSObject, ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs = Set<String>()
    @Published var isLoading = false
    @Published var lastStoreErrorMessage: String?
    @Published var lastPurchaseStatusMessage: String?
    
    static let proProductID = "com.yancmo.pdfpacketbuilder.pro.unlock"

#if DEBUG
    private static let debugForceFreeTierKey = "debug.forceFreeTier"
#endif
    
    private var updateListenerTask: Task<Void, Error>?
    
    override init() {
        super.init()
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
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
    
    @MainActor
    func loadProducts() {
        isLoading = true
        lastStoreErrorMessage = nil
        lastPurchaseStatusMessage = nil

        Task { @MainActor in
            defer { isLoading = false }
            do {
                let products = try await Product.products(for: [Self.proProductID])
                self.products = products
                await updatePurchasedProducts()
                if products.isEmpty {
                    lastStoreErrorMessage = "No products returned for \(Self.proProductID). (This usually means the Product ID doesn't exist in App Store Connect, isn't available yet, or the build isn't eligible for StoreKit testing.)"
                }
            } catch {
                let message = "Failed to load product \(Self.proProductID): \(error)"
                self.lastStoreErrorMessage = message
                print(message)
            }
        }
    }
    
    @MainActor
    func purchase(_ product: Product) async throws -> Transaction? {
        lastStoreErrorMessage = nil
        lastPurchaseStatusMessage = "Starting purchase…"

        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            self.lastPurchaseStatusMessage = "Purchase successful."
            return transaction
            
        case .userCancelled, .pending:
            switch result {
            case .userCancelled:
                self.lastPurchaseStatusMessage = "Purchase cancelled."
            case .pending:
                self.lastPurchaseStatusMessage = "Purchase pending approval."
            default:
                break
            }
            return nil
            
        @unknown default:
            self.lastPurchaseStatusMessage = "Purchase did not complete (unknown result)."
            return nil
        }
    }
    
    @MainActor
    func restorePurchases() async {
        isLoading = true
        lastStoreErrorMessage = nil
        lastPurchaseStatusMessage = nil
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            lastPurchaseStatusMessage = "Restore completed."
        } catch {
            let message = "Failed to restore purchases: \(error)"
            lastStoreErrorMessage = message
            print(message)
        }
        isLoading = false
    }
    
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
    
    var isProUnlocked: Bool {
#if DEBUG
        if UserDefaults.standard.bool(forKey: Self.debugForceFreeTierKey) {
            return false
        }
#endif
        return purchasedProductIDs.contains(Self.proProductID)
    }

#if DEBUG
    @MainActor
    func setDebugForceFreeTier(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.debugForceFreeTierKey)
        // Trigger any UI that depends on `isProUnlocked` to refresh.
        objectWillChange.send()
    }

    func debugForceFreeTierEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: Self.debugForceFreeTierKey)
    }
#endif
    
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
