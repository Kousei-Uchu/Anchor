import Foundation
import Security
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What an AI tool is asked to do (Patch AI1, docs/OPTIONAL_FEATURES.md). Each tool is one action on text the
/// person chose, with a fixed instruction that is shown in full on the consent sheet before anything is sent.
/// A later patch adds its own case, and its own instruction, here.
enum AIFeature: String, CaseIterable {
    case makeShorter
    case breakIntoSteps
    case estimateTime
    case turnIntoTasks
    case turnIntoThingsToRaise
    case findSpeakerChanges

    /// The plain name of the button, and of the tool in the list of ones that no longer ask.
    var title: String {
        switch self {
        case .makeShorter: return "Make shorter"
        case .breakIntoSteps: return "Break into steps"
        case .estimateTime: return "Estimate time"
        case .turnIntoTasks: return "Turn into tasks"
        case .turnIntoThingsToRaise: return "Turn into things to raise"
        case .findSpeakerChanges: return "Suggest who is speaking"
        }
    }

    /// The fixed instruction that goes with the text. It says what to keep and what never to add.
    var instruction: String {
        switch self {
        case .makeShorter:
            return "Rewrite this text so it is clearly shorter, about half its length. Cut repetition, filler, hedging and sentences that only say a point again. Keep every name, number and date, and keep who said what. Add nothing: no advice, no comment on feelings, no new facts. Use the same voice and the same language as the text. Reply with the shorter text only."
        case .breakIntoSteps:
            return "Break this task into a short list of small steps, in the order they would be done. Use only what the text says or plainly needs. Add no dates, no priorities, no advice and no comment on feelings. Write one step per line, with no numbers, bullets or other words, and at most 8 lines. Use the same language as the text."
        case .estimateTime:
            return "Guess how many minutes this task takes to do. Reply with one whole number of minutes and nothing else."
        case .turnIntoTasks:
            return "Turn this text into a short list of tasks the writer said they need to do or plainly meant to do. Use only what the text says. Add no tasks of your own, no dates, no priorities, no advice and no comment on feelings. Write one task per line, as a short action, with no numbers, bullets or other words, and at most 12 lines. If the text holds nothing to do, reply with nothing. Use the same language as the text."
        case .turnIntoThingsToRaise:
            return "Turn this text into a short list of things the writer wants to bring up in an appointment or session. Keep each one in the writer's own words as far as you can. Use only what the text says. Add nothing: no advice, no diagnosis, no comment on feelings, no new facts. Write one item per line, with no numbers, bullets or other words, at most 12 lines, and keep each under 160 characters. If the text holds nothing to bring up, reply with nothing. Use the same language as the text."
        case .findSpeakerChanges:
            return "Below is the transcript of a recording, cut into numbered pieces in order. Say where a different person starts speaking, using only how the words read, such as a question and its reply or a change between I and you. You cannot hear anyone, so do not guess about voices, names or anything the words do not show. Reply with one line for each piece where the speaker changes, and one for piece 1: the number, a space, and a letter, A for the first speaker, B for the next new one, and so on, using the same letter when an earlier speaker comes back. Use at most 6 letters. Write nothing else. If it reads as one person throughout, reply with: 1 A"
        }
    }
}

/// Where a tool can run. Apple's model on the phone, Ollama on the person's own computer (Patch AI5), and a
/// provider the person adds themselves, with their own key (Patch AI6, D42). The last is empty to begin with and
/// is never suggested, named or chosen for the person.
enum AIProviderKind: String, CaseIterable {
    case apple
    case ollama
    case other

    var name: String {
        switch self {
        case .apple: return "Apple's on-device model"
        case .ollama: return "Ollama on your computer"
        case .other: return "Other provider"
        }
    }

    /// The short place name used on the Settings screen.
    var placeName: String {
        switch self {
        case .apple: return "On this phone"
        case .ollama: return "On my computer"
        case .other: return "Other"
        }
    }

    /// Where the text goes, in the words the consent sheet uses.
    var whereItRuns: String {
        switch self {
        case .apple: return "On this phone. The text does not leave it."
        case .ollama: return "On your own computer, at the address below. The text goes there as it is and nowhere else."
        case .other: return "Over the internet, to the address below, with the key you gave. The text goes there as it is and nowhere else."
        }
    }

    /// What the provider does with the text, as far as Anchor can say.
    var keeping: String {
        switch self {
        case .apple: return "It is held in memory on this phone until you keep or discard the answer. Anchor keeps no log of it."
        case .ollama: return "Ollama holds it on your computer while it works. Anchor keeps no log of it. What Ollama keeps is set on your computer, and Anchor cannot see it."
        case .other: return "The provider receives it with your key. Anchor keeps no log of it, and cannot see or check how the provider keeps it or whether it is used for anything else. Any zero retention setting is yours, with the provider."
        }
    }

    /// Whether the consent sheet offers Don't ask again. Never for a provider the person added themselves (D42).
    var offersDontAskAgain: Bool {
        switch self {
        case .apple: return true
        case .ollama: return true
        case .other: return false
        }
    }
}

/// Whether a provider can be used right now, in words the person can act on.
enum AIProviderStatus: Equatable {
    case ready
    case notOnThisPhone
    case appleIntelligenceOff
    case notReady
    case unavailable
    case aiToolsOff
    case notSetUp
    case addressNotConfirmed
    case otherNotSetUp

    var plainText: String {
        switch self {
        case .ready: return "Ready"
        case .notOnThisPhone: return "This phone cannot run it"
        case .appleIntelligenceOff: return "Turn on Apple Intelligence in the phone's Settings"
        case .notReady: return "Not ready yet, try again later"
        case .unavailable: return "Not available"
        case .aiToolsOff: return "AI tools are off"
        case .notSetUp: return "Add your computer's address and a model name"
        case .addressNotConfirmed: return "Confirm the address in Settings, AI tools"
        case .otherNotSetUp: return "Add an address, a key and a model name"
        }
    }
}

enum AIError: Error, Equatable {
    case off
    case busy
    case nothingToSend
    case tooLong(limit: Int)
    case unavailable(AIProviderStatus)
    case cancelled
    case failed
    case cannotReach
    case modelNotFound
    case keyRefused
    case providerNotFound
    case providerBusy
    case cannotReachProvider

    var plainText: String {
        switch self {
        case .off: return "AI tools are off."
        case .busy: return "Another request is still going."
        case .nothingToSend: return "There is no text to send."
        case .tooLong(let limit): return "That is too long for this tool. Pick up to \(limit) characters. Nothing was sent."
        case .unavailable(let status): return status.plainText + ". Nothing was sent."
        case .cancelled: return "Cancelled. Nothing was sent."
        case .failed: return "It could not make an answer. Nothing was kept."
        case .cannotReach: return "Anchor could not reach your computer. Check the address, that Ollama is running, that you are on the same network, and that Local Network is on for Anchor in the phone's Settings. Nothing was kept."
        case .modelNotFound: return "Ollama on your computer does not have that model. Check the name in Settings, AI tools. Nothing was kept."
        case .keyRefused: return "The provider did not accept the key. Check it in Settings, AI tools. Nothing was kept."
        case .providerNotFound: return "The provider did not find that address or model. Check both in Settings, AI tools. Nothing was kept."
        case .providerBusy: return "The provider says there are too many requests, or the account has no credit left. Try again later. Nothing was kept."
        case .cannotReachProvider: return "Anchor could not reach the provider. Check the address and your connection. Nothing was kept."
        }
    }
}

/// One place a tool can run. It is only ever called by `AIAsk`, after the gate and after the person has been
/// shown the consent sheet (or has said not to be asked again), and `scripts/check-ai-gate.mjs` checks that.
protocol AIProviding: Sendable {
    var kind: AIProviderKind { get }
    /// The most characters this provider takes in one go. Longer text is refused before anything is sent.
    var maxCharacters: Int { get }
    /// Where exactly the text goes, when that is more than the kind says (the address of the person's computer).
    /// The consent sheet shows it under Where it goes.
    var destination: String? { get }
    /// One line on the consent sheet under the address, saying where that address is (Patch AI8).
    var destinationNote: String? { get }
    func status() -> AIProviderStatus
    func generate(instruction: String, text: String) async throws -> String
}

extension AIProviding {
    var destination: String? { nil }
    var destinationNote: String? { nil }
}

enum AIProviders {
    static let choiceKey = "aiProviderChoice"

    /// The provider in use. Apple's on-device model until the person picks another one in Settings, AI tools. It is
    /// kept in the phone's settings like the AI switch, so it is not in a backup and Clear all data leaves it.
    static var chosen: AIProviderKind {
        AIProviderKind(rawValue: UserDefaults.standard.string(forKey: choiceKey) ?? "") ?? .apple
    }

    static func setChosen(_ kind: AIProviderKind) {
        UserDefaults.standard.set(kind.rawValue, forKey: choiceKey)
    }

    static func make(_ kind: AIProviderKind) -> AIProviding {
        switch kind {
        case .apple: return AppleOnDeviceProvider()
        case .ollama: return OllamaProvider()
        case .other: return OtherProvider()
        }
    }
}

/// Apple's on-device model, through the FoundationModels framework. It runs on the phone, with no network.
/// It needs a phone that supports Apple Intelligence with it turned on in the phone's Settings.
struct AppleOnDeviceProvider: AIProviding {
    let kind = AIProviderKind.apple

    /// A guess to be checked on a real phone: the on-device model has a small context window, and the answer
    /// shares it with the text and the instruction, so the text is held well below it.
    let maxCharacters = 4000

    func status() -> AIProviderStatus {
        guard AIGate.isEnabled else { return .aiToolsOff }
        #if canImport(FoundationModels)
        // FoundationModels needs iOS 26; the app still runs on iOS 17 and says it is unavailable there.
        guard #available(iOS 26.0, *) else { return .notOnThisPhone }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .notOnThisPhone
            case .appleIntelligenceNotEnabled: return .appleIntelligenceOff
            case .modelNotReady: return .notReady
            @unknown default: return .unavailable
            }
        @unknown default:
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    /// The text set apart from the instruction, so the model treats it as something to work on and not to continue.
    static func framed(_ text: String) -> String {
        "Text to work on:\n\n" + text
    }

    /// True when a reply is the text it was given, ignoring case and spacing. Only for text long enough that an
    /// identical answer cannot be right (a one-line task can come back as itself).
    static func isUnchangedCopy(_ reply: String, of text: String) -> Bool {
        func squash(_ value: String) -> String {
            value.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }
        let original = squash(text)
        return original.count >= 120 && squash(reply) == original
    }

    func generate(instruction: String, text: String) async throws -> String {
        guard AIGate.isEnabled else { throw AIError.off }
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { throw AIError.unavailable(.notOnThisPhone) }
        let session = LanguageModelSession(instructions: instruction)
        var reply = try await session.respond(to: Self.framed(text)).content
        // The small on-device model sometimes returns the text it was given. Try once more, firmly; if it still
        // does, say so instead of showing an unchanged copy as if it were a result.
        if Self.isUnchangedCopy(reply, of: text) {
            let firm = LanguageModelSession(instructions: instruction + " Your reply must not be a copy of the text. Do what the instructions say to it.")
            reply = try await firm.respond(to: Self.framed(text)).content
            if Self.isUnchangedCopy(reply, of: text) { throw AIError.failed }
        }
        return reply
        #else
        throw AIError.unavailable(.unavailable)
        #endif
    }
}

/// Why a typed address is not accepted, in words the person can act on (Patch AI5, AI8).
enum OllamaAddressProblem: Error, Equatable {
    case empty
    case notAnAddress
    case needsHTTPS
    case thisPhone

    var plainText: String {
        switch self {
        case .empty: return "Type your computer's address, such as 192.168.1.20."
        case .notAnAddress: return "That does not look like an address. Try something like 192.168.1.20 or my-mac.local."
        case .needsHTTPS: return "That address is away from your home network, so it needs https:// in front of it. A Tailscale number does not."
        case .thisPhone: return "That points at this phone. Use your computer's address."
        }
    }
}

/// How far from the person's home network an address is (Patch AI8, D56). Home is a private number, a name ending in
/// .local, or a single name. Tailscale is a number in Tailscale's own ranges or a name ending in .ts.net. Internet is
/// anything else. Anything but home is away, and is only used after the person has confirmed that address.
enum OllamaReach: Equatable {
    case home
    case tailscale
    case internet

    var isAway: Bool { self != .home }

    /// One line on the consent sheet under the address.
    var sheetNote: String {
        switch self {
        case .home: return "On your home network."
        case .tailscale: return "Away from your home network, through Tailscale. It can use mobile data."
        case .internet: return "Away from your home network, over the internet with https. It can use mobile data."
        }
    }

    /// The line in Settings under an address that is away.
    var settingsLine: String {
        switch self {
        case .home: return ""
        case .tailscale: return "This is a Tailscale address, away from your home network."
        case .internet: return "This address is away from your home network."
        }
    }

    /// What the confirmation alert says before an away address is used.
    var confirmText: String {
        switch self {
        case .home:
            return ""
        case .tailscale:
            return "Anchor will send the text you pick to this address through Tailscale, and it can use mobile data. Tailscale encrypts what crosses it. Only use an address that is your own computer. You will be asked again if you change the address."
        case .internet:
            return "Anchor will send the text you pick to this address over the internet, and it can use mobile data. https keeps it private on the way. Only use an address that is your own computer. You will be asked again if you change the address."
        }
    }
}

/// A checked address for Ollama on the person's own computer (Patch AI5, AI8). An address on the person's own
/// network is accepted as it is: a number in a private range, a name ending in .local, or a single name such as
/// my-mac. An address away from it (D56) is accepted too, but it is marked away, plain http is allowed only to a
/// Tailscale number, and `OllamaSettings` holds the text back until the person has confirmed that address.
struct OllamaEndpoint: Equatable {
    static let defaultPort = 11434
    static let securePort = 443

    let base: URL
    /// The scheme (only when https), host and port, as shown on the consent sheet.
    let display: String
    let reach: OllamaReach

    var isAway: Bool { reach.isAway }

    /// What a confirmation is remembered against.
    var confirmationKey: String { display }

    private struct HostClass {
        let reach: OllamaReach
        /// True for a number such as 192.168.1.20 or an IPv6 address, false for a name.
        let isNumber: Bool
    }

    static func parse(_ typed: String) -> Result<OllamaEndpoint, OllamaAddressProblem> {
        var text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .failure(.empty) }
        while text.hasSuffix("/") { text.removeLast() }
        var typedScheme: String?
        var rest = text
        if let marker = text.range(of: "://") {
            typedScheme = String(text[text.startIndex..<marker.lowerBound]).lowercased()
            rest = String(text[marker.upperBound...])
        }
        if let typedScheme, typedScheme != "http", typedScheme != "https" { return .failure(.notAnAddress) }

        let host: String
        var typedPort: Int?
        if rest.contains("[") || rest.filter({ $0 == ":" }).count >= 2 {
            guard let found = splitIPv6(rest) else { return .failure(.notAnAddress) }
            host = found.host
            typedPort = found.port
        } else {
            guard let parts = URLComponents(string: "http://" + rest),
                  let found = parts.host?.lowercased(), !found.isEmpty,
                  parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
                  parts.path.isEmpty
            else { return .failure(.notAnAddress) }
            host = found
            typedPort = parts.port
        }
        if let typedPort, typedPort < 1 || typedPort > 65535 { return .failure(.notAnAddress) }

        let classified: HostClass
        switch classify(host: host) {
        case .failure(let problem): return .failure(problem)
        case .success(let found): classified = found
        }
        // Plain http only on the home network or to a Tailscale number, which Tailscale encrypts. Everything else is
        // https, which is also all the phone's transport security allows for a name with dots in it.
        let plainAllowed = classified.reach == .home || (classified.reach == .tailscale && classified.isNumber)
        let scheme = typedScheme ?? (plainAllowed ? "http" : "https")
        if scheme == "http" && !plainAllowed { return .failure(.needsHTTPS) }
        let port = typedPort ?? (scheme == "https" ? securePort : defaultPort)
        let hostInURL = host.contains(":") ? "[" + host + "]" : host
        guard let base = URL(string: scheme + "://" + hostInURL + ":" + String(port)) else { return .failure(.notAnAddress) }
        let prefix = scheme == "https" ? "https://" : ""
        return .success(OllamaEndpoint(base: base, display: prefix + hostInURL + ":" + String(port), reach: classified.reach))
    }

    /// The eight 16-bit groups of an IPv6 address typed the usual way, or nil when the text is not one. A zone ending
    /// such as %en0 and an IPv4 tail are not accepted. The text must already be lower case.
    static func ipv6Groups(_ text: String) -> [UInt16]? {
        guard text.contains(":"), !text.contains("%") else { return nil }
        let allowed = Set("0123456789abcdef:")
        guard text.allSatisfy({ allowed.contains($0) }) else { return nil }
        let halves = text.components(separatedBy: "::")
        guard halves.count <= 2 else { return nil }
        func groups(_ part: String) -> [UInt16]? {
            if part.isEmpty { return [] }
            var out: [UInt16] = []
            for piece in part.split(separator: ":", omittingEmptySubsequences: false) {
                guard !piece.isEmpty, piece.count <= 4, let value = UInt16(piece, radix: 16) else { return nil }
                out.append(value)
            }
            return out
        }
        guard let head = groups(halves[0]) else { return nil }
        if halves.count == 1 { return head.count == 8 ? head : nil }
        guard let tail = groups(halves[1]) else { return nil }
        let missing = 8 - head.count - tail.count
        guard missing >= 1 else { return nil }
        return head + Array(repeating: 0, count: missing) + tail
    }

    /// An IPv6 address typed bare, or in square brackets with an optional port after them.
    private static func splitIPv6(_ text: String) -> (host: String, port: Int?)? {
        var address = text
        var port: Int?
        if address.hasPrefix("[") {
            guard let close = address.firstIndex(of: "]") else { return nil }
            let after = address[address.index(after: close)...]
            address = String(address[address.index(after: address.startIndex)..<close])
            if !after.isEmpty {
                guard after.hasPrefix(":"), let value = Int(after.dropFirst()), value >= 1, value <= 65535 else { return nil }
                port = value
            }
        }
        let lowered = address.lowercased()
        guard ipv6Groups(lowered) != nil else { return nil }
        return (lowered, port)
    }

    private static func classify(host: String) -> Result<HostClass, OllamaAddressProblem> {
        if host == "localhost" || host == "0.0.0.0" || host.hasPrefix("127.") { return .failure(.thisPhone) }
        if let groups = ipv6Groups(host) {
            if groups.dropLast().allSatisfy({ $0 == 0 }) && groups[7] <= 1 { return .failure(.thisPhone) }
            let first = groups[0]
            if (first & 0xff00) == 0xff00 { return .failure(.notAnAddress) }
            if first == 0xfd7a && groups[1] == 0x115c && groups[2] == 0xa1e0 {
                return .success(HostClass(reach: .tailscale, isNumber: true))
            }
            if (first & 0xffc0) == 0xfe80 || (first & 0xfe00) == 0xfc00 {
                return .success(HostClass(reach: .home, isNumber: true))
            }
            return .success(HostClass(reach: .internet, isNumber: true))
        }
        let pieces = host.split(separator: ".", omittingEmptySubsequences: false)
        let isDigit: (Character) -> Bool = { $0.isASCII && $0.isNumber }
        if pieces.count == 4, pieces.allSatisfy({ piece in !piece.isEmpty && piece.allSatisfy(isDigit) }) {
            let numbers = pieces.compactMap { Int($0) }
            guard numbers.count == 4, numbers.allSatisfy({ $0 >= 0 && $0 <= 255 }) else { return .failure(.notAnAddress) }
            if numbers[0] == 0 || numbers[0] >= 224 { return .failure(.notAnAddress) }
            if numbers[0] == 10 { return .success(HostClass(reach: .home, isNumber: true)) }
            if numbers[0] == 172 && numbers[1] >= 16 && numbers[1] <= 31 { return .success(HostClass(reach: .home, isNumber: true)) }
            if numbers[0] == 192 && numbers[1] == 168 { return .success(HostClass(reach: .home, isNumber: true)) }
            if numbers[0] == 169 && numbers[1] == 254 { return .success(HostClass(reach: .home, isNumber: true)) }
            if numbers[0] == 100 && numbers[1] >= 64 && numbers[1] <= 127 { return .success(HostClass(reach: .tailscale, isNumber: true)) }
            return .success(HostClass(reach: .internet, isNumber: true))
        }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-.")
        guard host.allSatisfy({ allowed.contains($0) }), !host.hasPrefix("."), !host.hasPrefix("-"), !host.hasSuffix("-") else { return .failure(.notAnAddress) }
        if host.allSatisfy(isDigit) { return .failure(.notAnAddress) }
        if host.hasSuffix(".local") && host.count > ".local".count { return .success(HostClass(reach: .home, isNumber: false)) }
        if !host.contains(".") { return .success(HostClass(reach: .home, isNumber: false)) }
        guard !host.hasSuffix("."), !host.contains("..") else { return .failure(.notAnAddress) }
        if host.hasSuffix(".ts.net") && host.count > ".ts.net".count { return .success(HostClass(reach: .tailscale, isNumber: false)) }
        return .success(HostClass(reach: .internet, isNumber: false))
    }
}

/// What the person typed for Ollama, kept in the phone's settings like the AI switch (not in a backup, and Clear
/// all data leaves it). Nothing connects to the address while AI tools are off.
enum OllamaSettings {
    static let addressKey = "aiOllamaAddress"
    static let modelKey = "aiOllamaModel"

    static var address: String {
        get { LockedSetting.string(addressKey) }
        set { LockedSetting.setString(newValue, key: addressKey) }
    }

    static var model: String {
        get { LockedSetting.string(modelKey) }
        set { LockedSetting.setString(newValue, key: modelKey) }
    }

    // An address away from the home network is held back until the person has confirmed that address (Patch AI8,
    // D56). The confirmation is the address itself, so it belongs to that one address: a different one, or the same
    // one typed again after another, is asked about again. It is kept in the phone's settings like the rest.
    static let confirmedKey = "aiOllamaConfirmedAway"

    static var confirmedAway: String {
        LockedSetting.string(confirmedKey)
    }

    /// True for an address on the home network, and for an away address the person has confirmed.
    static func isConfirmed(_ endpoint: OllamaEndpoint, in defaults: UserDefaults = .standard) -> Bool {
        !endpoint.isAway || LockedSetting.string(confirmedKey, in: defaults) == endpoint.confirmationKey
    }

    static func confirm(_ endpoint: OllamaEndpoint, in defaults: UserDefaults = .standard) {
        guard endpoint.isAway else { return }
        LockedSetting.setString(endpoint.confirmationKey, key: confirmedKey, in: defaults)
    }

    /// Called as the address is typed: the confirmation stays only while what is typed is the confirmed address.
    static func keepConfirmation(onlyFor typed: String, in defaults: UserDefaults = .standard) {
        if case .success(let endpoint) = OllamaEndpoint.parse(typed), LockedSetting.string(confirmedKey, in: defaults) == endpoint.confirmationKey {
            return
        }
        defaults.removeObject(forKey: confirmedKey)
    }
}

private struct OllamaChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
    let stream: Bool
}

private struct OllamaChatReply: Decodable {
    struct Message: Decodable {
        let content: String
    }
    let message: Message?
}

private struct OllamaTags: Decodable {
    struct Model: Decodable {
        let name: String
    }
    let models: [Model]
}

/// The two ways Anchor talks to Ollama: asking it to answer (through `OllamaProvider`, only after the consent
/// sheet) and asking which models it has (only when the person taps Look for models, and sending none of their
/// words). It uses a private session that keeps nothing. An address on the home network never uses the mobile
/// network. An address the person confirmed as away from home may, because that is how it is reached (Patch AI8).
enum OllamaClient {
    private static func makeSession(allowsCellular: Bool) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.allowsCellularAccess = allowsCellular
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 180
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }

    private static let homeSession = makeSession(allowsCellular: false)
    private static let awaySession = makeSession(allowsCellular: true)

    fileprivate static func send(_ request: URLRequest, reach: OllamaReach) async throws -> (Data, HTTPURLResponse) {
        let session = reach.isAway ? awaySession : homeSession
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AIError.failed }
            return (data, http)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw AIError.cannotReach
        }
    }

    /// The models on the computer, by name. It sends a question and none of the person's words. An address away
    /// from home is asked only after it has been confirmed.
    static func models(at endpoint: OllamaEndpoint) async throws -> [String] {
        guard AIGate.isEnabled else { throw AIError.off }
        guard OllamaSettings.isConfirmed(endpoint) else { throw AIError.unavailable(.addressNotConfirmed) }
        var request = URLRequest(url: endpoint.base.appendingPathComponent("api/tags"))
        request.timeoutInterval = 10
        let (data, http) = try await send(request, reach: endpoint.reach)
        guard http.statusCode == 200, let tags = try? JSONDecoder().decode(OllamaTags.self, from: data) else { throw AIError.failed }
        return tags.models.map { $0.name }.sorted()
    }

    /// Some models put their thinking in the answer between think tags. That is not the answer, so it comes off.
    static func cleaned(_ answer: String) -> String {
        var result = answer
        while let open = result.range(of: "<think>"), let close = result.range(of: "</think>", range: open.upperBound..<result.endIndex) {
            result.removeSubrange(open.lowerBound..<close.upperBound)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Ollama on the person's own computer (Patch AI5, D42). The person types its address and a model name in
/// Settings, AI tools. Nothing connects while AI tools are off, and the first connection is what makes the phone
/// ask about the local network, so that is asked only on first use. `AIAsk` calls it after the consent sheet,
/// which shows the address the text is going to.
struct OllamaProvider: AIProviding {
    let kind = AIProviderKind.ollama

    /// A guess to be checked with a real model: Ollama's default window is a few thousand words and the answer
    /// shares it with the text and the instruction, so the text is held below it.
    let maxCharacters = 8000

    let address: String
    let model: String

    init(address: String = OllamaSettings.address, model: String = OllamaSettings.model) {
        self.address = address
        self.model = model
    }

    private var modelName: String { model.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var parsedEndpoint: OllamaEndpoint? {
        if case .success(let found) = OllamaEndpoint.parse(address) { return found }
        return nil
    }

    var destination: String? {
        guard let found = parsedEndpoint else { return nil }
        return found.display + ", model " + modelName
    }

    var destinationNote: String? {
        parsedEndpoint?.reach.sheetNote
    }

    func status() -> AIProviderStatus {
        guard AIGate.isEnabled else { return .aiToolsOff }
        guard let found = parsedEndpoint else { return .notSetUp }
        guard OllamaSettings.isConfirmed(found) else { return .addressNotConfirmed }
        guard !modelName.isEmpty else { return .notSetUp }
        return .ready
    }

    func generate(instruction: String, text: String) async throws -> String {
        guard AIGate.isEnabled else { throw AIError.off }
        guard let endpoint = parsedEndpoint else { throw AIError.unavailable(.notSetUp) }
        guard OllamaSettings.isConfirmed(endpoint) else { throw AIError.unavailable(.addressNotConfirmed) }
        guard !modelName.isEmpty else { throw AIError.unavailable(.notSetUp) }
        var request = URLRequest(url: endpoint.base.appendingPathComponent("api/chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(OllamaChatRequest(
            model: modelName,
            messages: [
                .init(role: "system", content: instruction),
                .init(role: "user", content: text)
            ],
            stream: false
        ))
        let (data, http) = try await OllamaClient.send(request, reach: endpoint.reach)
        if http.statusCode == 404 { throw AIError.modelNotFound }
        guard http.statusCode == 200,
              let reply = try? JSONDecoder().decode(OllamaChatReply.self, from: data),
              let content = reply.message?.content
        else { throw AIError.failed }
        return OllamaClient.cleaned(content)
    }
}

/// Why a typed address for an Other provider is not accepted (Patch AI6).
enum OtherAddressProblem: Error, Equatable {
    case empty
    case notAnAddress
    case needsHTTPS
    case thisPhone

    var plainText: String {
        switch self {
        case .empty: return "Type the address of the service, starting with https://."
        case .notAnAddress: return "That does not look like an address Anchor can use. It needs a name with a dot in it, and no name, password, question mark or # in it."
        case .needsHTTPS: return "The address has to start with https://, because your key goes with it."
        case .thisPhone: return "That points at this phone. Use the address of the service."
        }
    }
}

/// The address of an Other provider, in the common chat completions format. Only https is accepted, because a key
/// goes with every request. Anything typed after the host, such as /v1, is kept, and `/chat/completions` is added
/// to it (and is not added twice if it was typed). Nothing here connects to anything (Patch AI6).
struct OtherEndpoint: Equatable {
    let url: URL
    let display: String

    static func parse(_ typed: String) -> Result<OtherEndpoint, OtherAddressProblem> {
        var text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .failure(.empty) }
        let lower = text.lowercased()
        if lower.hasPrefix("http://") { return .failure(.needsHTTPS) }
        if !lower.hasPrefix("https://") {
            if text.contains("://") { return .failure(.notAnAddress) }
            text = "https://" + text
        }
        guard let parts = URLComponents(string: text), parts.scheme?.lowercased() == "https",
              let rawHost = parts.host, !rawHost.isEmpty
        else { return .failure(.notAnAddress) }
        guard parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil else {
            return .failure(.notAnAddress)
        }
        let host = rawHost.lowercased()
        if host == "localhost" || host.hasPrefix("127.") || host == "0.0.0.0" || host == "::1" || host == "::" {
            return .failure(.thisPhone)
        }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-.")
        guard host.allSatisfy({ allowed.contains($0) }), host.contains("."), !host.hasPrefix("."), !host.hasSuffix("."),
              !host.hasPrefix("-"), !host.contains("..")
        else { return .failure(.notAnAddress) }
        var port: Int?
        if let given = parts.port {
            guard given >= 1 && given <= 65535 else { return .failure(.notAnAddress) }
            port = given
        }
        var path = parts.path
        while path.hasSuffix("/") { path.removeLast() }
        if path.lowercased().hasSuffix("/chat/completions") {
            path.removeLast("/chat/completions".count)
            while path.hasSuffix("/") { path.removeLast() }
        }
        if !path.isEmpty && !path.hasPrefix("/") { return .failure(.notAnAddress) }
        var build = URLComponents()
        build.scheme = "https"
        build.host = host
        build.port = port
        build.path = path + "/chat/completions"
        guard let url = build.url else { return .failure(.notAnAddress) }
        let shown = "https://" + host + (port.map { ":" + String($0) } ?? "") + path
        return .success(OtherEndpoint(url: url, display: shown))
    }
}

/// The key for an Other provider is kept in the phone's Keychain, on this phone only: it is not in a backup, not in
/// the settings the app keeps, and never in an export (Patch AI6). It is read only to go in the Authorization line of
/// a request that the person has just agreed to send, and to fill the key field in Settings, AI tools.
enum OtherKeychain {
    static let service = "page.aspens.anchor.ai"
    static let defaultAccount = "otherProviderKey"

    private static func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func read(account: String = defaultAccount) -> String {
        var request = query(account)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Saves the key, or removes it when nothing is left after trimming spaces and new lines.
    @discardableResult
    static func write(_ key: String, account: String = defaultAccount) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return remove(account: account) }
        guard let data = trimmed.data(using: .utf8) else { return false }
        var attributes = query(account)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        var status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let change: [String: Any] = [kSecValueData as String: data]
            status = SecItemUpdate(query(account) as CFDictionary, change as CFDictionary)
        }
        return status == errSecSuccess
    }

    @discardableResult
    static func remove(account: String = defaultAccount) -> Bool {
        let status = SecItemDelete(query(account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

/// The five typed AI settings that Lock my data seals (Patch 35g4). Kept here so the Lock my data file never has to
/// name a provider.
enum AITypedSettingKeys {
    static var all: [String] {
        [OllamaSettings.addressKey, OllamaSettings.modelKey, OllamaSettings.confirmedKey, OtherSettings.addressKey, OtherSettings.modelKey]
    }
    static var address: String { OllamaSettings.addressKey }
}

/// What the person typed for an Other provider. The address and model name are kept in the phone's settings like
/// the AI switch (not in a backup, and Clear all data leaves them). The key is in the Keychain (`OtherKeychain`).
/// All three are empty to begin with, and nothing connects to the address while AI tools are off.
enum OtherSettings {
    static let addressKey = "aiOtherAddress"
    static let modelKey = "aiOtherModel"

    static var address: String {
        get { LockedSetting.string(addressKey) }
        set { LockedSetting.setString(newValue, key: addressKey) }
    }

    static var model: String {
        get { LockedSetting.string(modelKey) }
        set { LockedSetting.setString(newValue, key: modelKey) }
    }

    static var key: String { OtherKeychain.read() }

    static var hasKey: Bool { !OtherKeychain.read().isEmpty }

    static func setKey(_ newValue: String) {
        OtherKeychain.write(newValue)
    }

    static func removeKey() {
        OtherKeychain.remove()
    }
}

private struct OtherChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
    let stream: Bool
}

private struct OtherChatReply: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message?
    }
    let choices: [Choice]?
}

/// Never follows a redirect. A request that carries a key goes to the address the person typed and nowhere else,
/// so an answer that points somewhere new is treated as a failure (Patch AI6).
private final class OtherNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// How Anchor talks to an Other provider: one request to ask for an answer, only through `OtherProvider` and only
/// after the consent sheet. It uses a private session that keeps nothing, no cookies and no cache.
enum OtherClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.allowsCellularAccess = true
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 180
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        return URLSession(configuration: config, delegate: OtherNoRedirect(), delegateQueue: nil)
    }()

    /// The request for one answer. The key goes in the Authorization line and nowhere else.
    static func makeRequest(endpoint: OtherEndpoint, key: String, model: String, instruction: String, text: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(OtherChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: instruction),
                .init(role: "user", content: text)
            ],
            stream: false
        ))
        return request
    }

    /// The answer in a reply, with any thinking taken off, or nil when the reply holds none.
    static func answer(in data: Data) -> String? {
        guard let reply = try? JSONDecoder().decode(OtherChatReply.self, from: data),
              let content = reply.choices?.first?.message?.content
        else { return nil }
        return OllamaClient.cleaned(content)
    }

    fileprivate static func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AIError.failed }
            return (data, http)
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw AIError.cannotReachProvider
        }
    }
}

/// A provider the person added themselves, in the common chat completions format (Patch AI6, D42). It is empty to
/// begin with and is never suggested, named or chosen for the person. `AIAsk` calls it after the consent sheet,
/// which is shown every time and never offers Don't ask again for this provider.
struct OtherProvider: AIProviding {
    let kind = AIProviderKind.other

    /// A guess to be checked with a real provider, held the same as Ollama's.
    let maxCharacters = 8000

    let address: String
    let model: String

    init(address: String = OtherSettings.address, model: String = OtherSettings.model) {
        self.address = address
        self.model = model
    }

    private var modelName: String { model.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var parsedEndpoint: OtherEndpoint? {
        if case .success(let found) = OtherEndpoint.parse(address) { return found }
        return nil
    }

    var destination: String? {
        guard let found = parsedEndpoint else { return nil }
        return found.display + ", model " + modelName
    }

    func status() -> AIProviderStatus {
        guard AIGate.isEnabled else { return .aiToolsOff }
        guard parsedEndpoint != nil, !modelName.isEmpty, OtherSettings.hasKey else { return .otherNotSetUp }
        return .ready
    }

    func generate(instruction: String, text: String) async throws -> String {
        guard AIGate.isEnabled else { throw AIError.off }
        guard let endpoint = parsedEndpoint, !modelName.isEmpty else { throw AIError.unavailable(.otherNotSetUp) }
        let key = OtherSettings.key
        guard !key.isEmpty else { throw AIError.unavailable(.otherNotSetUp) }
        let request = try OtherClient.makeRequest(endpoint: endpoint, key: key, model: modelName, instruction: instruction, text: text)
        let (data, http) = try await OtherClient.send(request)
        switch http.statusCode {
        case 200: break
        case 401, 403: throw AIError.keyRefused
        case 404: throw AIError.providerNotFound
        case 429: throw AIError.providerBusy
        default: throw AIError.failed
        }
        guard let answer = OtherClient.answer(in: data) else { throw AIError.failed }
        return answer
    }
}

#if DEBUG
/// Checks, in a test build, which typed addresses are accepted for Ollama, which are away from home, that a
/// confirmation belongs to one address, and that its thinking is taken off an answer. Nothing here connects to
/// anything. Patches AI5 and AI8.
enum OllamaSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Ollama self-test: \(message)") }
    }

    private static func display(_ typed: String) -> String? {
        if case .success(let endpoint) = OllamaEndpoint.parse(typed) { return endpoint.display }
        return nil
    }

    private static func reach(_ typed: String) -> OllamaReach? {
        if case .success(let endpoint) = OllamaEndpoint.parse(typed) { return endpoint.reach }
        return nil
    }

    private static func problem(_ typed: String) -> OllamaAddressProblem? {
        if case .failure(let problem) = OllamaEndpoint.parse(typed) { return problem }
        return nil
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        check(display("192.168.1.20") == "192.168.1.20:11434", "a home number gets the usual port")
        check(display(" http://10.0.0.5:8080/ ") == "10.0.0.5:8080", "a typed port and a trailing slash are kept and tidied")
        check(display("172.16.4.2") != nil && display("172.31.255.1") != nil && display("169.254.1.1") != nil, "private ranges are accepted")
        check(display("My-Mac.local") == "my-mac.local:11434", "a .local name is accepted")
        check(display("my-mac") == "my-mac:11434", "a single name is accepted")
        check(reach("192.168.1.20") == .home && reach("my-mac.local") == .home && reach("my-mac") == .home, "these are the home network")
        check(reach("fd12:3456::1") == .home && reach("fe80::1") == .home, "private and link-local IPv6 are the home network")
        // Away from home (Patch AI8, D56): accepted, but marked away.
        check(reach("100.101.102.103") == .tailscale && display("100.101.102.103") == "100.101.102.103:11434", "a Tailscale number is away, over plain http")
        check(reach("100.64.0.1") == .tailscale && reach("100.127.255.254") == .tailscale, "the whole Tailscale range is away")
        check(reach("100.63.255.255") == .internet && reach("100.128.0.1") == .internet, "just outside the Tailscale range is the internet")
        check(reach("fd7a:115c:a1e0::1") == .tailscale && display("fd7a:115c:a1e0::1") == "[fd7a:115c:a1e0::1]:11434", "a Tailscale IPv6 address is away, and shown in brackets")
        check(display("[fd7a:115c:a1e0:ab12::7]:8080") == "[fd7a:115c:a1e0:ab12::7]:8080", "a bracketed IPv6 address keeps its port")
        check(reach("my-mac.tail1234.ts.net") == .tailscale && display("my-mac.tail1234.ts.net") == "https://my-mac.tail1234.ts.net:443", "a Tailscale name is away and uses https")
        check(reach("172.32.0.1") == .internet && display("8.8.8.8") == "https://8.8.8.8:443", "a public number is away and uses https")
        check(reach("2001:db8::1") == .internet && display("2001:db8::1") == "https://[2001:db8::1]:443", "a public IPv6 address is away and uses https")
        check(reach("example.com") == .internet && display("https://example.com:8443") == "https://example.com:8443", "a public name is away and uses https")
        check(problem("http://example.com") == .needsHTTPS && problem("http://anchor.aspens.page") == .needsHTTPS, "plain http to a public name is refused")
        check(problem("http://8.8.8.8") == .needsHTTPS && problem("http://172.32.0.1") == .needsHTTPS, "plain http to a public number is refused")
        check(problem("http://[2001:db8::1]") == .needsHTTPS && problem("http://my-mac.tail1234.ts.net") == .needsHTTPS, "plain http to a public IPv6 address or a Tailscale name is refused")
        check(display("https://192.168.1.20") == "https://192.168.1.20:443", "https is kept when typed, with the https port")
        check(problem("localhost") == .thisPhone && problem("127.0.0.1") == .thisPhone, "this phone is refused")
        check(problem("::1") == .thisPhone && problem("[::1]:11434") == .thisPhone && problem("::") == .thisPhone, "this phone, in IPv6, is refused")
        check(problem("") == .empty && problem("   ") == .empty, "nothing typed")
        check(problem("192.168.1.20/api") == .notAnAddress, "a path is refused")
        check(problem("http://user:pw@192.168.1.20") == .notAnAddress, "a name and password are refused")
        check(problem("300.1.1.1") == .notAnAddress && problem("192") == .notAnAddress && problem("224.0.0.1") == .notAnAddress, "not an address")
        check(problem("ftp://192.168.1.20") == .notAnAddress, "only http and https")
        check(problem("ff02::1") == .notAnAddress && problem("1:2:3") == .notAnAddress && problem("fe80::1%en0") == .notAnAddress, "not a usable IPv6 address")
        check(problem("192.168.1.20:99999") == .notAnAddress, "a port out of range")
        check(OllamaEndpoint.ipv6Groups("::") == [0, 0, 0, 0, 0, 0, 0, 0] && OllamaEndpoint.ipv6Groups("1::2") == [1, 0, 0, 0, 0, 0, 0, 2], "IPv6 groups fill in the gap")
        check(OllamaEndpoint.ipv6Groups("1:2:3:4:5:6:7:8") == [1, 2, 3, 4, 5, 6, 7, 8] && OllamaEndpoint.ipv6Groups("1:2:3:4:5:6:7:8:9") == nil, "eight groups and no more")
        // The confirmation belongs to one away address (Patch AI8).
        let suite = "page.aspens.anchor.ollama-selftest"
        if let defaults = UserDefaults(suiteName: suite) {
            defaults.removePersistentDomain(forName: suite)
            if case .success(let away) = OllamaEndpoint.parse("100.101.102.103"), case .success(let home) = OllamaEndpoint.parse("192.168.1.20") {
                check(OllamaSettings.isConfirmed(home, in: defaults), "the home network needs no confirmation")
                check(!OllamaSettings.isConfirmed(away, in: defaults), "an away address waits for a confirmation")
                OllamaSettings.confirm(away, in: defaults)
                check(OllamaSettings.isConfirmed(away, in: defaults), "a confirmed away address is used")
                OllamaSettings.keepConfirmation(onlyFor: "100.101.102.103", in: defaults)
                check(OllamaSettings.isConfirmed(away, in: defaults), "the same address keeps its confirmation")
                OllamaSettings.keepConfirmation(onlyFor: "100.101.102.104", in: defaults)
                check(!OllamaSettings.isConfirmed(away, in: defaults), "a different address loses it")
            } else {
                check(false, "the test addresses should parse")
            }
            defaults.removePersistentDomain(forName: suite)
        }
        check(OllamaClient.cleaned("<think>hmm</think>\nHello there ") == "Hello there", "thinking comes off")
        check(OllamaClient.cleaned("Plain answer") == "Plain answer", "a plain answer is left alone")
        check(OllamaClient.cleaned("<think>never closed Hello") == "<think>never closed Hello", "an unclosed tag is left alone")
    }
}
#endif

#if DEBUG
/// Checks, in a test build, which typed addresses are accepted for an Other provider, that the request carries the
/// key only in the Authorization line, that an answer is read out of a reply, that the key is kept in the
/// Keychain and can be removed, and that Don't ask again is never kept for this provider. Nothing here connects to
/// anything, and the Keychain test uses its own entry, never the real key. Patch AI6.
enum OtherProviderSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Other provider self-test: \(message)") }
    }

    private static func display(_ typed: String) -> String? {
        if case .success(let endpoint) = OtherEndpoint.parse(typed) { return endpoint.display }
        return nil
    }

    private static func url(_ typed: String) -> String? {
        if case .success(let endpoint) = OtherEndpoint.parse(typed) { return endpoint.url.absoluteString }
        return nil
    }

    private static func problem(_ typed: String) -> OtherAddressProblem? {
        if case .failure(let problem) = OtherEndpoint.parse(typed) { return problem }
        return nil
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        check(url("https://api.example.com/v1") == "https://api.example.com/v1/chat/completions", "the path is kept and the chat address is added")
        check(url(" https://API.example.com/v1/ ") == "https://api.example.com/v1/chat/completions", "spaces, capitals and a trailing slash are tidied")
        check(url("https://api.example.com/v1/chat/completions") == "https://api.example.com/v1/chat/completions", "the chat address is not added twice")
        check(url("api.example.com/v1") == "https://api.example.com/v1/chat/completions", "no scheme means https")
        check(url("https://api.example.com") == "https://api.example.com/chat/completions", "no path is allowed")
        check(display("https://api.example.com:8443/v1") == "https://api.example.com:8443/v1", "a port is kept and shown")
        check(problem("http://api.example.com/v1") == .needsHTTPS, "plain http is refused")
        check(problem("HTTP://192.168.1.20") == .needsHTTPS, "plain http is refused in capitals and to a home number")
        check(problem("") == .empty && problem("   ") == .empty, "nothing typed")
        check(problem("https://localhost/v1") == .thisPhone && problem("https://127.0.0.1") == .thisPhone, "this phone is refused")
        check(problem("https://user:pw@api.example.com") == .notAnAddress, "a name and password are refused")
        check(problem("https://api.example.com/v1?key=abc") == .notAnAddress, "a question mark is refused, so no key rides in the address")
        check(problem("https://api.example.com/v1#top") == .notAnAddress, "a # is refused")
        check(problem("https://myserver") == .notAnAddress, "a name with no dot is refused")
        check(problem("ftp://api.example.com") == .notAnAddress, "only https")
        check(problem("https://api.example.com:99999") == .notAnAddress, "a port out of range")
        check(problem("https://api example.com") == .notAnAddress, "a space inside the name")

        guard case .success(let endpoint) = OtherEndpoint.parse("https://api.example.com/v1"),
              let request = try? OtherClient.makeRequest(endpoint: endpoint, key: "sk-test-123", model: "some-model", instruction: "Do it.", text: "Hello")
        else { check(false, "the request should be made"); return }
        check(request.httpMethod == "POST" && request.url == endpoint.url, "it is a post to the chat address")
        check(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-123", "the key is in the Authorization line")
        check(!(request.url?.absoluteString ?? "").contains("sk-test-123"), "the key is not in the address")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        check(!body.contains("sk-test-123"), "the key is not in the body")
        check(body.contains("\"model\":\"some-model\"") && body.contains("\"stream\":false") && body.contains("\"role\":\"system\"") && body.contains("Hello"), "the body holds the model, the instruction and the text")

        check(OtherClient.answer(in: Data(#"{"choices":[{"message":{"role":"assistant","content":"<think>hm</think> Short."}}]}"#.utf8)) == "Short.", "the answer is read and its thinking taken off")
        check(OtherClient.answer(in: Data(#"{"choices":[]}"#.utf8)) == nil, "no choice, no answer")
        check(OtherClient.answer(in: Data(#"{"choices":[{"message":{"content":null}}]}"#.utf8)) == nil, "an empty content is no answer")
        check(OtherClient.answer(in: Data("not json".utf8)) == nil, "something else is no answer")

        let testAccount = "otherProviderKey.selftest"
        OtherKeychain.remove(account: testAccount)
        check(OtherKeychain.read(account: testAccount).isEmpty, "no key to begin with")
        check(OtherKeychain.write("  abc123 \n", account: testAccount) && OtherKeychain.read(account: testAccount) == "abc123", "a key is kept, trimmed")
        check(OtherKeychain.write("def456", account: testAccount) && OtherKeychain.read(account: testAccount) == "def456", "a key can be replaced")
        check(OtherKeychain.write("   ", account: testAccount) && OtherKeychain.read(account: testAccount).isEmpty, "an emptied key is removed")
        OtherKeychain.remove(account: testAccount)

        check(!AIProviderKind.other.offersDontAskAgain, "Don't ask again is never offered for this provider")
        let suite = "page.aspens.anchor.other-selftest"
        if let defaults = UserDefaults(suiteName: suite) {
            defaults.removePersistentDomain(forName: suite)
            let store = AIConsentStore(defaults: defaults)
            store.setSkipsAsking(true, .makeShorter, .other)
            check(!store.skipsAsking(.makeShorter, .other) && store.all.isEmpty, "a skip is never kept for this provider")
            defaults.set(["makeShorter|other"], forKey: AIConsentStore.key)
            check(!store.skipsAsking(.makeShorter, .other) && store.all.isEmpty, "a skip written by hand is ignored")
            defaults.removePersistentDomain(forName: suite)
        }
    }
}
#endif

/// Reads what a model answered into the small pieces a tool shows as suggestions (Patch AI3). Nothing here sends
/// anything or keeps anything; the caller shows the pieces and the person decides.
enum AIAnswerReader {
    /// One step per line, with any bullet or number the model added taken off, blank and repeated lines dropped,
    /// and at most `limit` of them. Nothing is cut short or reworded.
    static func steps(from answer: String, limit: Int = 8) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in answer.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            while let first = line.first, "-*\u{2022}\u{2013}\u{2014}".contains(first) {
                line.removeFirst()
                line = line.trimmingCharacters(in: .whitespaces)
            }
            if let marker = line.range(of: #"^\d{1,2}[.)]\s+"#, options: .regularExpression) {
                line.removeSubrange(marker)
            }
            line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, seen.insert(line.lowercased()).inserted else { continue }
            result.append(line)
            if result.count == limit { break }
        }
        return result
    }

    /// The lines of a list for Turn into tasks or Turn into things to raise: the same reading as steps, with room for
    /// twelve. Each line is shown to be ticked before anything is made from it.
    static func items(from answer: String, limit: Int = 12) -> [String] {
        steps(from: answer, limit: limit)
    }

    /// A guess in minutes, rounded to the nearest 5 and held between 5 and 480, or nil when the answer is not
    /// plainly a number of minutes (for instance, when it talks about hours).
    static func minutes(from answer: String) -> Int? {
        let lower = answer.lowercased()
        guard !lower.contains("hour"), !lower.contains("hr") else { return nil }
        guard let range = lower.range(of: #"\d+"#, options: .regularExpression), let value = Int(lower[range]), value > 0 else { return nil }
        let rounded = Int((Double(value) / 5).rounded()) * 5
        return min(480, max(5, rounded))
    }
}

#if DEBUG
/// Checks, in a test build, how a model's answer is read into suggestions: bullets, numbers and repeats come off,
/// the count is held, and a number of minutes is rounded and bounded or refused. Patch AI3.
enum AIAnswerReaderSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("AI answer reader self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        let steps = AIAnswerReader.steps(from: "1. Find the form\n- Fill it in\n\u{2022} Fill it in\n\n  2) Post it\n")
        check(steps == ["Find the form", "Fill it in", "Post it"], "marks, blanks and repeats come off")
        check(AIAnswerReader.steps(from: (1...12).map { "Step \($0)" }.joined(separator: "\n")).count == 8, "at most eight")
        check(AIAnswerReader.steps(from: "  \n ").isEmpty, "nothing in, nothing out")
        check(AIAnswerReader.items(from: (1...20).map { "Task \($0)" }.joined(separator: "\n")).count == 12, "at most twelve in a list")
        check(AIAnswerReader.items(from: "- Ring the clinic\n2. Ring the clinic\n") == ["Ring the clinic"], "a list reads like steps")
        check(AIAnswerReader.minutes(from: "17") == 15 && AIAnswerReader.minutes(from: "About 20 minutes") == 20, "rounded to five")
        check(AIAnswerReader.minutes(from: "1") == 5 && AIAnswerReader.minutes(from: "9000") == 480, "held between 5 and 480")
        check(AIAnswerReader.minutes(from: "2 hours") == nil && AIAnswerReader.minutes(from: "no idea") == nil && AIAnswerReader.minutes(from: "0") == nil, "not plainly minutes is refused")
    }
}
#endif
