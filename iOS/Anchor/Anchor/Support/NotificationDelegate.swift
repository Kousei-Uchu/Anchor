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

/// Set when a session reminder is opened, so Session prep opens for that provider.
struct SessionPrepRequest: Identifiable {
    let id = UUID()
    let providerID: UUID?
}

/// Set when a hello reminder is opened, so the message box opens for that person.
struct HelloRequest: Identifiable {
    let id = UUID()
    let contactID: UUID
}

/// What a trigger window reminder shows once it is opened. The lock screen never carries these;
/// they travel inside the reminder and are read here.
struct WindowReminderPrompt: Identifiable {
    let id = UUID()
    let label: String
    let line: String?
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

    /// Set when a trigger window reminder is opened, so the window's label and a line from the
    /// safety plan show inside the app instead of on the lock screen.
    @Published var windowReminder: WindowReminderPrompt?

    /// Set when a session reminder is opened. ContentView shows Session prep for the provider
    /// the session is with, which is carried inside the reminder and never on the lock screen.
    @Published var sessionPrep: SessionPrepRequest?

    /// Set when a hello reminder is opened. ContentView opens the message box for that person,
    /// who is carried inside the reminder and never on the lock screen.
    @Published var hello: HelloRequest?

    /// Set when a trigger-window/escalation notification arrives while the
    /// app is in the foreground, so it still shows as a banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // The focus timer's alert only makes a sound if that is switched on.
        if notification.request.identifier == PomodoroTimer.alertIdentifier {
            return PomodoroSettings.soundOn ? [.banner, .sound] : [.banner]
        }
        return [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "IM_OKAY", UNNotificationDefaultActionIdentifier, "OPEN":
            cancelFollowUps(userInfo: userInfo, firedAt: response.notification.date)
            if response.actionIdentifier != "IM_OKAY",
               response.notification.request.content.categoryIdentifier == NotificationCategory.triggerWindow.rawValue,
               let label = userInfo["windowLabel"] as? String, !label.isEmpty {
                windowReminder = WindowReminderPrompt(label: label, line: userInfo["line"] as? String)
            }
            if response.actionIdentifier != "IM_OKAY",
               response.notification.request.content.categoryIdentifier == NotificationCategory.appointmentReminder.rawValue {
                let provider = (userInfo["providerID"] as? String).flatMap { UUID(uuidString: $0) }
                sessionPrep = SessionPrepRequest(providerID: provider)
            }
            if response.actionIdentifier != "IM_OKAY",
               response.notification.request.content.categoryIdentifier == NotificationCategory.helloReminder.rawValue,
               let raw = userInfo[HelloReminders.contactKey] as? String, let contact = UUID(uuidString: raw) {
                hello = HelloRequest(contactID: contact)
            }
            if response.notification.request.content.categoryIdentifier == NotificationCategory.dailyCheckIn.rawValue {
                shouldOpenCheckIn = true
            }
        case "CHECKIN_NOW":
            shouldOpenCheckIn = true
        case "CONTACT":
            cancelFollowUps(userInfo: userInfo, firedAt: response.notification.date)
            let name = userInfo["contactName"] as? String ?? ""
            let phone = userInfo["contactPhone"] as? String ?? ""
            if !phone.isEmpty {
                contactMessagePrompt = ContactMessagePrompt(name: name, phoneNumber: phone)
            }
        default:
            break
        }
    }

    /// Answering a trigger window reminder takes away that day's escalation reminders and leaves
    /// the weeks after it alone. Reminders scheduled before this change listed repeating
    /// identifiers instead, and are handled the old way until the next re-sync replaces them.
    private func cancelFollowUps(userInfo: [AnyHashable: Any], firedAt: Date) {
        if let keys = userInfo["escalationKeys"] as? [String] {
            NotificationScheduler.cancelEscalations(keys: keys, firedAt: firedAt)
        } else if let ids = userInfo["escalationIdentifiers"] as? [String] {
            NotificationScheduler.cancelEscalations(identifiers: ids)
        }
    }
}
