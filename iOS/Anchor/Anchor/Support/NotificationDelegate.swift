//
//  NotificationDelegate.swift
//  Anchor
//
//  The only place that reacts to a person tapping a notification action.
//  "I'm okay" and opening the app both count as a response and cancel any
//  pending escalation reminder — escalation only fires from silence, never
//  from an explicit check-in.
//

import Foundation
import UserNotifications
import SwiftUI

struct ContactMessagePrompt: Identifiable {
    let id = UUID()
    let name: String
    let phoneNumber: String
}

@MainActor
final class NotificationDelegate: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Set when the user taps "Message a contact" from a notification;
    /// ContentView observes this to present the message composer.
    @Published var contactMessagePrompt: ContactMessagePrompt?

    /// Set when the daily check-in notification (or its "Check in now"
    /// action, or just tapping the notification itself) is opened.
    /// ContentView observes this to switch to Now and open the check-in
    /// sheet, then resets it back to false.
    @Published var shouldOpenCheckIn = false

    /// Set when a trigger-window/escalation notification arrives while the
    /// app is in the foreground, so it still shows as a banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "IM_OKAY", UNNotificationDefaultActionIdentifier, "OPEN":
            if let escalationIDs = userInfo["escalationIdentifiers"] as? [String] {
                NotificationScheduler.cancelEscalations(identifiers: escalationIDs)
            }
            if response.notification.request.content.categoryIdentifier == NotificationCategory.dailyCheckIn.rawValue {
                shouldOpenCheckIn = true
            }
        case "CHECKIN_NOW":
            shouldOpenCheckIn = true
        case "CONTACT":
            if let escalationIDs = userInfo["escalationIdentifiers"] as? [String] {
                NotificationScheduler.cancelEscalations(identifiers: escalationIDs)
            }
            let name = userInfo["contactName"] as? String ?? ""
            let phone = userInfo["contactPhone"] as? String ?? ""
            if !phone.isEmpty {
                contactMessagePrompt = ContactMessagePrompt(name: name, phoneNumber: phone)
            }
        default:
            break
        }
    }
}
