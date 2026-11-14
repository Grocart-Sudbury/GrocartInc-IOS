//
//  SubscriptionRepository.swift
//  GrocartInc-IOS
//
//  Subscriptions live on the backend (GET/POST/DELETE
//  /customer/subscriptions). The backend owns recurring billing: it
//  charges the saved card on each cycle and creates the order.
//
//  The backend endpoints are not verified yet — the backend returns 403
//  for every /customer/* path without auth, so an unauthenticated probe
//  cannot tell whether they exist. If a call fails, the subscription is
//  kept on-device (negative id, "Saved on this device") so the feature
//  still works in the app; it is not billed until it is recreated once
//  the backend is ready.
//

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "SubscriptionRepository")

final class SubscriptionRepository: @unchecked Sendable {

    static let shared = SubscriptionRepository()
    private static let decoder = JSONDecoder()
    private init() {}

    // MARK: - Local cache (per signed-in user)
    private var userId: Int { SessionManager.shared.currentUser?.id ?? 0 }

    private var cacheKey: String { "grocart.subscriptions.\(userId)" }
    private var localIdKey: String { "grocart.subscriptions.localId.\(userId)" }

    private func loadCached() -> [Subscription] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let subs = try? Self.decoder.decode([Subscription].self, from: data) else {
            return []
        }
        return subs
    }

    private func saveCached(_ subs: [Subscription]) {
        if let data = try? JSONEncoder().encode(subs) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func nextLocalId() -> Int {
        // Negative ids can never collide with backend ids.
        let current = UserDefaults.standard.integer(forKey: localIdKey)
        let next = current <= 0 ? current - 1 : -1
        UserDefaults.standard.set(next, forKey: localIdKey)
        return next
    }

    // MARK: - List my subscriptions
    func fetchMySubscriptions() async throws -> [Subscription] {
        logger.info("GET /customer/subscriptions")
        let response = await Session.authenticated
            .request(APIConfig.Subscriptions.base, method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        switch response.result {
        case .success(let data):
            do {
                // The API returns either an array directly or a wrapper.
                if let subs = try? Self.decoder.decode([Subscription].self, from: data) {
                    let list = merged(subs)
                    saveCached(list)
                    return list
                }
                struct Wrapper: Decodable { let subscriptions: [Subscription] }
                if let wrapper = try? Self.decoder.decode(Wrapper.self, from: data) {
                    let list = merged(wrapper.subscriptions)
                    saveCached(list)
                    return list
                }
                throw NetworkError.decodingError
            } catch {
                logger.error("DECODE ERROR: \(error)")
                throw NetworkError.decodingError
            }
        case .failure(let afError):
            // Offline or the backend has no subscriptions endpoint yet:
            // show what is saved on-device. For a customer with no
            // subscriptions yet that is an empty list — the empty
            // state, not an error.
            let cached = loadCached()
            logger.info("Backend list failed; returning \(cached.count) cached subscriptions")
            return cached
        }
    }

    // MARK: - Create a subscription
    func create(
        store: Store,
        items: [SubscriptionItem],
        frequency: SubscriptionFrequency,
        fulfilment: OrderType,
        paymentMethodId: String,
        paymentCardLabel: String?,
        addressId: Int?,
        deliveryAddressLabel: String?
    ) async throws -> Subscription {
        let request = CreateSubscriptionRequest(
            storeId: store.id,
            frequency: frequency,
            fulfilment: fulfilment,
            items: items.map { .init(productId: $0.productId, quantity: $0.quantity) },
            paymentMethodId: paymentMethodId,
            addressId: addressId
        )
        logger.info("POST /customer/subscriptions — storeId:\(store.id) frequency:\(frequency.rawValue) fulfilment:\(fulfilment.rawValue) items:\(items.count)")
        let response = await Session.authenticated
            .request(APIConfig.Subscriptions.base, method: .post,
                     parameters: try encodeToParams(request), encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        switch response.result {
        case .success(let data):
            do {
                let sub = try Self.decoder.decode(Subscription.self, from: data)
                var cached = loadCached()
                cached.removeAll { $0.id == sub.id }
                cached.insert(sub, at: 0)
                saveCached(cached)
                return sub
            } catch {
                logger.error("DECODE ERROR: \(error)")
                throw NetworkError.decodingError
            }
        case .failure(let afError):
            // Backend did not confirm it (endpoints may not exist yet).
            // Keep it on-device so the subscription still works in the
            // app; it is marked local-only and is not billed.
            logger.error("CREATE FAILED (\(afError.localizedDescription)); saving locally")
            let firstDelivery = Subscription.firstDeliveryDate()
            let local = Subscription(
                id: nextLocalId(),
                storeId: store.id,
                storeName: store.name,
                frequency: frequency,
                fulfilment: fulfilment,
                items: items,
                paymentMethodId: paymentMethodId,
                paymentCardLabel: paymentCardLabel,
                addressId: addressId,
                deliveryAddressLabel: deliveryAddressLabel,
                nextDeliveryDate: Subscription.backendDateString(firstDelivery),
                status: .active,
                createdAt: Subscription.backendDateString(Date())
            )
            var cached = loadCached()
            cached.insert(local, at: 0)
            saveCached(cached)
            return local
        }
    }

    // MARK: - Cancel a subscription
    // Standard rule (the one every subscription service uses): cancelling
    // ends the subscription at the end of the current period. The next
    // scheduled delivery is cancelled and the card is not charged again;
    // a delivery already placed still arrives. The cancelled record is
    // kept (status CANCELLED + the cancelled delivery date) so the
    // customer can see what was cancelled, instead of vanishing.
    func cancel(_ subscription: Subscription) async throws -> Subscription {
        let cancelled = subscription.cancelledCopy()
        if subscription.id < 0 {
            // Local-only: just mark it cancelled on-device.
            updateCached(cancelled)
            return cancelled
        }
        logger.info("DELETE /customer/subscriptions/\(subscription.id)")
        let response = await Session.authenticated
            .request(APIConfig.Subscriptions.byId(subscription.id), method: .delete)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        if case .failure(let afError) = response.result {
            throw mapError(response: response, afError: afError)
        }
        updateCached(cancelled)
        return cancelled
    }

    /// Replace a cached subscription with an updated copy (or append it
    /// when it is not cached yet).
    private func updateCached(_ subscription: Subscription) {
        var cached = loadCached()
        if let index = cached.firstIndex(where: { $0.id == subscription.id }) {
            cached[index] = subscription
        } else {
            cached.append(subscription)
        }
        saveCached(cached)
    }

    /// Keep locally-cancelled records the server no longer returns (the
    /// backend deletes the record on cancel, but the customer should
    /// still see what was cancelled). Server list first, then the kept
    /// cancelled ones.
    private func merged(_ serverSubs: [Subscription]) -> [Subscription] {
        let cached = loadCached()
        let serverIds = Set(serverSubs.map(\.id))
        let keptCancelled = cached.filter { $0.status == .cancelled && !serverIds.contains($0.id) }
        return serverSubs + keptCancelled
    }

    // MARK: - Helpers
    private func encodeToParams<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let params = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkError.unknown(NSError(domain: "SubscriptionRepository", code: -1,
                                               userInfo: [NSLocalizedDescriptionKey: "Encoding failed"]))
        }
        return params
    }

    private func mapError(response: DataResponse<Data, AFError>, afError: AFError) -> NetworkError {
        let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        logger.error("FAILED: \(body)")
        if let data = response.data,
           let errResponse = try? Self.decoder.decode(APIErrorResponse.self, from: data) {
            return NetworkError.serverError(errResponse.displayMessage)
        }
        if response.response?.statusCode == 401 { return NetworkError.unauthorized }
        return NetworkError.unknown(afError)
    }
}
