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

// MARK: - Extra lines, custom numbers and settings

extension CrisisRegion {
    /// Numbers for LGBTQIA+ people. Only shown when the person switches them on. A region with none listed
    /// here has none checked yet; the Find a helpline row is always there for it.
    var lgbtqNumbers: [CrisisNumber] {
        switch self {
        case .au:
            return [CrisisNumber(label: "QLife (3pm to midnight)", url: "tel:1800184527", display: "1800 184 527")]
        default:
            return []
        }
    }

    /// Numbers for Aboriginal and Torres Strait Islander people (or the region's Indigenous peoples). Only shown when switched on.
    var indigenousNumbers: [CrisisNumber] {
        switch self {
        case .au:
            return [CrisisNumber(label: "13YARN (24/7)", url: "tel:139276", display: "13 92 76")]
        default:
            return []
        }
    }

    static let findAHelpline = CrisisNumber(label: "Find a helpline", url: "https://findahelpline.com", display: "findahelpline.com")
}

/// A number the person added themselves, for someone they trust or a service near them.
struct CustomCrisisNumber: Codable, Identifiable, Hashable {
    var id = UUID()
    var label = ""
    var number = ""

    var crisisNumber: CrisisNumber? {
        let dialable = number.filter { $0.isNumber || $0 == "+" || $0 == "*" || $0 == "#" }
        guard !dialable.isEmpty else { return nil }
        return CrisisNumber(label: label.isEmpty ? "My number" : label, url: "tel:" + dialable, display: number)
    }
}

enum CrisisSettings {
    static let showLGBTQ = "anchor.crisis.showLGBTQ"
    static let showIndigenous = "anchor.crisis.showIndigenous"
    static let customNumbers = "anchor.crisis.customNumbers"

    static func decode(_ raw: String) -> [CustomCrisisNumber] {
        guard let data = raw.data(using: .utf8),
              let list = try? JSONDecoder().decode([CustomCrisisNumber].self, from: data) else { return [] }
        return list
    }

    static func encode(_ list: [CustomCrisisNumber]) -> String {
        guard let data = try? JSONEncoder().encode(list), let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
}

/// Settings page: which extra lines to show, and the person's own numbers.
struct CrisisNumbersSettingsView: View {
    @AppStorage(CrisisSettings.showLGBTQ) private var showLGBTQ = false
    @AppStorage(CrisisSettings.showIndigenous) private var showIndigenous = false
    @AppStorage(CrisisSettings.customNumbers) private var customRaw = ""
    @AppStorage("anchor.crisisRegion") private var regionSetting = "auto"

    private var region: CrisisRegion {
        if regionSetting == "auto" { return CrisisRegion.detect() }
        return CrisisRegion(rawValue: regionSetting) ?? CrisisRegion.detect()
    }

    private var custom: Binding<[CustomCrisisNumber]> {
        Binding(get: { CrisisSettings.decode(customRaw) }, set: { customRaw = CrisisSettings.encode($0) })
    }

    var body: some View {
        Form {
            Anchor.SettingsSection(
                title: "Numbers for \(region.name)",
                footer: "These are added to the Crisis numbers card on Now. Find a helpline is always there. \(region.lgbtqNumbers.isEmpty && region.indigenousNumbers.isEmpty ? "No extra lines are listed for this region yet." : "")"
            ) {
                Anchor.SettingsToggle(title: "LGBTQIA+ support lines", isOn: $showLGBTQ)
                Anchor.SettingsToggle(title: "Aboriginal and Torres Strait Islander lines", isOn: $showIndigenous)
            }

            Anchor.SettingsSection(
                title: "My own numbers",
                footer: "A number you add shows on the Crisis numbers card, after the standard ones. It stays on this phone."
            ) {
                ForEach(custom) { $entry in
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Name, such as My sister", text: $entry.label)
                        TextField("Number", text: $entry.number)
                            .keyboardType(.phonePad)
                    }
                    .font(.system(.subheadline, design: .rounded))
                }
                .onDelete { offsets in
                    var list = custom.wrappedValue
                    list.remove(atOffsets: offsets)
                    custom.wrappedValue = list
                }
                Button {
                    custom.wrappedValue = custom.wrappedValue + [CustomCrisisNumber()]
                } label: {
                    Label("Add a number", systemImage: "plus.circle.fill")
                        .font(.system(.subheadline, design: .rounded))
                }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("Crisis numbers")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CrisisNumbersView: View {
    @AppStorage("anchor.crisisRegion") private var regionSetting = "auto"
    @AppStorage(CrisisSettings.showLGBTQ) private var showLGBTQ = false
    @AppStorage(CrisisSettings.showIndigenous) private var showIndigenous = false
    @AppStorage(CrisisSettings.customNumbers) private var customRaw = ""

    /// The region's standard numbers, then the person's own, then any extra lines they switched on, then Find a helpline.
    private var numbers: [CrisisNumber] {
        var list = region.numbers
        list += CrisisSettings.decode(customRaw).compactMap { $0.crisisNumber }
        if showLGBTQ { list += region.lgbtqNumbers }
        if showIndigenous { list += region.indigenousNumbers }
        if !list.contains(where: { $0.url == CrisisRegion.findAHelpline.url }) { list.append(CrisisRegion.findAHelpline) }
        return list
    }

    private var region: CrisisRegion {
        if regionSetting == "auto" { return CrisisRegion.detect() }
        return CrisisRegion(rawValue: regionSetting) ?? CrisisRegion.detect()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Crisis numbers", systemImage: "cross.case.fill")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            ForEach(numbers) { entry in
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
