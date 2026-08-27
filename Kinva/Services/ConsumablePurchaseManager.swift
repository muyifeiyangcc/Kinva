import Foundation
import StoreKit

/// StoreKit V1 manager for consumable diamond products.
///
/// Product identifiers and their delivered diamond amounts live in Info.plist under
/// `KinvaConsumableProducts`. The list may contain any number of products, so the
/// production catalog can expand from 6 to 10 without changing this purchase flow.
@MainActor
final class ConsumablePurchaseManager: NSObject {
    struct Product: Hashable {
        let identifier: String
        let diamonds: Int
        let displayPrice: String
    }

    static let shared = ConsumablePurchaseManager()

    private struct Configuration {
        let identifier: String
        let diamonds: Int
        let displayPrice: String
    }

    private static let fallbackConfigurations: [Configuration] = [
        Configuration(identifier: "zwzmodcmkqkhvved", diamonds: 400, displayPrice: "$0.99"),
        Configuration(identifier: "jurnintfnozyilpw", diamonds: 1_200, displayPrice: "$1.99"),
        Configuration(identifier: "mnnpmcndncqtojxp", diamonds: 2_450, displayPrice: "$4.99"),
        Configuration(identifier: "xkckndlfqkslqkdf", diamonds: 4_900, displayPrice: "$9.99"),
        Configuration(identifier: "ajtmpiofycjrjxww", diamonds: 6_400, displayPrice: "$12.99"),
        Configuration(identifier: "wehtrucfbainxgqn", diamonds: 9_800, displayPrice: "$19.99"),
        Configuration(identifier: "bshwyofiwvkwjyer", diamonds: 14_900, displayPrice: "$29.99"),
        Configuration(identifier: "aqikhijvnzfggsso", diamonds: 24_500, displayPrice: "$49.99"),
        Configuration(identifier: "znsgbfpvsfeldalb", diamonds: 34_500, displayPrice: "$69.99"),
        Configuration(identifier: "tfmuzjyjtxyaoyfv", diamonds: 49_000, displayPrice: "$99.99")
    ]

    private lazy var configurations = Self.loadConfigurations()
    private var productsByIdentifier: [String: SKProduct] = [:]
    private var productsRequest: SKProductsRequest?
    private var productCallbacks: [(Result<[Product], Error>) -> Void] = []
    private var purchaseCallback: ((Result<Int, Error>) -> Void)?
    private var purchasingProductIdentifier: String?
    private var isObservingQueue = false

    private override init() {
        super.init()
    }

    func start() {
        guard !isObservingQueue else { return }
        isObservingQueue = true
        SKPaymentQueue.default().add(self)
        loadProducts(forceRefresh: false) { _ in }
    }

    func stop() {
        guard isObservingQueue else { return }
        SKPaymentQueue.default().remove(self)
        isObservingQueue = false
        productsRequest?.cancel()
        productsRequest = nil
    }

    func loadProducts(forceRefresh: Bool = false,
                      completion: @escaping (Result<[Product], Error>) -> Void) {
        if !forceRefresh, !productsByIdentifier.isEmpty {
            completion(.success(displayProducts()))
            return
        }

        productCallbacks.append(completion)
        guard productsRequest == nil else { return }
        guard !configurations.isEmpty else {
            finishProductLoading(with: .failure(PurchaseError.missingConfiguration))
            return
        }

        let request = SKProductsRequest(productIdentifiers: Set(configurations.map(\.identifier)))
        productsRequest = request // SKProductsRequest must be retained until its callback.
        request.delegate = self
        request.start()
    }

    func purchase(productID: String,
                  completion: @escaping (Result<Int, Error>) -> Void) {
        guard purchaseCallback == nil else {
            completion(.failure(PurchaseError.purchaseInProgress))
            return
        }
        guard SKPaymentQueue.canMakePayments() else {
            completion(.failure(PurchaseError.paymentsDisabled))
            return
        }
        guard let product = productsByIdentifier[productID] else {
            completion(.failure(PurchaseError.productUnavailable))
            return
        }

        purchaseCallback = completion
        purchasingProductIdentifier = productID
        SKPaymentQueue.default().add(SKPayment(product: product))
    }

    private func displayProducts() -> [Product] {
        configurations.compactMap { configuration in
            guard productsByIdentifier[configuration.identifier] != nil else { return nil }
            return Product(identifier: configuration.identifier,
                           diamonds: configuration.diamonds,
                           displayPrice: configuration.displayPrice)
        }
    }

    private func finishProductLoading(with result: Result<[Product], Error>) {
        productsRequest = nil
        let callbacks = productCallbacks
        productCallbacks.removeAll()
        callbacks.forEach { $0(result) }
    }

    private func finishPurchase(for productID: String, with result: Result<Int, Error>) {
        guard purchasingProductIdentifier == productID else { return }
        let callback = purchaseCallback
        purchaseCallback = nil
        purchasingProductIdentifier = nil
        callback?(result)
    }

    private static func loadConfigurations() -> [Configuration] {
        guard let values = Bundle.main.object(forInfoDictionaryKey: "KinvaConsumableProducts") as? [[String: Any]] else {
            return fallbackConfigurations
        }
        let configured = values.compactMap { value -> Configuration? in
            guard let identifier = value["productIdentifier"] as? String,
                  !identifier.isEmpty,
                  let diamonds = value["diamonds"] as? Int,
                  diamonds > 0,
                  let displayPrice = value["displayPrice"] as? String,
                  !displayPrice.isEmpty else { return nil }
            return Configuration(identifier: identifier,
                                 diamonds: diamonds,
                                 displayPrice: displayPrice)
        }
        return configured.isEmpty ? fallbackConfigurations : configured
    }
}

extension ConsumablePurchaseManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        productsByIdentifier = Dictionary(uniqueKeysWithValues: response.products.map { ($0.productIdentifier, $0) })
        let products = displayProducts()
        if products.isEmpty {
            finishProductLoading(with: .failure(PurchaseError.noProductsReturned))
        } else {
            finishProductLoading(with: .success(products))
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        finishProductLoading(with: .failure(error))
    }
}

extension ConsumablePurchaseManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            let productID = transaction.payment.productIdentifier
            // BPackage records its product ownership before enqueuing payment.
            // Leave those transactions exclusively to its receipt-verification
            // manager; the A package must never finish them first.
            if StoreKit1PurchaseManager.bPackageShared.bPackageOwnsProductIdentifier(productID) {
                continue
            }
            switch transaction.transactionState {
            case .purchased:
                guard let diamonds = configurations.first(where: { $0.identifier == productID })?.diamonds else {
                    queue.finishTransaction(transaction)
                    finishPurchase(for: productID, with: .failure(PurchaseError.missingConfiguration))
                    continue
                }
                let transactionID = transaction.transactionIdentifier ?? "storekit-v1-\(UUID().uuidString)"
                do {
                    try LocalDataStore.shared.addDiamonds(diamonds, transactionID: transactionID)
                    queue.finishTransaction(transaction)
                    finishPurchase(for: productID, with: .success(diamonds))
                } catch {
                    // Keep the transaction unfinished so StoreKit can deliver it again after
                    // a temporary local persistence failure.
                    finishPurchase(for: productID, with: .failure(error))
                }

            case .failed:
                let resultError: Error
                if let storeKitError = transaction.error as? SKError,
                   storeKitError.code == .paymentCancelled {
                    resultError = PurchaseError.cancelled
                } else {
                    resultError = transaction.error ?? PurchaseError.failed
                }
                queue.finishTransaction(transaction)
                finishPurchase(for: productID, with: .failure(resultError))

            case .deferred:
                finishPurchase(for: productID, with: .failure(PurchaseError.deferred))

            case .restored:
                // Consumables are never restored. Finish unexpected restored transactions
                // without granting the consumable again.
                queue.finishTransaction(transaction)

            case .purchasing:
                break

            @unknown default:
                queue.finishTransaction(transaction)
                finishPurchase(for: productID, with: .failure(PurchaseError.failed))
            }
        }
    }
}

enum PurchaseError: LocalizedError {
    case paymentsDisabled
    case productUnavailable
    case noProductsReturned
    case missingConfiguration
    case purchaseInProgress
    case cancelled
    case deferred
    case failed

    var errorDescription: String? {
        switch self {
        case .paymentsDisabled:
            return "In-app purchases are disabled on this device."
        case .productUnavailable:
            return "This product is not currently available. Please refresh and try again."
        case .noProductsReturned:
            return "No recharge products are currently available from the App Store."
        case .missingConfiguration:
            return "The recharge product configuration is unavailable."
        case .purchaseInProgress:
            return "Another purchase is already in progress."
        case .cancelled:
            return "Purchase cancelled."
        case .deferred:
            return "This purchase is awaiting approval."
        case .failed:
            return "The purchase could not be completed."
        }
    }
}
