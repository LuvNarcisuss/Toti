import StoreKit
import StoreKitTest
import UIKit
import XCTest
@testable import toti

/// Runs the shipping StoreKit 1 service with Apple's local StoreKit server and real disk persistence.
/// The fixture is independent of the production catalog so an incorrect ID/amount fails the tests.
@MainActor
final class StoreKit1PaymentTests: XCTestCase {
    private var session: SKTestSession!
    private var purchasing: StoreKit1Purchasing!
    private var repository: LocalLibraryRepository!
    private var root: URL!
    private var ledger = WalletLedger.empty
    private var prices: [String: String] = [:]

    override func setUp() async throws {
        continueAfterFailure = true
        try await stopHostPayments()
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "TotiDiamonds", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        root = FileManager.default.temporaryDirectory.appendingPathComponent("TotiPayment-" + UUID().uuidString)
        repository = LocalLibraryRepository(root: root)
        try await startService()
    }

    override func tearDown() async throws {
        await purchasing?.stop()
        purchasing?.clearMemory()
        session?.clearTransactions()
        session?.resetToDefaultState()
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private func startService(fetcher: StoreProductFetching? = nil, timeout: TimeInterval = 20, waitForCatalog: Bool = true, owner: UUID? = nil) async throws {
        purchasing = StoreKit1Purchasing(productsFetcher: fetcher, productRequestTimeout: timeout)
        purchasing.transactionOwner = owner
        purchasing.onChange = { [weak self] ledger, prices in
            self?.ledger = ledger
            self?.prices = prices
        }
        purchasing.adopt(try await repository.loadWallet())
        enablePersistence()
        await purchasing.start()
        if waitForCatalog {
            try await eventually("Nine localized StoreKit products load") { self.prices.count == 9 }
        }
    }

    private func enablePersistence() {
        let repository = repository!
        purchasing.setPersist { ledger in
            do { try await repository.saveWallet(ledger); return true }
            catch { return false }
        }
    }

    private func buy(_ productID: String) async throws -> String? {
        let package = try XCTUnwrap(WalletCatalog.package(forProductID: productID))
        let completed = expectation(description: "Purchase settles: \(productID)")
        var message: String?
        var settled = false
        Task { @MainActor in
            message = await purchasing.purchase(package)
            settled = true
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 30)
        guard settled else { throw PaymentTestError.timeout }
        return message
    }

    private func eventually(_ description: String, condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while !condition(), Date() < deadline { try await Task.sleep(nanoseconds: 100_000_000) }
        guard condition() else { XCTFail(description); throw PaymentTestError.timeout }
    }

    func testConcurrentGiftSpendsPreserveBothDebits() async throws {
        let purchased = try await buy("jezvdjvpoifednhy")
        XCTAssertNil(purchased)
        let repository = repository!
        purchasing.setPersist { next in
            try? await Task.sleep(nanoseconds: 100_000_000)
            do { try await repository.saveWallet(next); return true }
            catch { return false }
        }
        let rose = MusicGift.catalog[0]
        async let first = purchasing.spend(rose, quantity: 1)
        async let second = purchasing.spend(rose, quantity: 1)
        let results = await [first, second]
        XCTAssertTrue(results.allSatisfy { $0 == nil })
        XCTAssertEqual(ledger.diamonds, 380)
        XCTAssertEqual(ledger.activity.filter { $0.kind == "gift" }.count, 2)
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 380)
    }

    func testScopedWalletRejectsAnotherOwnerAndRecoversForOriginalOwner() async throws {
        let originalOwner = UUID()
        purchasing.transactionOwner = originalOwner
        purchasing.setPersist { _ in false }
        let result = try await buy("jezvdjvpoifednhy")
        XCTAssertNotNil(result)
        XCTAssertEqual(ledger.diamonds, 0)
        XCTAssertTrue(purchasing.hasUnfinishedTransactions)
        await purchasing.stop()
        purchasing.transactionOwner = UUID()
        enablePersistence()
        await purchasing.start()
        XCTAssertEqual(ledger.diamonds, 0)
        XCTAssertTrue(purchasing.hasUnfinishedTransactions)
        await purchasing.stop()
        purchasing.transactionOwner = originalOwner
        await purchasing.start()
        try await eventually("Only the original test wallet receives the pending credit") { self.ledger.diamonds == 400 }
        XCTAssertEqual(ledger.creditedTransactionIDs.count, 1)
        await purchasing.stop()
        await purchasing.start()
        XCTAssertEqual(ledger.diamonds, 400)
    }

    func testGiftContextPersistsAndLegacyActivityStillDecodes() async throws {
        let purchased = try await buy("jezvdjvpoifednhy")
        XCTAssertNil(purchased)
        let post = LoungeState.editorialPosts[0]
        let context = GiftContext(surface: .post, sourceID: post.id.uuidString, sourceTitle: "Lounge post",
            recipients: [GiftRecipient(id: post.author.id, name: post.author.name)])
        let result = await purchasing.spend(MusicGift.catalog[0], quantity: 5, context: context)
        XCTAssertNil(result)
        XCTAssertEqual(ledger.diamonds, 350)
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.activity.first?.giftContext, context)
        XCTAssertEqual(saved.activity.first?.giftID, "rose")
        XCTAssertEqual(saved.activity.first?.giftQuantity, 5)
        XCTAssertTrue(saved.isValid)
        await purchasing.stop()
        try await startService()
        XCTAssertEqual(ledger.diamonds, 350)
        XCTAssertEqual(ledger.activity.first?.giftContext, context)
        var legacy = WalletLedger.empty
        legacy.activity = [WalletActivity(id: "old-gift", title: "Sent Rose", currency: .diamonds,
            amount: 10, date: Date(), kind: "gift")]
        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(WalletLedger.self, from: data)
        XCTAssertTrue(decoded.isValid)
        XCTAssertNil(decoded.activity[0].giftContext)
    }

    func testVoiceMemberAndEveryoneKeepRecipientMetadataWithoutMultiplyingPrice() async throws {
        let purchased = try await buy("jezvdjvpoifednhy")
        XCTAssertNil(purchased)
        let room = MusicRoomCatalog.rooms[0]
        let recipients = room.participants.map { GiftRecipient(id: $0.id, name: $0.name) }
        var context = GiftContext(surface: .voiceRoom, sourceID: room.id, sourceTitle: room.title, recipients: [recipients[1]])
        let single = await purchasing.spend(MusicGift.catalog[0], quantity: 5, context: context)
        XCTAssertNil(single)
        XCTAssertEqual(ledger.diamonds, 350)
        XCTAssertEqual(ledger.activity.first?.giftContext?.recipients, [recipients[1]])
        context.recipients = recipients
        let everyone = await purchasing.spend(MusicGift.catalog[0], quantity: 5, context: context)
        XCTAssertNil(everyone)
        XCTAssertEqual(ledger.diamonds, 300)
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.activity.first?.giftContext?.recipients, recipients)
        XCTAssertEqual(saved.activity.first?.amount, 50)
    }

    func testGiftFailureInsufficientFundsAndInvalidTargetLeaveBalanceUnchanged() async throws {
        let purchased = try await buy("jezvdjvpoifednhy")
        XCTAssertNil(purchased)
        let valid = GiftContext(surface: .voiceRoom, sourceID: "hip-hop-crew", sourceTitle: "The Pop Lounge",
            recipients: [GiftRecipient(id: "dancer-0-0", name: "Maya")])
        let insufficient = await purchasing.spend(MusicGift.catalog.last!, quantity: 1, context: valid)
        XCTAssertNotNil(insufficient)
        var invalid = valid
        invalid.recipients = [GiftRecipient(id: "local-owner", name: "You")]
        let selfGift = await purchasing.spend(MusicGift.catalog[0], quantity: 1, context: invalid)
        XCTAssertNotNil(selfGift)
        purchasing.setPersist { _ in false }
        let failed = await purchasing.spend(MusicGift.catalog[0], quantity: 1, context: valid)
        XCTAssertNotNil(failed)
        XCTAssertEqual(ledger.diamonds, 400)
        XCTAssertEqual(ledger.activity.count, 1)
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 400)
        enablePersistence()
        await purchasing.stop()
        let afterLogout = await purchasing.spend(MusicGift.catalog[0], quantity: 1, context: valid)
        XCTAssertNotNil(afterLogout)
        XCTAssertEqual(ledger.diamonds, 400)
    }

    func testPurchaseCreditDuringGiftSaveKeepsBothChanges() async throws {
        let purchased = try await buy("jezvdjvpoifednhy")
        XCTAssertNil(purchased)
        let repository = repository!
        let saving = expectation(description: "Gift persistence has started")
        purchasing.setPersist { next in
            if next.activity.first?.kind == "gift" {
                saving.fulfill()
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            do { try await repository.saveWallet(next); return true }
            catch { return false }
        }
        let giftTask = Task { await purchasing.spend(MusicGift.catalog[0], quantity: 1) }
        await fulfillment(of: [saving], timeout: 5)
        let added = try await buy("uylrrniaqxjtlaie")
        XCTAssertNil(added)
        let giftResult = await giftTask.value
        XCTAssertNil(giftResult)
        try await eventually("Credit and gift both survive") { self.ledger.diamonds == 1190 }
        XCTAssertEqual(ledger.activity.count, 3)
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 1190)
    }

    func testPostAndVoiceEligibilityRejectsSelfBlockedAndMissingTargets() async throws {
        await purchasing.stop()
        let appRoot = root.appendingPathComponent("Eligibility")
        let store = AppStore(storageRoot: appRoot)
        await store.load()
        let entered = await store.acceptUserAgreement()
        XCTAssertTrue(entered)
        let post = LoungeState.editorialPosts[0]
        let target = GiftContext(surface: .post, sourceID: post.id.uuidString, sourceTitle: "Lounge post",
            recipients: [GiftRecipient(id: post.author.id, name: post.author.name)])
        XCTAssertNil(store.giftUnavailableReason(target))
        var own = LoungePost(author: .signedIn(store.library.profile), body: "My music")
        own.isDraft = false
        let saved = await store.saveLoungePost(own, asDraft: false)
        XCTAssertTrue(saved)
        let selfTarget = GiftContext(surface: .post, sourceID: own.id.uuidString, sourceTitle: "My post",
            recipients: [GiftRecipient(id: "local-owner", name: "You")])
        XCTAssertNotNil(store.giftUnavailableReason(selfTarget))
        let missing = GiftContext(surface: .post, sourceID: UUID().uuidString, sourceTitle: "Missing post", recipients: target.recipients)
        XCTAssertNotNil(store.giftUnavailableReason(missing))
        let room = MusicRoomCatalog.rooms[0]
        let member = room.participants[0]
        let voice = GiftContext(surface: .voiceRoom, sourceID: room.id, sourceTitle: room.title,
            recipients: [GiftRecipient(id: member.id, name: member.name)])
        XCTAssertNil(store.giftUnavailableReason(voice))
        let blocked = await store.blockCreator(post.author)
        XCTAssertTrue(blocked)
        XCTAssertNotNil(store.giftUnavailableReason(target))
        let exited = await store.logOut()
        XCTAssertTrue(exited)
        XCTAssertNotNil(store.giftUnavailableReason(voice))
    }

    func testAllNinePackagesCreditExactAmountsAndPersist() async throws {
        let expected: [(String, Int)] = [
            ("jezvdjvpoifednhy", 400), ("uylrrniaqxjtlaie", 800),
            ("oqojxyitbbjeayzj", 2450), ("skrseirtauvvrsol", 5150),
            ("bqrdrlkrlfpzjmod", 10800), ("qcrxcepelpjfskbi", 16800),
            ("psqtqagzmiiyhncr", 29400), ("fwcwwzfkbeawlbql", 42700),
            ("bzwmucutltusfxpv", 63700)
        ]
        var total = 0
        let expectedPrices = ["$0.99", "$1.99", "$4.99", "$9.99", "$19.99", "$29.99", "$49.99", "$69.99", "$99.99"]
        for (index, tier) in expected.enumerated() {
            let (id, amount) = tier
            XCTAssertEqual(prices[id], expectedPrices[index])
            let message = try await buy(id)
            XCTAssertNil(message, message ?? "")
            total += amount
            XCTAssertEqual(ledger.diamonds, total)
            XCTAssertEqual(ledger.activity.first?.amount, amount)
            let saved = try await repository.loadWallet()
            XCTAssertEqual(saved.diamonds, total)
            print("PAYMENT_PASS \(id) +\(amount), balance=\(total), price=\(prices[id] ?? "missing")")
        }
        XCTAssertEqual(ledger.diamonds, 172200)
        XCTAssertEqual(ledger.creditedTransactionIDs.count, 9)
        try await eventually("Fulfilled transactions are finished") { SKPaymentQueue.default().transactions.isEmpty }
        await purchasing.stop()
        try await startService()
        XCTAssertEqual(ledger.diamonds, 172200)
        XCTAssertEqual(ledger.activity.count, 9)
    }

    func testRepeatConsumablePurchasesCreditEachNewTransaction() async throws {
        let trace = PaymentTransactionTrace()
        SKPaymentQueue.default().add(trace)
        defer { SKPaymentQueue.default().remove(trace) }
        for index in 0..<3 {
            print("REPEAT_BEGIN \(index) balance=\(ledger.diamonds) queue=\(SKPaymentQueue.default().transactions.map { "\(ObjectIdentifier($0)):\($0.transactionIdentifier ?? "nil"):\($0.transactionState.rawValue)" })")
            let result = try await buy("jezvdjvpoifednhy")
            print("REPEAT_END \(index) result=\(result ?? "success") balance=\(ledger.diamonds)")
            XCTAssertNil(result)
        }
        XCTAssertEqual(ledger.diamonds, 1200)
        XCTAssertEqual(Set(ledger.creditedTransactionIDs).count, 3)
    }

    func testReusedLocalIdentifierCreditsNewPurchaseAndPreservesLegacyWallet() async throws {
        await purchasing.stop()
        let oldActivity = WalletActivity(id: "0", title: "Added 400 diamonds", currency: .diamonds,
                                        amount: 400, date: Date(timeIntervalSince1970: 1_793_353_313))
        let oldLedger = WalletLedger(diamonds: 400, activity: [oldActivity], creditedTransactionIDs: ["0"])
        try await repository.saveWallet(oldLedger)
        try await startService(owner: UUID())

        let result = try await buy("uylrrniaqxjtlaie")
        XCTAssertNil(result)
        XCTAssertEqual(session.allTransactions().first?.identifier, 0, "Reproduce Xcode's reused identifier")
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 1200, "A new 800-diamond transaction must not collide with the old ID 0")
        XCTAssertEqual(saved.activity.count, 2)
        let retained = try XCTUnwrap(saved.activity.first { $0.id == oldActivity.id })
        XCTAssertEqual(retained.title, oldActivity.title)
        XCTAssertEqual(retained.date, oldActivity.date)
        XCTAssertEqual(retained.amount, oldActivity.amount)
        XCTAssertTrue(saved.isValid)
    }

    func testLocalHistoryResetCreditsSameProductAgainAndSurvivesRelaunch() async throws {
        await purchasing.stop()
        let owner = UUID()
        try await startService(owner: owner)
        let first = try await buy("jezvdjvpoifednhy")
        XCTAssertNil(first)
        XCTAssertEqual(ledger.diamonds, 400)
        let firstID = try XCTUnwrap(session.allTransactions().first?.identifier)
        let firstActivity = try XCTUnwrap(ledger.activity.first)
        await purchasing.stop()
        // Keep the wallet on disk while only the Xcode history is reset, as in a manual Run after tests.
        session.clearTransactions()
        try await startService(owner: owner)
        let second = try await buy("jezvdjvpoifednhy")
        XCTAssertNil(second)
        XCTAssertEqual(session.allTransactions().first?.identifier, firstID)
        XCTAssertEqual(ledger.diamonds, 800)
        XCTAssertEqual(ledger.activity.count, 2)
        XCTAssertTrue(ledger.activity.contains { $0.id == firstActivity.id && $0.date == firstActivity.date })
        await purchasing.stop()
        try await startService(owner: owner)
        XCTAssertEqual(ledger.diamonds, 800)
        XCTAssertEqual(ledger.activity.count, 2)
        XCTAssertEqual(ledger.localStoreKitCredits?.count, 2)
    }

    func testLegacyLocalReplayMigratesWithoutCreditAndDeduplicationOutlivesVisibleHistory() async throws {
        await purchasing.stop()
        let owner = UUID()
        try await startService(owner: owner)
        purchasing.setPersist { _ in false }
        let failedSave = try await buy("jezvdjvpoifednhy")
        XCTAssertNotNil(failedSave)
        let transaction = try XCTUnwrap(SKPaymentQueue.default().transactions.first { $0.transactionState == .purchased })
        let id = try XCTUnwrap(transaction.transactionIdentifier)
        let date = try XCTUnwrap(transaction.transactionDate)
        await purchasing.stop()
        let oldLedger = WalletLedger(diamonds: 400,
            activity: [WalletActivity(id: id, title: "Added 400 diamonds", currency: .diamonds, amount: 400, date: date)],
            creditedTransactionIDs: [id])
        try await repository.saveWallet(oldLedger)
        try await startService(owner: owner)
        try await eventually("A replay of the credited legacy purchase is finished") { SKPaymentQueue.default().transactions.isEmpty }
        var saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 400)
        XCTAssertEqual(saved.activity.first?.id, id)
        XCTAssertEqual(saved.localStoreKitCredits?.count, 1)

        // Simulate the existing visible-history limit while keeping durable delivery metadata.
        await purchasing.stop()
        saved.activity = []
        try await repository.saveWallet(saved)
        try await startService(owner: owner)
        let replayed = expectation(description: "Replay checks the migrated durable identity")
        let repository = repository!
        purchasing.setPersist { ledger in
            try? await repository.saveWallet(ledger)
            replayed.fulfill()
            return true
        }
        purchasing.paymentQueue(.default(), updatedTransactions: [transaction])
        await fulfillment(of: [replayed], timeout: 10)
        saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 400)
        XCTAssertTrue(saved.activity.isEmpty)
        XCTAssertEqual(saved.localStoreKitCredits?.count, 1)
    }

    func testLocalCollisionSaveFailureRetriesExactlyOnce() async throws {
        await purchasing.stop()
        let owner = UUID()
        let oldLedger = WalletLedger(diamonds: 400,
            activity: [WalletActivity(id: "0", title: "Added 400 diamonds", currency: .diamonds,
                                      amount: 400, date: Date(timeIntervalSince1970: 1_793_353_313))],
            creditedTransactionIDs: ["0"])
        try await repository.saveWallet(oldLedger)
        try await startService(owner: owner)
        purchasing.setPersist { _ in false }
        let failed = try await buy("uylrrniaqxjtlaie")
        XCTAssertNotNil(failed)
        XCTAssertEqual(ledger.diamonds, 400)
        let failedLedger = try await repository.loadWallet()
        XCTAssertNil(failedLedger.localStoreKitCredits)
        let transaction = try XCTUnwrap(SKPaymentQueue.default().transactions.first { $0.transactionState == .purchased })
        await purchasing.stop()
        try await startService(owner: owner)
        try await eventually("The failed local credit is retried") { self.ledger.diamonds == 1200 }
        try await eventually("Recovered local purchase is finished") { SKPaymentQueue.default().transactions.isEmpty }
        await purchasing.stop()
        try await startService(owner: owner)
        let replayed = expectation(description: "Recovered local credit is not delivered twice")
        let repository = repository!
        purchasing.setPersist { ledger in
            try? await repository.saveWallet(ledger)
            replayed.fulfill()
            return true
        }
        purchasing.paymentQueue(.default(), updatedTransactions: [transaction])
        await fulfillment(of: [replayed], timeout: 10)
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 1200)
        XCTAssertEqual(saved.activity.count, 2)
        XCTAssertEqual(saved.localStoreKitCredits?.count, 2)
    }

    func testUnresolvableLegacyLocalIDStaysUnfinishedWithoutFalseSuccess() async throws {
        await purchasing.stop()
        // The old credited ID survived, but its visible activity was already pruned by an earlier build.
        try await repository.saveWallet(WalletLedger(diamonds: 400, activity: [], creditedTransactionIDs: ["0"]))
        try await startService(owner: UUID())
        let result = try await buy("uylrrniaqxjtlaie")
        XCTAssertNotNil(result)
        XCTAssertTrue(purchasing.hasUnfinishedTransactions)
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 400)
        XCTAssertTrue(saved.activity.isEmpty)
    }

    @available(iOS 17.0, *)
    func testCancellationDoesNotCreditAndNextPurchaseSucceeds() async throws {
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let canceled = try await buy("jezvdjvpoifednhy")
        XCTAssertEqual(canceled, "Purchase canceled. You have not been charged.")
        XCTAssertEqual(ledger.diamonds, 0)
        XCTAssertTrue(ledger.creditedTransactionIDs.isEmpty)
        // Reset the local server after the injected failure; clearing only its error value
        // leaves an empty failure payload on the iOS 26 StoreKit 1 test server.
        session.resetToDefaultState()
        session.disableDialogs = true
        let result = try await buy("jezvdjvpoifednhy")
        XCTAssertNil(result)
        XCTAssertEqual(ledger.diamonds, 400)
    }

    @available(iOS 17.0, *)
    func testPaymentFailureDoesNotCredit() async throws {
        try await session.setSimulatedError(.generic(.systemError(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))), forAPI: .purchase)
        let message = try await buy("uylrrniaqxjtlaie")
        XCTAssertNotNil(message)
        XCTAssertEqual(ledger.diamonds, 0)
        XCTAssertTrue(ledger.activity.isEmpty)
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 0)
    }

    func testAskToBuyCreditsOnlyAfterApproval() async throws {
        session.askToBuyEnabled = true
        let pending = try await buy("uylrrniaqxjtlaie")
        XCTAssertEqual(pending, "This purchase is waiting for approval. Diamonds are added when it is approved.")
        XCTAssertEqual(ledger.diamonds, 0)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        try await eventually("Approved purchase adds 800 diamonds") { self.ledger.diamonds == 800 }
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 800)
    }

    func testFailedSaveRecoversOnObserverRestartAndDuplicateDoesNotCreditTwice() async throws {
        purchasing.setPersist { _ in false }
        let failedSave = try await buy("jezvdjvpoifednhy")
        XCTAssertTrue(failedSave?.contains("could not be saved") == true)
        XCTAssertEqual(ledger.diamonds, 0)
        let transaction = try XCTUnwrap(SKPaymentQueue.default().transactions.first { $0.transactionState == .purchased })
        let beforeRecovery = try await repository.loadWallet()
        XCTAssertEqual(beforeRecovery.diamonds, 0)
        await purchasing.stop()
        try await startService()
        try await eventually("Unfinished purchase is recovered") { self.ledger.diamonds == 400 }
        try await eventually("Recovered transaction is finished") { SKPaymentQueue.default().transactions.isEmpty }
        await purchasing.stop()
        try await startService()
        // Replay the actual StoreKit transaction into a fresh observer, exercising persisted ID deduplication.
        let duplicateHandled = expectation(description: "Duplicate transaction checks the saved ledger")
        let repository = repository!
        purchasing.setPersist { ledger in
            do {
                try await repository.saveWallet(ledger)
                duplicateHandled.fulfill()
                return true
            } catch { return false }
        }
        purchasing.paymentQueue(.default(), updatedTransactions: [transaction])
        await fulfillment(of: [duplicateHandled], timeout: 10)
        let saved = try await repository.loadWallet()
        XCTAssertEqual(saved.diamonds, 400)
        XCTAssertEqual(saved.creditedTransactionIDs.count, 1)
        XCTAssertEqual(saved.activity.count, 1)
    }

    func testPartialCatalogRetryAndStaleCallbackCannotReplaceNewRequest() async throws {
        let response = try await CatalogProbe().fetch(WalletCatalog.productIDs)
        let product = try XCTUnwrap(response.products.first { $0.productIdentifier == "jezvdjvpoifednhy" })
        await purchasing.stop()
        let fetcher = ControlledProductFetcher()
        try await startService(fetcher: fetcher, waitForCatalog: false)
        purchasing.retryProducts()
        XCTAssertEqual(fetcher.callbacks.count, 1, "Concurrent loads are coalesced")
        fetcher.deliver(0, .success(.init(products: [product], invalidProductIDs: Array(WalletCatalog.productIDs.subtracting([product.productIdentifier])))))
        XCTAssertEqual(purchasing.catalog.phase, .partial)
        XCTAssertEqual(prices, ["jezvdjvpoifednhy": "$0.99"])
        purchasing.retryProducts()
        fetcher.deliver(1, .failure(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)))
        XCTAssertEqual(purchasing.catalog.phase, .failed)
        XCTAssertEqual(prices.count, 1, "Valid offers survive a failed refresh")
        purchasing.retryProducts()
        fetcher.deliver(1, .success(.init(products: [], invalidProductIDs: Array(WalletCatalog.productIDs))))
        XCTAssertEqual(purchasing.catalog.phase, .loading, "Old callback must not end the new request")
        fetcher.deliver(2, .success(.init(products: response.products, invalidProductIDs: [])))
        XCTAssertEqual(purchasing.catalog.phase, .ready)
        XCTAssertEqual(prices.count, 9)
    }

    func testTimeoutCancelsRequestAndLateResultCannotReplaceRetry() async throws {
        let response = try await CatalogProbe().fetch(WalletCatalog.productIDs)
        await purchasing.stop()
        let fetcher = ControlledProductFetcher()
        try await startService(fetcher: fetcher, timeout: 0.15, waitForCatalog: false)
        try await eventually("Request reaches the explicit timeout state") { self.purchasing.catalog.phase == .timedOut }
        XCTAssertEqual(fetcher.cancelCount, 1)
        purchasing.retryProducts()
        fetcher.deliver(0, .success(.init(products: response.products, invalidProductIDs: [])))
        XCTAssertEqual(purchasing.catalog.phase, .loading)
        XCTAssertTrue(prices.isEmpty)
        fetcher.deliver(1, .success(.init(products: response.products, invalidProductIDs: [])))
        XCTAssertEqual(purchasing.catalog.phase, .ready)
    }

    func testSessionEndWhileLoadingPreventsDelayedPurchase() async throws {
        let response = try await CatalogProbe().fetch(WalletCatalog.productIDs)
        await purchasing.stop()
        let fetcher = ControlledProductFetcher()
        try await startService(fetcher: fetcher, waitForCatalog: false)
        let completed = expectation(description: "Session end releases pending purchase")
        var result: String?
        Task { @MainActor in
            result = await purchasing.purchase(WalletCatalog.package(forProductID: "jezvdjvpoifednhy")!)
            completed.fulfill()
        }
        await Task.yield()
        await purchasing.stop()
        fetcher.deliver(0, .success(.init(products: response.products, invalidProductIDs: [])))
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertTrue(result?.contains("wallet was closed") == true)
        XCTAssertTrue(session.allTransactions().isEmpty)
        XCTAssertEqual(ledger.diamonds, 0)
        XCTAssertEqual(purchasing.catalog.phase, .idle)
    }

    func testEmptyCatalogAndSanitizedErrorDiagnostics() async throws {
        await purchasing.stop()
        let fetcher = ControlledProductFetcher()
        try await startService(fetcher: fetcher, waitForCatalog: false)
        fetcher.deliver(0, .success(.init(products: [], invalidProductIDs: Array(WalletCatalog.productIDs))))
        XCTAssertEqual(purchasing.catalog.phase, .unavailable)
        XCTAssertTrue(prices.isEmpty)
        XCTAssertEqual(purchasing.catalog.invalidIDs.count, 9)
        purchasing.retryProducts()
        fetcher.deliver(1, .failure(NSError(domain: "CatalogTest", code: 42, userInfo: [NSLocalizedDescriptionKey: "secret receipt", "receipt-data": "private"])))
        XCTAssertEqual(purchasing.catalog.phase, .failed)
        XCTAssertTrue(purchasing.diagnostics.contains("CatalogTest(42)"))
        XCTAssertFalse(purchasing.diagnostics.contains("secret"))
        XCTAssertFalse(purchasing.diagnostics.contains("private"))
    }
}

@MainActor
private final class ControlledProductFetcher: StoreProductFetching {
    var callbacks: [(Result<StoreProductResponse, Error>) -> Void] = []
    var cancelCount = 0
    func start(_ identifiers: Set<String>, completion: @escaping (Result<StoreProductResponse, Error>) -> Void) {
        callbacks.append(completion)
    }
    func cancel() { cancelCount += 1 }
    // Deliberately retains callbacks after cancel to reproduce late StoreKit delivery.
    func deliver(_ index: Int, _ result: Result<StoreProductResponse, Error>) { callbacks[index](result) }
}

private enum PaymentTestError: Error { case timeout }

private final class PaymentTransactionTrace: NSObject, SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            print("PAYMENT_REMOVED object=\(ObjectIdentifier(transaction)) id=\(transaction.transactionIdentifier ?? "nil")")
        }
    }
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            print("PAYMENT_TRACE object=\(ObjectIdentifier(transaction)) id=\(transaction.transactionIdentifier ?? "nil") state=\(transaction.transactionState.rawValue)")
        }
    }
}

/// Stops the normal app observer before a test owns the queue. Uses existing controller APIs only.
@MainActor
private func stopHostPayments() async throws {
    let deadline = Date().addingTimeInterval(20)
    while Date() < deadline {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        if let navigation = windows.first(where: { $0.isKeyWindow })?.rootViewController as? UINavigationController,
           let screen = navigation.viewControllers.first as? TotiScreen {
            await screen.store.wallet.stopPayments()
            return
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    throw PaymentTestError.timeout
}

@MainActor
final class CatalogAvailabilityTests: XCTestCase {
    func testAppleCatalogWithoutLocalStoreKitConfiguration() async throws {
        try await stopHostPayments()
        let probe = CatalogProbe()
        let response = try await probe.fetch(WalletCatalog.productIDs)
        let detail = "APPLE_CATALOG loaded=\(response.products.map(\.productIdentifier).sorted()), invalid=\(response.invalidProductIdentifiers.sorted())"
        print(detail)
        let attachment = XCTAttachment(string: detail)
        attachment.lifetime = .keepAlways
        add(attachment)
        guard response.products.count == 9 else {
            throw XCTSkip("Apple did not return all nine products. See catalog attachment; this is not a sandbox purchase pass.")
        }
    }
}

@MainActor
private final class CatalogProbe: NSObject, SKProductsRequestDelegate {
    private var request: SKProductsRequest?
    private var continuation: CheckedContinuation<SKProductsResponse, Error>?

    func fetch(_ identifiers: Set<String>) async throws -> SKProductsResponse {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = SKProductsRequest(productIdentifiers: identifiers)
            self.request = request
            request.delegate = self
            request.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
                guard let self, let continuation = self.continuation else { return }
                self.continuation = nil
                self.request?.cancel()
                continuation.resume(throwing: XCTSkip("Apple catalog request timed out without a local StoreKit configuration."))
            }
        }
    }
    nonisolated func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        Task { @MainActor in
            self.continuation?.resume(returning: response)
            self.continuation = nil
        }
    }
    nonisolated func request(_ request: SKRequest, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: XCTSkip("Apple catalog unavailable: \(error)"))
            self.continuation = nil
        }
    }
}
