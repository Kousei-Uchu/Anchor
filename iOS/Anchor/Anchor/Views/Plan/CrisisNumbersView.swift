//
//  CrisisNumbersView.swift
//  Anchor
//
//  Crisis numbers for the user's region. Defaults to the phone's region
//  setting, and can be changed by hand from the menu at the bottom of the
//  card, since someone might be travelling or have a different region set.
//

import SwiftUI

struct CrisisNumber: Identifiable {
    let label: String
    let url: String
    let display: String
    var id: String { label + url }
}

enum CrisisRegion: String, CaseIterable, Identifiable {
    case au, us, ca, gb, ie, nz, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .au: return "Australia"
        case .us: return "United States"
        case .ca: return "Canada"
        case .gb: return "United Kingdom"
        case .ie: return "Ireland"
        case .nz: return "New Zealand"
        case .other: return "Somewhere else"
        }
    }

    static func detect() -> CrisisRegion {
        switch Locale.current.region?.identifier {
        case "AU": return .au
        case "US": return .us
        case "CA": return .ca
        case "GB": return .gb
        case "IE": return .ie
        case "NZ": return .nz
        default: return .other
        }
    }

    var numbers: [CrisisNumber] {
        switch self {
        case .au:
            return [
                CrisisNumber(label: "Emergency", url: "tel:000", display: "000"),
                CrisisNumber(label: "Lifeline (call)", url: "tel:131114", display: "13 11 14"),
                CrisisNumber(label: "Lifeline (text)", url: "sms:0477131114", display: "0477 13 11 14"),
            ]
        case .us:
            return [
                CrisisNumber(label: "Emergency", url: "tel:911", display: "911"),
                CrisisNumber(label: "988 Lifeline (call)", url: "tel:988", display: "988"),
                CrisisNumber(label: "988 Lifeline (text)", url: "sms:988", display: "988"),
            ]
        case .ca:
            return [
                CrisisNumber(label: "Emergency", url: "tel:911", display: "911"),
                CrisisNumber(label: "9-8-8 (call)", url: "tel:988", display: "9-8-8"),
                CrisisNumber(label: "9-8-8 (text)", url: "sms:988", display: "9-8-8"),
            ]
        case .gb:
            return [
                CrisisNumber(label: "Emergency", url: "tel:999", display: "999"),
                CrisisNumber(label: "Samaritans (call)", url: "tel:116123", display: "116 123"),
                CrisisNumber(label: "Shout (text SHOUT)", url: "sms:85258", display: "85258"),
            ]
        case .ie:
            return [
                CrisisNumber(label: "Emergency", url: "tel:112", display: "112 or 999"),
                CrisisNumber(label: "Samaritans (call)", url: "tel:116123", display: "116 123"),
                CrisisNumber(label: "Pieta (call)", url: "tel:1800247247", display: "1800 247 247"),
            ]
        case .nz:
            return [
                CrisisNumber(label: "Emergency", url: "tel:111", display: "111"),
                CrisisNumber(label: "1737 (call)", url: "tel:1737", display: "1737"),
                CrisisNumber(label: "1737 (text)", url: "sms:1737", display: "1737"),
            ]
        case .other:
            return [
                CrisisNumber(label: "Emergency (many countries)", url: "tel:112", display: "112"),
                CrisisNumber(label: "Find a local helpline", url: "https://findahelpline.com", display: "findahelpline.com"),
            ]
        }
    }
}

struct CrisisNumbersView: View {
    @AppStorage("anchor.crisisRegion") private var regionSetting = "auto"

    private var region: CrisisRegion {
        if regionSetting == "auto" { return CrisisRegion.detect() }
        return CrisisRegion(rawValue: regionSetting) ?? CrisisRegion.detect()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Crisis numbers", systemImage: "cross.case.fill")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            ForEach(region.numbers) { entry in
                if let url = URL(string: entry.url) {
                    Link(destination: url) {
                        HStack {
                            Text(entry.label)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                            Spacer()
                            Text(entry.display)
                            Image(systemName: entry.url.hasPrefix("https") ? "safari.fill" : (entry.url.hasPrefix("sms:") ? "message.fill" : "phone.fill"))
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
            Menu {
                Button("Use my phone's region") { regionSetting = "auto" }
                ForEach(CrisisRegion.allCases) { option in
                    Button(option.name) { regionSetting = option.rawValue }
                }
            } label: {
                Label("Numbers for \(region.name). Change", systemImage: "globe")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.red.opacity(0.85), Color.red.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}
