//
//  CouponNotificationScheduler.swift
//  GrocartInc-IOS
//

import UserNotifications

enum CouponNotificationScheduler {

    private static let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    static func requestPermissionIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Schedule

    /// Schedules a local notification for every locked coupon whose unlock date is in the future.
    /// Safe to call repeatedly — uses "scratch-\(id)" as the identifier so duplicates are replaced.
    static func scheduleUnlockNotifications(for promoCodes: [PromoCode]) async {
        await requestPermissionIfNeeded()

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else { return }

        let dateParser = makeDateParser()

        for code in promoCodes {
            guard let rawDate = code.activeFrom,
                  let unlockDate = dateParser(rawDate),
                  unlockDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "🎁 Your scratch card is ready!"
            content.body = "Your mystery reward is now unlocked. Open My Coupons to reveal it!"
            content.sound = .default

            // Fire at 10:00 AM on the unlock date
            var components = Calendar.current.dateComponents(
                [.year, .month, .day], from: unlockDate
            )
            components.hour = 10
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "scratch-\(code.id)",
                content: content,
                trigger: trigger
            )

            // addNotificationRequest replaces any existing request with the same identifier
            try? await center.add(request)
        }
    }

    // MARK: - Cancel

    /// Removes pending notifications for coupons that are now unlocked (no longer need a reminder).
    static func cancelUnlockNotifications(for promoCodes: [PromoCode]) {
        let ids = promoCodes.compactMap { code -> String? in
            guard let rawDate = code.activeFrom else { return nil }
            let parser = makeDateParser()
            guard let unlockDate = parser(rawDate), unlockDate <= Date() else { return nil }
            return "scratch-\(code.id)"
        }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Helpers

    private static func makeDateParser() -> (String) -> Date? {
        let iso = ISO8601DateFormatter()
        let plain = DateFormatter()
        plain.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        plain.locale = Locale(identifier: "en_US_POSIX")
        return { raw in iso.date(from: raw) ?? plain.date(from: raw) }
    }
}
