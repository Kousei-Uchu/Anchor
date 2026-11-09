import Foundation
import SwiftUI

/// Which tools and places the person has said not to be asked about again (Patch AI1, D42). It is a list of
/// pairs, one tool at one place, kept in the phone's settings like the AI switch. Not asking again is never
/// offered for a provider the person added themselves.
struct AIConsentStore {
    static let key = "aiAskSkips"
    static let standard = AIConsentStore(defaults: .standard)

    struct Pair: Hashable {
        let feature: AIFeature
        let provider: AIProviderKind
    }

    let defaults: UserDefaults

    private func tag(_ feature: AIFeature, _ provider: AIProviderKind) -> String {
        feature.rawValue + "|" + provider.rawValue
    }

    func skipsAsking(_ feature: AIFeature, _ provider: AIProviderKind) -> Bool {
        guard provider.offersDontAskAgain else { return false }
        return (defaults.stringArray(forKey: Self.key) ?? []).contains(tag(feature, provider))
    }

    func setSkipsAsking(_ on: Bool, _ feature: AIFeature, _ provider: AIProviderKind) {
        var tags = defaults.stringArray(forKey: Self.key) ?? []
        tags.removeAll { $0 == tag(feature, provider) }
        if on && provider.offersDontAskAgain { tags.append(tag(feature, provider)) }
        defaults.set(tags, forKey: Self.key)
    }

    /// Every pair that no longer asks, for the list in Settings where each can be turned back on.
    var all: [Pair] {
        (defaults.stringArray(forKey: Self.key) ?? []).compactMap { entry in
            let parts = entry.split(separator: "|").map(String.init)
            guard parts.count == 2, let feature = AIFeature(rawValue: parts[0]), let provider = AIProviderKind(rawValue: parts[1]) else { return nil }
            guard provider.offersDontAskAgain else { return nil }
            return Pair(feature: feature, provider: provider)
        }
    }
}

/// What the consent sheet shows, in full, before anything is sent.
struct AIAskRequest: Identifiable {
    let id = UUID()
    let feature: AIFeature
    let provider: AIProviderKind
    /// The exact text that will be sent, and nothing else is sent with it but the instruction.
    let text: String
    let instruction: String
    /// The address and model when the text goes to the person's own computer (Patch AI5), shown on the sheet.
    let destination: String?
}

/// Runs one AI tool on one piece of text, with the person in charge of every step (Patch AI1). It checks the
/// gate, checks the text, shows the consent sheet unless the person said not to be asked, and only then sends
/// the text to the provider. The answer is returned and held nowhere: the caller shows it as a suggestion.
///
/// A screen that offers a tool keeps one of these, puts `.aiAsk(ask)` on a view, and calls `run`.
@MainActor
final class AIAsk: ObservableObject {
    @Published var pending: AIAskRequest?
    @Published private(set) var isWorking = false

    private let consent: AIConsentStore
    private let gate: () -> Bool
    private var decision: CheckedContinuation<Bool, Never>?
    private var generating: Task<String, Error>?
    private var observer: NSObjectProtocol?

    init(consent: AIConsentStore = .standard, gate: @escaping () -> Bool = { AIGate.isEnabled }) {
        self.consent = consent
        self.gate = gate
        observer = NotificationCenter.default.addObserver(forName: .aiToolsTurnedOff, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.dropEverything() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func run(_ feature: AIFeature, on text: String, using provider: AIProviding = AIProviders.make(AIProviders.chosen)) async throws -> String {
        guard gate() else { throw AIError.off }
        guard !isWorking else { throw AIError.busy }
        let sending = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sending.isEmpty else { throw AIError.nothingToSend }
        guard sending.count <= provider.maxCharacters else { throw AIError.tooLong(limit: provider.maxCharacters) }
        let status = provider.status()
        guard status == .ready else { throw AIError.unavailable(status) }

        isWorking = true
        defer { isWorking = false }

        if !consent.skipsAsking(feature, provider.kind) {
            let request = AIAskRequest(feature: feature, provider: provider.kind, text: sending, instruction: feature.instruction, destination: provider.destination)
            guard await askPerson(request) else { throw AIError.cancelled }
        }
        guard gate() else { throw AIError.off }

        let task = Task { try await provider.generate(instruction: feature.instruction, text: sending) }
        generating = task
        defer { generating = nil }
        let answer: String
        do {
            answer = try await task.value
        } catch is CancellationError {
            throw AIError.cancelled
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.failed
        }
        guard gate() else { throw AIError.off }
        guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AIError.failed }
        return answer
    }

    /// The sheet's answer. Send carries on, Cancel (or dismissing the sheet) stops. Don't ask again is kept
    /// only when the person sent, and only for a provider that offers it.
    func resolve(_ send: Bool, dontAskAgain: Bool = false) {
        guard let continuation = decision, let request = pending else { return }
        decision = nil
        pending = nil
        if send && dontAskAgain && request.provider.offersDontAskAgain {
            consent.setSkipsAsking(true, request.feature, request.provider)
        }
        continuation.resume(returning: send)
    }

    private func askPerson(_ request: AIAskRequest) async -> Bool {
        await withCheckedContinuation { continuation in
            decision = continuation
            pending = request
        }
    }

    /// AI tools were turned off: close the sheet and stop any work in progress.
    private func dropEverything() {
        generating?.cancel()
        if decision != nil { resolve(false) }
    }
}

#if DEBUG
/// Checks, in a test build, that the asking layer keeps its promises, with a made-up provider and a throwaway
/// settings store, so nothing real is read or sent: nothing reaches a provider while the gate is off, with no
/// text, with too long a text, or while the provider is not ready; the sheet's request holds the exact text and
/// nothing is sent until Send; Cancel sends nothing; Don't ask again is kept only after Send and then skips the
/// sheet; turning AI tools off while the sheet is open, or while the provider works, returns nothing; and an
/// empty answer is a failure. Patch AI1.
enum AIAskSelfTest {
    private static var hasRun = false

    private final class Fake: AIProviding, @unchecked Sendable {
        let kind = AIProviderKind.apple
        let maxCharacters = 50
        var ready = true
        var answer = "short"
        var delay: UInt64 = 0
        private(set) var calls = 0
        func status() -> AIProviderStatus { ready ? .ready : .notReady }
        func generate(instruction: String, text: String) async throws -> String {
            calls += 1
            if delay > 0 { try await Task.sleep(nanoseconds: delay) }
            return answer
        }
    }

    private final class Flag: @unchecked Sendable { var on = true }

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("AI ask self-test: \(message)") }
    }

    @MainActor
    private static func waitUntil(_ what: String, _ condition: () -> Bool) async {
        var waited = 0
        while !condition() {
            try? await Task.sleep(nanoseconds: 20_000_000)
            waited += 1
            check(waited < 150, "timed out waiting for \(what)")
        }
    }

    private static func thrown(by task: Task<String, Error>) async -> AIError? {
        do { _ = try await task.value; return nil } catch { return error as? AIError }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        Task { @MainActor in
            let suiteName = "page.aspens.anchor.selftest.ai"
            guard let defaults = UserDefaults(suiteName: suiteName) else { fatalError("AI ask self-test: no settings store.") }
            defaults.removePersistentDomain(forName: suiteName)
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let store = AIConsentStore(defaults: defaults)

            check(!store.skipsAsking(.makeShorter, .apple), "asks to begin with")
            check(store.all.isEmpty, "the list starts empty")
            store.setSkipsAsking(true, .makeShorter, .apple)
            check(store.skipsAsking(.makeShorter, .apple), "Don't ask again is kept")
            check(store.all == [AIConsentStore.Pair(feature: .makeShorter, provider: .apple)], "the list shows it")
            store.setSkipsAsking(false, .makeShorter, .apple)
            check(!store.skipsAsking(.makeShorter, .apple) && store.all.isEmpty, "asking again removes it")

            let fake = Fake()
            let flag = Flag()
            let ask = AIAsk(consent: store, gate: { flag.on })

            flag.on = false
            var failure: AIError?
            do { _ = try await ask.run(.makeShorter, on: "hello there", using: fake) } catch { failure = error as? AIError }
            check(failure == .off && fake.calls == 0, "the gate being off must stop everything")
            flag.on = true

            failure = nil
            do { _ = try await ask.run(.makeShorter, on: "   \n ", using: fake) } catch { failure = error as? AIError }
            check(failure == .nothingToSend && fake.calls == 0, "blank text must not be sent")

            failure = nil
            do { _ = try await ask.run(.makeShorter, on: String(repeating: "a", count: 51), using: fake) } catch { failure = error as? AIError }
            check(failure == .tooLong(limit: 50) && fake.calls == 0, "text over the limit must not be sent")

            fake.ready = false
            failure = nil
            do { _ = try await ask.run(.makeShorter, on: "hello there", using: fake) } catch { failure = error as? AIError }
            check(failure == .unavailable(.notReady) && fake.calls == 0, "a provider that is not ready must not be called")
            fake.ready = true

            var task = Task { @MainActor in try await ask.run(.makeShorter, on: "  hello there  ", using: fake) }
            await waitUntil("the sheet") { ask.pending != nil }
            check(ask.pending?.text == "hello there" && ask.pending?.instruction == AIFeature.makeShorter.instruction, "the sheet holds the exact text and instruction")
            check(fake.calls == 0, "nothing is sent while the sheet is open")
            ask.resolve(false)
            check(await thrown(by: task) == .cancelled && fake.calls == 0, "Cancel must send nothing")
            check(ask.pending == nil && !ask.isWorking, "Cancel closes the sheet")

            task = Task { @MainActor in try await ask.run(.makeShorter, on: "hello there", using: fake) }
            await waitUntil("the sheet") { ask.pending != nil }
            ask.resolve(false, dontAskAgain: true)
            _ = await thrown(by: task)
            check(!store.skipsAsking(.makeShorter, .apple), "Don't ask again is not kept after Cancel")

            task = Task { @MainActor in try await ask.run(.makeShorter, on: "hello there", using: fake) }
            await waitUntil("the sheet") { ask.pending != nil }
            ask.resolve(true, dontAskAgain: true)
            check((try? await task.value) == "short" && fake.calls == 1, "Send must send once and return the answer")
            check(store.skipsAsking(.makeShorter, .apple), "Don't ask again is kept after Send")

            let quiet = (try? await ask.run(.makeShorter, on: "hello there", using: fake)) ?? ""
            check(quiet == "short" && fake.calls == 2 && ask.pending == nil, "after Don't ask again the sheet is skipped")
            store.setSkipsAsking(false, .makeShorter, .apple)

            task = Task { @MainActor in try await ask.run(.makeShorter, on: "hello there", using: fake) }
            await waitUntil("the sheet") { ask.pending != nil }
            flag.on = false
            ask.resolve(true)
            check(await thrown(by: task) == .off && fake.calls == 2, "turning AI tools off while the sheet is open must send nothing")
            flag.on = true

            task = Task { @MainActor in try await ask.run(.makeShorter, on: "hello there", using: fake) }
            await waitUntil("the sheet") { ask.pending != nil }
            NotificationCenter.default.post(name: .aiToolsTurnedOff, object: nil)
            check(await thrown(by: task) == .cancelled && fake.calls == 2 && ask.pending == nil, "the off notice must close the sheet and send nothing")

            store.setSkipsAsking(true, .makeShorter, .apple)
            fake.delay = 400_000_000
            task = Task { @MainActor in try await ask.run(.makeShorter, on: "hello there", using: fake) }
            await waitUntil("the provider") { fake.calls == 3 }
            flag.on = false
            check(await thrown(by: task) == .off, "turning AI tools off while the provider works must return nothing")
            flag.on = true
            fake.delay = 0

            fake.answer = "  \n "
            failure = nil
            do { _ = try await ask.run(.makeShorter, on: "hello there", using: fake) } catch { failure = error as? AIError }
            check(failure == .failed, "an empty answer is a failure")
            check(!ask.isWorking, "nothing is left working")
        }
    }
}
#endif
