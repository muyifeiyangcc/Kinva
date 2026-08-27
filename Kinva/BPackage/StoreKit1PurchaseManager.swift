import Foundation
import StoreKit

final class StoreKit1PurchaseManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver, SKRequestDelegate {
    static let bPackageShared = StoreKit1PurchaseManager()

    enum BPackageState {
        case bPackageLoading(String)
        case bPackageSuccess(String)
        case bPackageFailure(String)
        case bPackageCancelled
    }

    private struct BPackagePaymentContext: Codable {
        let bPackageBatchNo: String
        let bPackageOrderCode: String
        var bPackageAmount: String?
        var bPackageCurrency: String?
    }

    private var bPackageOnStateChange: ((BPackageState) -> Void)?
    private var bPackageAPI: BPackageAPIClient?
    private var bPackageEventReporter: BPackageEventReporter?
    private var bPackageProductRequest: SKProductsRequest?
    private var bPackageReceiptRefreshRequest: SKReceiptRefreshRequest?
    private var bPackageWaitingForReceipt: [SKPaymentTransaction] = []
    private var bPackageProcessingTransactions = Set<String>()
    private let bPackageContextKey = "bPackage.storeKit1.pendingPaymentContext"
    private let bPackageOwnedProductIDsKey = "bPackage.storeKit1.ownedProductIDs"
    private let bPackageVerifiedTransactionIDsKey = "bPackage.storeKit1.verifiedTransactionIDs"

    private override init() { super.init() }

    func bPackageStartObserving() {
        SKPaymentQueue.default().add(self)
        BPackageLogger.bPackageShared.bPackageLog("StoreKit1", "交易观察者已在 App 启动时注册")
    }

    func bPackageStopObserving() { SKPaymentQueue.default().remove(self) }

    func bPackageConfigure(bPackageAPI: BPackageAPIClient,
                           bPackageEventReporter: BPackageEventReporter,
                           bPackageOnStateChange: @escaping (BPackageState) -> Void) {
        self.bPackageAPI = bPackageAPI
        self.bPackageEventReporter = bPackageEventReporter
        self.bPackageOnStateChange = bPackageOnStateChange
        SKPaymentQueue.default().transactions
            .filter {
                bPackageOwnsProductIdentifier($0.payment.productIdentifier) &&
                ($0.transactionState == .purchased || $0.transactionState == .restored)
            }
            .forEach(bPackageProcessPurchasedTransaction)
    }

    func bPackageDetachUI() { bPackageOnStateChange = nil }

    func bPackagePurchase(bPackageBatchNo: String, bPackageOrderCode: String) {
        guard !bPackageBatchNo.isEmpty else { bPackageNotify(.bPackageFailure("The product ID is missing.")); return }
        guard !bPackageOrderCode.isEmpty else { bPackageNotify(.bPackageFailure("The order number is missing.")); return }
        guard SKPaymentQueue.canMakePayments() else { bPackageNotify(.bPackageFailure("In-App Purchases are not allowed on this device.")); return }
        guard SKPaymentQueue.default().transactions.allSatisfy({ $0.transactionState != .purchasing && $0.transactionState != .deferred }) else {
            bPackageNotify(.bPackageFailure("Another payment is already in progress.")); return
        }
        bPackageRememberOwnedProductID(bPackageBatchNo)
        bPackageSaveContext(BPackagePaymentContext(bPackageBatchNo: bPackageBatchNo,
                                                   bPackageOrderCode: bPackageOrderCode,
                                                   bPackageAmount: nil,
                                                   bPackageCurrency: nil))
        bPackageNotify(.bPackageLoading("Loading product information…"))
        BPackageLogger.bPackageShared.bPackageLog("StoreKit1", "查询 BPackage 商品 Product ID=\(bPackageBatchNo)")
        let bPackageRequest = SKProductsRequest(productIdentifiers: [bPackageBatchNo])
        bPackageProductRequest = bPackageRequest
        bPackageRequest.delegate = self
        bPackageRequest.start()
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        bPackageProductRequest = nil
        guard var bPackageContext = bPackageLoadContext(),
              let bPackageProduct = response.products.first(where: { $0.productIdentifier == bPackageContext.bPackageBatchNo }) else {
            let bPackageInvalid = response.invalidProductIdentifiers.joined(separator: ",")
            bPackageClearContext()
            bPackageNotify(.bPackageFailure("The App Store product was not found. Invalid product ID: \(bPackageInvalid)"))
            return
        }
        guard let bPackageCurrency = bPackageProduct.priceLocale.currencyCode,
              !bPackageCurrency.isEmpty else {
            bPackageClearContext()
            bPackageNotify(.bPackageFailure("The App Store did not return a valid currency."))
            return
        }
        bPackageContext.bPackageAmount = bPackageProduct.price.stringValue
        bPackageContext.bPackageCurrency = bPackageCurrency
        bPackageSaveContext(bPackageContext)
        let bPackagePayment = SKMutablePayment(product: bPackageProduct)
        bPackagePayment.quantity = 1
        bPackageNotify(.bPackageLoading("Waiting for payment confirmation…"))
        BPackageLogger.bPackageShared.bPackageLog("StoreKit1", "商品查询成功：\(bPackageProduct.productIdentifier)，价格=\(bPackageProduct.price)，加入支付队列")
        SKPaymentQueue.default().add(bPackagePayment)
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        if request === bPackageReceiptRefreshRequest {
            bPackageReceiptRefreshRequest = nil
            bPackageWaitingForReceipt.removeAll()
            bPackageNotify(.bPackageFailure("Unable to refresh the App Store receipt: \(error.localizedDescription)"))
        } else {
            bPackageProductRequest = nil
            bPackageClearContext()
            bPackageNotify(.bPackageFailure("Unable to load the App Store product: \(error.localizedDescription)"))
        }
    }

    func requestDidFinish(_ request: SKRequest) {
        guard request === bPackageReceiptRefreshRequest else { return }
        bPackageReceiptRefreshRequest = nil
        let bPackageTransactions = bPackageWaitingForReceipt
        bPackageWaitingForReceipt.removeAll()
        BPackageLogger.bPackageShared.bPackageLog("StoreKit1", "Receipt 刷新完成，继续验单")
        bPackageTransactions.forEach(bPackageProcessPurchasedTransaction)
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for bPackageTransaction in transactions {
            guard bPackageOwnsProductIdentifier(bPackageTransaction.payment.productIdentifier) else {
                continue
            }
            switch bPackageTransaction.transactionState {
            case .purchasing:
                bPackageNotify(.bPackageLoading("Processing payment…"))
            case .deferred:
                bPackageNotify(.bPackageLoading("Payment is awaiting approval…"))
            case .purchased, .restored:
                bPackageProcessPurchasedTransaction(bPackageTransaction)
            case .failed:
                let bPackageError = bPackageTransaction.error as NSError?
                queue.finishTransaction(bPackageTransaction)
                bPackageClearContext()
                if bPackageError?.domain == SKErrorDomain, bPackageError?.code == SKError.paymentCancelled.rawValue {
                    BPackageLogger.bPackageShared.bPackageLog("StoreKit1", "用户取消支付")
                    bPackageNotify(.bPackageCancelled)
                } else {
                    bPackageNotify(.bPackageFailure("Payment failed: \(bPackageTransaction.error?.localizedDescription ?? "Unknown error")"))
                }
            @unknown default:
                bPackageNotify(.bPackageFailure("The App Store returned an unknown transaction state."))
            }
        }
    }

    private func bPackageProcessPurchasedTransaction(_ bPackageTransaction: SKPaymentTransaction) {
        guard let bPackageTransactionID = bPackageTransaction.transactionIdentifier, !bPackageTransactionID.isEmpty else {
            bPackageNotify(.bPackageFailure("The App Store did not return a transaction identifier. The transaction will be retried later.")); return
        }
        guard !bPackageProcessingTransactions.contains(bPackageTransactionID) else { return }
        if bPackageHasVerifiedTransaction(bPackageTransactionID) {
            SKPaymentQueue.default().finishTransaction(bPackageTransaction)
            BPackageLogger.bPackageShared.bPackageLog("StoreKit1", "重复回调已确认验单成功，直接 finishTransaction：\(bPackageTransactionID)")
            return
        }
        guard let bPackageAPI else {
            BPackageLogger.bPackageShared.bPackageLog("StoreKit1", "验单接口尚未配置，保留交易")
            return
        }
        guard let bPackageContext = bPackageLoadContext() else {
            BPackageLogger.bPackageShared.bPackageLog("StoreKit1", "交易缺少订单上下文，视为重复或历史回调；不向用户显示支付失败弹窗：\(bPackageTransactionID)")
            return
        }
        guard bPackageContext.bPackageBatchNo == bPackageTransaction.payment.productIdentifier else {
            bPackageNotify(.bPackageFailure("The purchased product does not match the order. Verification will be retried later.")); return
        }
        guard let bPackageReceipt = bPackageReadReceipt() else {
            if !bPackageWaitingForReceipt.contains(where: { $0 === bPackageTransaction }) { bPackageWaitingForReceipt.append(bPackageTransaction) }
            if bPackageReceiptRefreshRequest == nil {
                bPackageNotify(.bPackageLoading("Refreshing the App Store receipt…"))
                let bPackageRequest = SKReceiptRefreshRequest()
                bPackageReceiptRefreshRequest = bPackageRequest
                bPackageRequest.delegate = self
                bPackageRequest.start()
            }
            return
        }
        let bPackageCallbackResult = bPackageMakeCallbackResult(bPackageOrderCode: bPackageContext.bPackageOrderCode)
        bPackageProcessingTransactions.insert(bPackageTransactionID)
        bPackageNotify(.bPackageLoading("Payment completed. Verifying purchase…"))
        BPackageLogger.bPackageShared.bPackageLog("StoreKit1", "调用 3.2.5 验单；收据与订单信息已脱敏")
        Task {
            do {
                try await bPackageAPI.bPackageVerifyPayment(bPackageTransactionID: bPackageTransactionID,
                                                            bPackageReceipt: bPackageReceipt,
                                                            bPackageCallbackResult: bPackageCallbackResult)
                await MainActor.run {
                    self.bPackageProcessingTransactions.remove(bPackageTransactionID)
                    guard let bPackageAmountText = bPackageContext.bPackageAmount,
                          let bPackageAmount = Decimal(string: bPackageAmountText),
                          let bPackageCurrency = bPackageContext.bPackageCurrency,
                          !bPackageCurrency.isEmpty else {
                        self.bPackageNotify(.bPackageFailure("The purchase was verified, but its price or currency is missing. The transaction will be retried later."))
                        return
                    }
                    self.bPackageEventReporter?.bPackageReportPurchase(
                        bPackageAmount: bPackageAmount,
                        bPackageCurrency: bPackageCurrency
                    )
                    self.bPackageRememberVerifiedTransaction(bPackageTransactionID)
                    SKPaymentQueue.default().finishTransaction(bPackageTransaction)
                    self.bPackageClearContext()
                    BPackageLogger.bPackageShared.bPackageLog("StoreKit1", "验单 code=0000；触发 Purchase 后已 finishTransaction")
                    self.bPackageNotify(.bPackageSuccess("Payment successful"))
                }
            } catch {
                await MainActor.run {
                    self.bPackageProcessingTransactions.remove(bPackageTransactionID)
                    BPackageLogger.bPackageShared.bPackageLog("StoreKit1", "验单失败：\(error.localizedDescription)。交易未 finish")
                    self.bPackageNotify(.bPackageFailure("Payment completed, but verification failed: \(error.localizedDescription)\nThe transaction will be retried later."))
                }
            }
        }
    }

    private func bPackageReadReceipt() -> String? {
        guard let bPackageURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: bPackageURL.path),
              let bPackageData = try? Data(contentsOf: bPackageURL), !bPackageData.isEmpty else { return nil }
        return bPackageData.base64EncodedString()
    }

    private func bPackageMakeCallbackResult(bPackageOrderCode: String) -> String {
        guard let bPackageData = try? JSONSerialization.data(withJSONObject: ["orderCode": bPackageOrderCode], options: [.sortedKeys]) else { return "" }
        return String(decoding: bPackageData, as: UTF8.self)
    }

    private func bPackageSaveContext(_ bPackageValue: BPackagePaymentContext) {
        if let bPackageData = try? JSONEncoder().encode(bPackageValue) {
            UserDefaults.standard.set(bPackageData, forKey: bPackageContextKey)
        }
    }

    private func bPackageLoadContext() -> BPackagePaymentContext? {
        guard let bPackageData = UserDefaults.standard.data(forKey: bPackageContextKey) else { return nil }
        return try? JSONDecoder().decode(BPackagePaymentContext.self, from: bPackageData)
    }

    private func bPackageClearContext() { UserDefaults.standard.removeObject(forKey: bPackageContextKey) }

    private func bPackageHasVerifiedTransaction(_ bPackageTransactionID: String) -> Bool {
        let bPackageIDs = UserDefaults.standard.stringArray(forKey: bPackageVerifiedTransactionIDsKey) ?? []
        return bPackageIDs.contains(bPackageTransactionID)
    }

    private func bPackageRememberVerifiedTransaction(_ bPackageTransactionID: String) {
        var bPackageIDs = UserDefaults.standard.stringArray(forKey: bPackageVerifiedTransactionIDsKey) ?? []
        guard !bPackageIDs.contains(bPackageTransactionID) else { return }
        bPackageIDs.append(bPackageTransactionID)
        UserDefaults.standard.set(bPackageIDs, forKey: bPackageVerifiedTransactionIDsKey)
    }

    func bPackageOwnsProductIdentifier(_ bPackageProductIdentifier: String) -> Bool {
        let bPackageIDs = UserDefaults.standard.stringArray(forKey: bPackageOwnedProductIDsKey) ?? []
        return bPackageIDs.contains(bPackageProductIdentifier)
    }

    private func bPackageRememberOwnedProductID(_ bPackageProductIdentifier: String) {
        var bPackageIDs = UserDefaults.standard.stringArray(forKey: bPackageOwnedProductIDsKey) ?? []
        guard !bPackageIDs.contains(bPackageProductIdentifier) else { return }
        bPackageIDs.append(bPackageProductIdentifier)
        UserDefaults.standard.set(bPackageIDs, forKey: bPackageOwnedProductIDsKey)
    }

    private func bPackageNotify(_ bPackageState: BPackageState) {
        DispatchQueue.main.async { [weak self] in self?.bPackageOnStateChange?(bPackageState) }
    }
}
