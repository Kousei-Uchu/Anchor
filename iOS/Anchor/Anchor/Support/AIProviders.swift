import Foundation
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

    /// The plain name of the button, and of the tool in the list of ones that no longer ask.
    var title: String {
        switch self {
        case .makeShorter: return "Make shorter"
        case .breakIntoSteps: return "Break into steps"
        case .estimateTime: return "Estimate time"
        case .turnIntoTasks: return "Turn into tasks"
        case .turnIntoThingsToRaise: return "Turn into things to raise"
        }
    }

    /// The fixed instruction that goes with the text. It says what to keep and what never to add.
    var instruction: String {
        switch self {
        case .makeShorter:
            return "Make this text shorter. Keep every concrete detail, name, number and date, and keep who said what. Add nothing: no advice, no comment on feelings, no new facts. Use the same voice and the same language as the text. Reply with the shorter text only."
        case .breakIntoSteps:
            return "Break this task into a short list of small steps, in the order they would be done. Use only what the text says or plainly needs. Add no dates, no priorities, no advice and no comment on feelings. Write one step per line, with no numbers, bullets or other words, and at most 8 lines. Use the same language as the text."
        case .estimateTime:
            return "Guess how many minutes this task takes to do. Reply with one whole number of minutes and nothing else."
        case .turnIntoTasks:
            return "Turn this text into a short list of tasks the writer said they need to do or plainly meant to do. Use only what the text says. Add no tasks of your own, no dates, no priorities, no advice and no comment on feelings. Write one task per line, as a short action, with no numbers, bullets or other words, and at most 12 lines. If the text holds nothing to do, reply with nothing. Use the same language as the text."
        case .turnIntoThingsToRaise:
            return "Turn this text into a short list of things the writer wants to bring up in an appointment or session. Keep each one in the writer's own words as far as you can. Use only what the text says. Add nothing: no advice, no diagnosis, no comment on feelings, no new facts. Write one item per line, with no numbers, bullets or other words, at most 12 lines, and keep each under 160 characters. If the text holds nothing to bring up, reply with nothing. Use the same language as the text."
        }
    }
}

/// Where a tool can run. Apple's model on the phone, and Ollama on the person's own computer (Patch AI5). A
/// provider the person adds themselves (AI6) is added here when it is built.
enum AIProviderKind: String, CaseIterable {
    case apple
    case ollama

    var name: String {
        switch self {
        case .apple: return "Apple's on-device model"
        case .ollama: return "Ollama on your computer"
        }
    }

    /// The short place name used on the Settings screen.
    var placeName: String {
        switch self {
        case .apple: return "On this phone"
        case .ollama: return "On my computer"
        }
    }

    /// Where the text goes, in the words the consent sheet uses.
    var whereItRuns: String {
        switch self {
        case .apple: return "On this phone. The text does not leave it."
        case .ollama: return "On your own computer, at the address below. The text goes there as it is and nowhere else."
        }
    }

    /// What the provider does with the text, as far as Anchor can say.
    var keeping: String {
        switch self {
        case .apple: return "It is held in memory on this phone until you keep or discard the answer. Anchor keeps no log of it."
        case .ollama: return "Ollama holds it on your computer while it works. Anchor keeps no log of it. What Ollama keeps is set on your computer, and Anchor cannot see it."
        }
    }

    /// Whether the consent sheet offers Don't ask again. Never for a provider the person added themselves (D42).
    var offersDontAskAgain: Bool {
        switch self {
        case .apple: return true
        case .ollama: return true
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

    func generate(instruction: String, text: String) async throws -> String {
        guard AIGate.isEnabled else { throw AIError.off }
        #if canImport(FoundationModels)
        let session = LanguageModelSession(instructions: instruction)
        let response = try await session.respond(to: text)
        return response.content
        #else
        throw AIError.unavailable(.unavailable)
        #endif
    }
}

/// Why a typed address is not accepted, in words the person can act on (Patch AI5, AI8).
enum OllamaAddressProblem: Equatable {
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
        get { UserDefaults.standard.string(forKey: addressKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: addressKey) }
    }

    static var model: String {
        get { UserDefaults.standard.string(forKey: modelKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: modelKey) }
    }

    // An address away from the home network is held back until the person has confirmed that address (Patch AI8,
    // D56). The confirmation is the address itself, so it belongs to that one address: a different one, or the same
    // one typed again after another, is asked about again. It is kept in the phone's settings like the rest.
    static let confirmedKey = "aiOllamaConfirmedAway"

    static var confirmedAway: String {
        UserDefaults.standard.string(forKey: confirmedKey) ?? ""
    }

    /// True for an address on the home network, and for an away address the person has confirmed.
    static func isConfirmed(_ endpoint: OllamaEndpoint, in defaults: UserDefaults = .standard) -> Bool {
        !endpoint.isAway || defaults.string(forKey: confirmedKey) == endpoint.confirmationKey
    }

    static func confirm(_ endpoint: OllamaEndpoint, in defaults: UserDefaults = .standard) {
        guard endpoint.isAway else { return }
        defaults.set(endpoint.confirmationKey, forKey: confirmedKey)
    }

    /// Called as the address is typed: the confirmation stays only while what is typed is the confirmed address.
    static func keepConfirmation(onlyFor typed: String, in defaults: UserDefaults = .standard) {
        if case .success(let endpoint) = OllamaEndpoint.parse(typed), defaults.string(forKey: confirmedKey) == endpoint.confirmationKey {
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
