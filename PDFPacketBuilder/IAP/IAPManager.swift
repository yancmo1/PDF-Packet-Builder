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
    
    static let proProductID = "pdfpacketbuilder.pro.unlock"
    
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
        Task {
            do {
                let products = try await Product.products(for: [Self.proProductID])
                self.products = products
                await updatePurchasedProducts()
            } catch {
                print("Failed to load products: \(error)")
            }
            isLoading = false
        }
    }
    
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
        purchasedProductIDs.contains(Self.proProductID)
    }

    var isPro: Bool {
        isProUnlocked
    }
    
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
