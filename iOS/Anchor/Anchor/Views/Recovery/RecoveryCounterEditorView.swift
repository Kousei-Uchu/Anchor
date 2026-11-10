//
//  RecoveryCounterEditorView.swift
//  Anchor
//
//  Create or edit a counter. A configure surface (settings look, opened from the
//  gear): name, start and day count first, then Savings, then what (if anything)
//  lock-screen surfaces may say, then Delete.
//

import SwiftUI
import SwiftData

struct RecoveryCounterEditorView: View {
    /// A section the editor can open scrolled to, e.g. from the Savings tab.
    enum Focus: Hashable { case savings }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existing: [RecoveryCounter]

    let counter: RecoveryCounter?
    /// When set (editing an existing counter), a delete button is shown. The caller
    /// closes this sheet and performs the deletion after it has gone, so nothing
    /// reads a deleted counter.
    var onDelete: (() -> Void)? = nil
    var focus: Focus? = nil

    @State private var name: String
    @State private var discreetLabel: String
    @State private var showNameOutsideApp: Bool
    @State private var startDate: Date
    @State private var mode: DayCountMode
    @State private var tracksSavings: Bool
    @State private var amountText: String
    @State private var period: SavingsPeriod
    @State private var currencyCode: String
    @State private var confirmDelete = false

    init(counter: RecoveryCounter?, onDelete: (() -> Void)? = nil, focus: Focus? = nil) {
        self.counter = counter
        self.onDelete = onDelete
        self.focus = focus
        _name = State(initialValue: counter?.name ?? "")
        _discreetLabel = State(initialValue: counter?.discreetLabel ?? "Your counter")
        _showNameOutsideApp = State(initialValue: counter?.showNameOutsideApp ?? false)
        _startDate = State(initialValue: counter?.currentRun?.start ?? Date.now)
        _mode = State(initialValue: counter?.mode ?? .runAndTotal)
        let amount = counter?.savingsAmount ?? 0
        _tracksSavings = State(initialValue: amount > 0)
        _amountText = State(initialValue: amount > 0 ? String(amount) : "")
        _period = State(initialValue: counter?.savingsPeriod ?? .week)
        _currencyCode = State(initialValue: counter?.currencyCode ?? RecoveryCounter.defaultCurrencyCode)
    }

    var body: some View {
        ScrollViewReader { proxy in
        Form {
            Section {
                TextField("What are you counting?", text: $name)
            } footer: {
                Text("Your own words. This name is only shown inside Anchor.")
            }

            Section {
                DatePicker("Started", selection: $startDate, in: ...Date.now)
            } footer: {
                Text("The day and time your current run began. You can change this later.")
            }

            Section {
                Picker("Day count", selection: $mode) {
                    ForEach(DayCountMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("How days are counted")
            } footer: {
                Text(mode.explanation)
            }

            Section {
                Toggle("Track money saved", isOn: $tracksSavings)
                if tracksSavings {
                    HStack {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                        Picker("", selection: $period) {
                            ForEach(SavingsPeriod.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden()
                    }
                    TextField("Currency code, e.g. AUD", text: $currencyCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("Savings")
            } footer: {
                Text("A simple estimate of what you haven't spent. It never leaves your phone.")
            }
            .id(Focus.savings)

            Section {
                Toggle("Show this name outside the app", isOn: $showNameOutsideApp)
                if !showNameOutsideApp {
                    TextField("Label for widgets and reminders", text: $discreetLabel)
                }
            } header: {
                Text("Lock screen and widgets")
            } footer: {
                Text(showNameOutsideApp
                     ? "Widgets and reminders will show this counter's name. Anyone who can see your lock screen could see it."
                     : "Widgets and reminders will only say this label, never the name above.")
            }

            if onDelete != nil {
                Section {
                    Button("Delete this counter", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .anchorSettingsStyle()
        .onAppear {
            if let focus { proxy.scrollTo(focus, anchor: .top) }
        }
        .navigationTitle(counter == nil ? "New counter" : "Counter settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .confirmationDialog("Delete this counter?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete it and its pledges and reviews", role: .destructive) { onDelete?() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let trimmedLabel = discreetLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmedLabel.isEmpty ? "Your counter" : trimmedLabel
        let amount = tracksSavings ? (Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0) : 0
        let code = currencyCode.trimmingCharacters(in: .whitespaces).uppercased()
        let safeCode = code.isEmpty ? RecoveryCounter.defaultCurrencyCode : code
        let start = min(startDate, Date.now)

        if let counter {
            counter.name = trimmedName
            counter.discreetLabel = label
            counter.showNameOutsideApp = showNameOutsideApp
            counter.mode = mode
            counter.savingsAmount = amount
            counter.savingsPeriod = period
            counter.currencyCode = safeCode
            counter.setCurrentRunStart(start)
        } else {
            let created = RecoveryCounter(name: trimmedName, discreetLabel: label, showNameOutsideApp: showNameOutsideApp,
                                          mode: mode, startDate: start, savingsAmount: amount,
                                          savingsPeriod: period, currencyCode: safeCode, sortOrder: existing.count)
            // A counter that starts in the past shouldn't celebrate days that were already behind it.
            created.acknowledgeMilestones()
            modelContext.insert(created)
        }
        RecoveryNotifications.refresh(using: modelContext)
        dismiss()
    }
}

/// What to do after a slip. Nothing is deleted; the run ends and a new one begins.
struct RecoverySlipView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let counter: RecoveryCounter

    @State private var slipDate = Date.now
    @State private var restartDate = Date.now
    @State private var times = 1

    var body: some View {
        Form {
            Section {
                if counter.mode == .runAndTotal {
                    Text("That's a hard moment, and it doesn't undo what you've done. Your \(RecoveryText.days(counter.totalDays())) in total stay. Only the current run starts again.")
                } else {
                    Text("That's a hard moment. The count will start again from zero. What you built before still happened.")
                }
            }

            Section("When did it happen?") {
                DatePicker("Date", selection: $slipDate, in: ...Date.now)
            }

            Section {
                Stepper("Times that day: \(times)", value: $times, in: 1...50)
            } footer: {
                Text("Optional, and just for your own record. It appears in the Times list. Leave it at 1 if you'd rather not say.")
            }

            Section {
                DatePicker("Start again from", selection: $restartDate, in: slipDate...)
            } footer: {
                Text("Usually now. You can pick a later time if you'd rather begin tomorrow.")
            }
        }
        .navigationTitle("Start again")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: slipDate) { _, newValue in
            if restartDate < newValue { restartDate = newValue }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Start again") {
                    counter.recordSlip(on: slipDate, restartAt: restartDate)
                    recordTimes()
                    RecoveryNotifications.refresh(using: modelContext)
                    dismiss()
                }
            }
        }
    }

    /// Remembers how many times it happened on the day of the slip.
    private func recordTimes() {
        let day = Calendar.current.startOfDay(for: slipDate)
        let id = counter.id
        // The day is locked, so the database cannot match on it: fetch this counter's days and pick the day here.
        let forCounter = (try? modelContext.fetch(FetchDescriptor<RecoveryDayEntry>(predicate: #Predicate { $0.counterID == id }))) ?? []
        let existing = forCounter.first { $0.day == day }
        let entry = existing ?? {
            let created = RecoveryDayEntry(counterID: id, day: day)
            modelContext.insert(created)
            return created
        }()
        entry.slipTimes += times
    }
}
