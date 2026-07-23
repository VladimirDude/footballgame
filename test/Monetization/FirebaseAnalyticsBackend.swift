//  Firebase implementation of `AnalyticsBackend`.
//  Guarded so the app builds with or without the Firebase SDK. Registered at
//  launch in `testApp` once `FirebaseApp.configure()` has run.

#if canImport(FirebaseAnalytics)
import Foundation
import FirebaseAnalytics

final class FirebaseAnalyticsBackend: AnalyticsBackend {
    func log(name: String, parameters: [String: Any]) {
        Analytics.logEvent(name, parameters: parameters)
    }

    func setUserProperty(_ value: String?, for key: String) {
        Analytics.setUserProperty(value, forName: key)
    }
}
#endif
