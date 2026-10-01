import AppKit
import SwiftUI

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(MenuDayAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class MenuDayAppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var midnightTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePopover()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(targetDateDidChange),
            name: UserDefaults.didChangeNotification,
            object: UserDefaults.standard
        )

        updateStatusTitle()
        scheduleMidnightRefresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        midnightTimer?.invalidate()
    }

    private func configureStatusItem() {
        // A stable identity preserves this item's user-defined menu-bar position.
        // Hidden Bar classifies macOS 27 items by that position and owning bundle.
        statusItem.autosaveName = "MenuDay.DDayStatus"
        statusItem.isVisible = true

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
            button.toolTip = "MenuDay"
        }
    }

    private func configurePopover() {
        let hostingController = NSHostingController(rootView: ContentView())
        hostingController.sizingOptions = [.preferredContentSize]

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
        }
    }

    @objc private func targetDateDidChange() {
        updateStatusTitle()
    }

    private func updateStatusTitle() {
        let storedInterval = UserDefaults.standard.object(forKey: "targetDate") as? Double
        let targetDate = storedInterval.map(Date.init(timeIntervalSinceReferenceDate:))
            ?? DDay.defaultTargetDate
        let title = DDay.remainingText(until: targetDate)

        statusItem.button?.title = title
        statusItem.button?.setAccessibilityLabel("Days remaining: \(title)")
    }

    private func scheduleMidnightRefresh() {
        midnightTimer?.invalidate()

        let calendar = Calendar.autoupdatingCurrent
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: .now)
        ) ?? .now.addingTimeInterval(86_400)

        midnightTimer = Timer(
            fireAt: tomorrow,
            interval: 0,
            target: self,
            selector: #selector(midnightDidPass),
            userInfo: nil,
            repeats: false
        )
        if let midnightTimer {
            RunLoop.main.add(midnightTimer, forMode: .common)
        }
    }

    @objc private func midnightDidPass() {
        updateStatusTitle()
        scheduleMidnightRefresh()
    }
}

enum DDay {
    static var defaultTargetDate: Date {
        Calendar.autoupdatingCurrent.date(byAdding: .day, value: 30, to: .now) ?? .now
    }

    static func remainingDays(
        until targetDate: Date,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        let targetDay = calendar.startOfDay(for: targetDate)
        return calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0
    }

    static func remainingText(
        until targetDate: Date,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let days = remainingDays(until: targetDate, now: now, calendar: calendar)
        return days >= 0 ? "D-\(days)" : "D+\(-days)"
    }
}
