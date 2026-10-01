import AppKit
import ServiceManagement
import SwiftUI

struct ContentView: View {
    @AppStorage("targetDate") private var targetDateInterval = DDay.defaultTargetDate.timeIntervalSinceReferenceDate

    private var targetDate: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: targetDateInterval) },
            set: { targetDateInterval = $0.timeIntervalSinceReferenceDate }
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            DDayHeader(targetDate: targetDate.wrappedValue)
            CompactDateSelector(date: targetDate)

            Divider()

            FooterControls()
        }
        .padding(20)
        .frame(width: 280)
    }
}

private struct DDayHeader: View {
    let targetDate: Date

    var body: some View {
        VStack(spacing: 4) {
            Text(DDay.remainingText(until: targetDate))
                .font(.largeTitle.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(targetDate, format: .dateTime.weekday(.wide).month(.wide).day().year())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CompactDateSelector: View {
    @Binding var date: Date

    private var calendar: Calendar {
        .autoupdatingCurrent
    }

    private var selectedYear: Int {
        calendar.component(.year, from: date)
    }

    private var selectedMonth: Int {
        calendar.component(.month, from: date)
    }

    private var selectedDay: Int {
        calendar.component(.day, from: date)
    }

    private var years: [Int] {
        let currentYear = calendar.component(.year, from: .now)
        return Array(min(currentYear, selectedYear)...(currentYear + 100))
    }

    private var days: [Int] {
        let components = DateComponents(year: selectedYear, month: selectedMonth)
        guard let month = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: month) else {
            return Array(1...31)
        }
        return Array(range)
    }

    var body: some View {
        HStack(spacing: 8) {
            DatePartPicker(title: "Year", selection: yearBinding, values: years) { year in
                Text(year, format: .number.grouping(.never))
            }

            MonthPicker(selection: monthBinding)

            DatePartPicker(title: "Day", selection: dayBinding, values: days) { day in
                Text(day, format: .number)
            }
        }
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { selectedYear },
            set: { updateDate(year: $0, month: selectedMonth, day: selectedDay) }
        )
    }

    private var monthBinding: Binding<Int> {
        Binding(
            get: { selectedMonth },
            set: { updateDate(year: selectedYear, month: $0, day: selectedDay) }
        )
    }

    private var dayBinding: Binding<Int> {
        Binding(
            get: { selectedDay },
            set: { updateDate(year: selectedYear, month: selectedMonth, day: $0) }
        )
    }

    private func updateDate(year: Int, month: Int, day: Int) {
        let firstOfMonth = DateComponents(year: year, month: month, day: 1)
        guard let monthDate = calendar.date(from: firstOfMonth),
              let validDays = calendar.range(of: .day, in: .month, for: monthDate) else {
            return
        }

        let clampedDay = min(day, validDays.count)
        if let newDate = calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: clampedDay
        )) {
            date = newDate
        }
    }
}

private struct DatePartPicker<Label: View>: View {
    let title: LocalizedStringResource
    @Binding var selection: Int
    let values: [Int]
    @ViewBuilder let label: (Int) -> Label

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(title, selection: $selection) {
                ForEach(values, id: \.self) { value in
                    label(value)
                        .tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct MonthPicker: View {
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Month")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Month", selection: $selection) {
                ForEach(1...12, id: \.self) { month in
                    Text(monthDate(month), format: .dateTime.month(.abbreviated))
                        .tag(month)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
    }

    private func monthDate(_ month: Int) -> Date {
        Calendar.autoupdatingCurrent.date(
            from: DateComponents(year: 2000, month: month, day: 1)
        ) ?? .now
    }
}

private struct FooterControls: View {
    var body: some View {
        HStack(spacing: 12) {
            LaunchAtLoginToggle()

            Spacer(minLength: 8)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
    }
}

private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = Self.isRegistered
    @State private var statusMessage: LocalizedStringResource?

    private static var isRegistered: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle("Launch at Login", isOn: Binding(
                get: { isEnabled },
                set: updateRegistration
            ))
            .controlSize(.small)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            refreshStatus()
        }
    }

    private func updateRegistration(_ shouldRegister: Bool) {
        statusMessage = nil

        do {
            if shouldRegister {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            statusMessage = "Unable to update the login setting."
        }

        refreshStatus()
    }

    private func refreshStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true
        case .requiresApproval:
            isEnabled = true
            statusMessage = "Approval is required in System Settings."
        case .notRegistered, .notFound:
            isEnabled = false
        @unknown default:
            isEnabled = false
        }
    }
}

#Preview {
    ContentView()
        .padding()
}
