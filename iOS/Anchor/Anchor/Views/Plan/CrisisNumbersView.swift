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
    /// Every line here was checked against its own organisation's page or a government page (see docs/CRISIS_LINES.md),
    /// and each label says when it is open if that is not all day, so nobody rings a line that is closed.
    var lgbtqNumbers: [CrisisNumber] {
        switch self {
        case .au:
            return [CrisisNumber(label: "QLife (3pm to midnight)", url: "tel:1800184527", display: "1800 184 527")]
        case .us:
            return [
                CrisisNumber(label: "Trevor Project, LGBTQ young people (call, 24/7)", url: "tel:18664887386", display: "1-866-488-7386"),
                CrisisNumber(label: "Trevor Project (text START)", url: "sms:678678&body=START", display: "678-678"),
                CrisisNumber(label: "Trans Lifeline (peer support)", url: "tel:18775658860", display: "1-877-565-8860")
            ]
        case .ca:
            return [
                CrisisNumber(label: "Trans Lifeline (peer support)", url: "tel:18773306366", display: "1-877-330-6366"),
                CrisisNumber(label: "LGBT YouthLine (text, Ontario, under 30)", url: "sms:6476944275", display: "647-694-4275")
            ]
        case .gb:
            return [
                CrisisNumber(label: "Switchboard LGBT+ (10am to 10pm)", url: "tel:08000119100", display: "0800 0119 100"),
                CrisisNumber(label: "Mindline Trans+ (Mon and Fri evenings)", url: "tel:03003305468", display: "0300 330 5468")
            ]
        case .ie:
            return [CrisisNumber(label: "LGBT Ireland helpline (evenings)", url: "tel:1800929539", display: "1800 929 539")]
        case .nz:
            return [CrisisNumber(label: "OUTLine (6pm to 9pm)", url: "tel:08006885463", display: "0800 688 5463")]
        case .other:
            return []
        }
    }

    /// Numbers for the region's Indigenous peoples. Only shown when switched on. Where there is no line to list, it is
    /// left empty rather than filled with something unchecked.
    var indigenousNumbers: [CrisisNumber] {
        switch self {
        case .au:
            return [CrisisNumber(label: "13YARN (24/7)", url: "tel:139276", display: "13 92 76")]
        case .us:
            return [CrisisNumber(label: "StrongHearts Native Helpline (domestic, dating and sexual violence, 24/7)", url: "tel:18447628483", display: "1-844-762-8483")]
        case .ca:
            return [
                CrisisNumber(label: "Hope for Wellness, Indigenous peoples (24/7)", url: "tel:18552423310", display: "1-855-242-3310"),
                CrisisNumber(label: "Talk4Healing, Indigenous women (24/7)", url: "tel:18555544325", display: "1-855-554-4325")
            ]
        case .gb, .ie, .nz, .other:
            return []
        }
    }

    /// What the switch for the Indigenous lines is called in this region.
    var indigenousLabel: String {
        switch self {
        case .au: return "Aboriginal and Torres Strait Islander lines"
        case .us: return "Native American and Alaska Native lines"
        default: return "Indigenous support lines"
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
                footer: "These are added to the Crisis numbers card on Now. Find a helpline is always there." + (region.indigenousNumbers.isEmpty && region != .other ? " No Indigenous line has been checked for \(region.name) yet, so there is no switch for one." : "") + (region == .other ? " Pick a region in the Crisis numbers card to see its extra lines." : "")
            ) {
                if !region.lgbtqNumbers.isEmpty {
                    Anchor.SettingsToggle(title: "LGBTQIA+ support lines", isOn: $showLGBTQ)
                }
                if !region.indigenousNumbers.isEmpty {
                    Anchor.SettingsToggle(title: region.indigenousLabel, isOn: $showIndigenous)
                }
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
