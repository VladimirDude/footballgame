import XCTest
import UserNotifications
@testable import test

final class DailyReminderTests: XCTestCase {

    @MainActor
    func testHorizonAlwaysSevenWhenTodayAlreadyPassed() {
        let service = DailyReminderService.shared
        // Freeze "now" to 20:00 so today's 19:00 slot is already past.
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 20
        comps.minute = 0
        let now = Calendar.current.date(from: comps)!

        UserDefaults.standard.set(19, forKey: DailyReminderService.hourKey)
        UserDefaults.standard.set(0, forKey: DailyReminderService.minuteKey)

        let dates = service.upcomingFireDates(completedToday: false, now: now)
        XCTAssertEqual(dates.count, 7, "Should still schedule a full week when today's slot is past")
        XCTAssertTrue(dates.allSatisfy { $0 > now })
        // First fire should be tomorrow 19:00
        let first = dates[0]
        XCTAssertEqual(Calendar.current.component(.hour, from: first), 19)
        XCTAssertEqual(Calendar.current.component(.minute, from: first), 0)
    }

    @MainActor
    func testHorizonSevenWhenCompletedToday() {
        let service = DailyReminderService.shared
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 10
        comps.minute = 0
        let now = Calendar.current.date(from: comps)!

        UserDefaults.standard.set(19, forKey: DailyReminderService.hourKey)
        UserDefaults.standard.set(0, forKey: DailyReminderService.minuteKey)

        let dates = service.upcomingFireDates(completedToday: true, now: now)
        XCTAssertEqual(dates.count, 7)
        // Must not include today even though 19:00 is still ahead.
        XCTAssertFalse(Calendar.current.isDate(dates[0], inSameDayAs: now))
    }

    @MainActor
    func testTrySchedulePendingNotificationsOnSimulator() async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        // Can't grant the system prompt from this agent — skip if denied/notDetermined without grant.
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else {
            throw XCTSkip("Simulator notification permission not granted — enable once in Settings to exercise this path")
        }

        let service = DailyReminderService.shared
        await service.setEnabled(true, completedToday: false)
        let pending = await center.pendingNotificationRequests()
        let ours = pending.filter { $0.identifier.hasPrefix("ftmp.dailyChallenge.reminder.") }
        XCTAssertEqual(ours.count, 7, "Authorized device should have 7 pending Daily reminder requests")
        await service.setEnabled(false, completedToday: false)
    }
}
