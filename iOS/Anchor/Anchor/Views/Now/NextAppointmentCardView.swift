//
//  NextAppointmentCardView.swift
//  Anchor
//
//  Surfaces the single soonest upcoming appointment on Now, so "when do I
//  next see my psych" doesn't require a trip to Plan. Only shown when
//  there's actually something scheduled — nothing to configure here, this
//  is read-only with a tap-through to the full calendar.
//

import SwiftUI
import SwiftData

struct NextAppointmentCardView: View {
    @Query private var series: [AppointmentSeries]

    private var calendar: Calendar { Calendar.current }

    /// The soonest occurrence across *every* series, paired with the
    /// series it belongs to (so the tap-through lands on the right
    /// clinician's calendar, not just the first one found).
    private var nextUpcoming: (series: AppointmentSeries, occurrence: AppointmentOccurrence)? {
        series
            .flatMap { seriesItem in seriesItem.occurrences.map { (seriesItem, $0) } }
            .filter { $0.1.scheduledDate > .now }
            .min { $0.1.scheduledDate < $1.1.scheduledDate }
    }

    var body: some View {
        if let next = nextUpcoming {
            NavigationLink {
                AppointmentView(series: next.series)
            } label: {
                Anchor.Card {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Anchor.SectionHeader(icon: "calendar.badge.clock", title: "Next appointment")
                            Text("\(next.series.clinicianLabel) · \(next.occurrence.scheduledDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(daysUntilLabel(next.occurrence.scheduledDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func daysUntilLabel(_ date: Date) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: date)).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }
}
