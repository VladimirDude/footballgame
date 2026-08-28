import Foundation
import UserNotifications
import UIKit
import Combine

/// Local daily reminder to play the Daily Challenge.
///
/// Schedules a rolling week of one-shot notifications (not a single fire) so
/// reminders keep coming even if the user doesn't open the app every day.
/// Completing today's challenge pushes the next fire to tomorrow.
@MainActor
final class DailyReminderService: ObservableObject {
    static let shared = DailyReminderService()

    static let enabledKey = "dailyReminderEnabled"
    static let hourKey = "dailyReminderHour"
    static let minuteKey = "dailyReminderMinute"

    static let defaultHour = 19
    static let defaultMinute = 0

    /// How many upcoming days to keep scheduled so reminders survive without opening the app.
    private let scheduleHorizonDays = 7
    private let notificationIDPrefix = "ftmp.dailyChallenge.reminder."
    private let center = UNUserNotificationCenter.current()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// Last scheduling error (for Settings footer / debugging).
    @Published private(set) var lastScheduleError: String?

    private init() {
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Preference helpers

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    var hour: Int {
        if UserDefaults.standard.object(forKey: Self.hourKey) == nil { return Self.defaultHour }
        return UserDefaults.standard.integer(forKey: Self.hourKey)
    }

    var minute: Int {
        if UserDefaults.standard.object(forKey: Self.minuteKey) == nil { return Self.defaultMinute }
        return UserDefaults.standard.integer(forKey: Self.minuteKey)
    }

    /// Binding-friendly time as today's date at the reminder clock.
    var reminderTime: Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    func setReminderTime(_ date: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        UserDefaults.standard.set(parts.hour ?? Self.defaultHour, forKey: Self.hourKey)
        UserDefaults.standard.set(parts.minute ?? Self.defaultMinute, forKey: Self.minuteKey)
    }

    // MARK: - Authorization

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// System denied — user must flip it in Settings.
    var needsOpenSettings: Bool {
        authorizationStatus == .denied
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Requests permission. Returns `true` when notifications can be scheduled.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted && isAuthorized
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Scheduling

    /// Turn reminders on/off. When enabling, requests permission if needed.
    /// Returns whether reminders are active afterward.
    @discardableResult
    func setEnabled(_ enabled: Bool, completedToday: Bool) async -> Bool {
        if !enabled {
            UserDefaults.standard.set(false, forKey: Self.enabledKey)
            await cancelPending()
            lastScheduleError = nil
            return false
        }

        await refreshAuthorizationStatus()
        if !isAuthorized {
            let granted = await requestAuthorization()
            if !granted {
                UserDefaults.standard.set(false, forKey: Self.enabledKey)
                await cancelPending()
                return false
            }
        }

        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        await reschedule(completedToday: completedToday)
        return isEnabled && lastScheduleError == nil
    }

    func reschedule(completedToday: Bool) async {
        await cancelPending()
        guard isEnabled else { return }
        await refreshAuthorizationStatus()
        guard isAuthorized else {
            lastScheduleError = "Notifications are not allowed."
            return
        }

        let fireDates = upcomingFireDates(completedToday: completedToday)
        guard !fireDates.isEmpty else {
            lastScheduleError = "Could not compute a reminder time."
            return
        }

        var scheduled = 0
        var firstError: String?
        for (index, fireDate) in fireDates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Daily Challenge"
            content.body = "Don't forget today's challenge. Keep your streak going."
            content.sound = .default

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(notificationIDPrefix)\(index)",
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduled += 1
            } catch {
                if firstError == nil {
                    firstError = error.localizedDescription
                }
            }
        }

        lastScheduleError = scheduled == 0 ? (firstError ?? "Failed to schedule reminders.") : nil
    }

    func cancelPending() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(notificationIDPrefix) || $0 == "ftmp.dailyChallenge.reminder" }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Pending reminder count (for sanity checks in Settings).
    func pendingReminderCount() async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.filter {
            $0.identifier.hasPrefix(notificationIDPrefix) || $0.identifier == "ftmp.dailyChallenge.reminder"
        }.count
    }

    /// Next fire times over the schedule horizon (always `scheduleHorizonDays` slots).
    /// Exposed for tests (`@testable import`).
    func upcomingFireDates(completedToday: Bool, now: Date = Date()) -> [Date] {
        let cal = Calendar.current
        guard let todayAt = cal.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: now
        ) else { return [] }

        var dates: [Date] = []
        var dayOffset = 0
        while dates.count < scheduleHorizonDays {
            defer { dayOffset += 1 }
            guard let fire = cal.date(byAdding: .day, value: dayOffset, to: todayAt) else { continue }
            if dayOffset == 0, (completedToday || fire <= now) { continue }
            if fire <= now { continue }
            dates.append(fire)
            if dayOffset > 40 { break } // safety
        }
        return dates
    }
}

// MARK: - App delegate (foreground banners + center delegate)

/// Required so reminders can appear while FTMP is open, and so the notification
/// center has a delegate for delivery.
final class FTMPAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        UserDefaults.standard.set(true, forKey: OnboardingStorage.openDailyAfterOnboardingKey)
        completionHandler()
    }
}
