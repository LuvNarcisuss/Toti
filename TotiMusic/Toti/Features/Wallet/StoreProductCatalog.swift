import Foundation
import StoreKit

struct StoreCatalogStatus {
    enum Phase: String { case idle, loading, ready, partial, unavailable, failed, timedOut }
    var phase: Phase = .idle
    var requestedIDs: [String] = []
    var returnedIDs: [String] = []
    var invalidIDs: [String] = []
    var errorSummary: String?

    var message: String? {
        switch phase {
        case .idle: return "Open the store to load diamond packages."
        case .loading: return "Loading prices from the App Store…"
        case .ready: return nil
        case .partial: return "Some packages are unavailable. You can buy the available packages or retry."
        case .unavailable: return "These packages are not available in the App Store right now. Please try again later."
        case .failed: return "Could not connect to the App Store. Check your connection and retry."
        case .timedOut: return "The App Store took too long to respond. Please retry."
        }
    }
    var canRetry: Bool { phase != .loading && phase != .ready }
}

struct StoreProductResponse {
    let products: [SKProduct]
    let invalidProductIDs: [String]
}

@MainActor
protocol StoreProductFetching: AnyObject {
    func start(_ identifiers: Set<String>, completion: @escaping (Result<StoreProductResponse, Error>) -> Void)
    func cancel()
}

/// Each wallet session owns a request delegate; canceled or superseded requests cannot deliver results.
@MainActor
final class TotiStoreProductFetcher: NSObject, StoreProductFetching, SKProductsRequestDelegate {
    private var request: SKProductsRequest?
    private var completion: ((Result<StoreProductResponse, Error>) -> Void)?

    func start(_ identifiers: Set<String>, completion: @escaping (Result<StoreProductResponse, Error>) -> Void) {
        cancel()
        let request = SKProductsRequest(productIdentifiers: identifiers)
        self.request = request
        self.completion = completion
        request.delegate = self
        request.start()
    }

    func cancel() {
        request?.delegate = nil
        request?.cancel()
        request = nil
        completion = nil
    }

    nonisolated func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        Task { @MainActor in
            self.complete(request, result: .success(StoreProductResponse(products: response.products, invalidProductIDs: response.invalidProductIdentifiers)))
        }
    }

    nonisolated func request(_ request: SKRequest, didFailWithError error: Error) {
        Task { @MainActor in self.complete(request, result: .failure(error)) }
    }

    private func complete(_ request: SKRequest, result: Result<StoreProductResponse, Error>) {
        guard let current = self.request, request === current else { return }
        let callback = completion
        current.delegate = nil
        self.request = nil
        completion = nil
        callback?(result)
    }
}

/// Bounded domain/code chains only. Never include receipts, userInfo, account IDs or credentials.
func storeErrorSummary(_ error: Error) -> String {
    var next: NSError? = error as NSError
    var entries: [String] = []
    for _ in 0..<3 {
        guard let current = next else { break }
        let domain = current.domain.filter { $0.isASCII && ($0.isLetter || $0.isNumber || ".-_".contains($0)) }.prefix(80)
        entries.append("\(domain)(\(current.code))")
        next = current.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    return entries.joined(separator: " → ")
}
