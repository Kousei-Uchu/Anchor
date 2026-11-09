import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What an AI tool is asked to do (Patch AI1, docs/OPTIONAL_FEATURES.md). Each tool is one action on text the
/// person chose, with a fixed instruction that is shown in full on the consent sheet before anything is sent.
/// A later patch adds its own case, and its own instruction, here.
enum AIFeature: String, CaseIterable {
    case makeShorter

    /// The plain name of the button, and of the tool in the list of ones that no longer ask.
    var title: String {
        switch self {
        case .makeShorter: return "Make shorter"
        }
    }

    /// The fixed instruction that goes with the text. It says what to keep and what never to add.
    var instruction: String {
        switch self {
        case .makeShorter:
            return "Make this text shorter. Keep every concrete detail, name, number and date, and keep who said what. Add nothing: no advice, no comment on feelings, no new facts. Use the same voice and the same language as the text. Reply with the shorter text only."
        }
    }
}

/// Where a tool can run. Apple's model on the phone is the only one so far. Ollama (AI5) and a provider the
/// person adds themselves (AI6) are added here when they are built.
enum AIProviderKind: String, CaseIterable {
    case apple

    var name: String {
        switch self {
        case .apple: return "Apple's on-device model"
        }
    }

    /// Where the text goes, in the words the consent sheet uses.
    var whereItRuns: String {
        switch self {
        case .apple: return "On this phone. The text does not leave it."
        }
    }

    /// What the provider does with the text, as far as Anchor can say.
    var keeping: String {
        switch self {
        case .apple: return "It is held in memory on this phone until you keep or discard the answer. Anchor keeps no log of it."
        }
    }

    /// Whether the consent sheet offers Don't ask again. Never for a provider the person added themselves (D42).
    var offersDontAskAgain: Bool {
        switch self {
        case .apple: return true
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

    var plainText: String {
        switch self {
        case .ready: return "Ready"
        case .notOnThisPhone: return "This phone cannot run it"
        case .appleIntelligenceOff: return "Turn on Apple Intelligence in the phone's Settings"
        case .notReady: return "Not ready yet, try again later"
        case .unavailable: return "Not available"
        case .aiToolsOff: return "AI tools are off"
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

    var plainText: String {
        switch self {
        case .off: return "AI tools are off."
        case .busy: return "Another request is still going."
        case .nothingToSend: return "There is no text to send."
        case .tooLong(let limit): return "That is too long for this tool. Pick up to \(limit) characters. Nothing was sent."
        case .unavailable(let status): return status.plainText + ". Nothing was sent."
        case .cancelled: return "Cancelled. Nothing was sent."
        case .failed: return "It could not make an answer. Nothing was kept."
        }
    }
}

/// One place a tool can run. It is only ever called by `AIAsk`, after the gate and after the person has been
/// shown the consent sheet (or has said not to be asked again), and `scripts/check-ai-gate.mjs` checks that.
protocol AIProviding: Sendable {
    var kind: AIProviderKind { get }
    /// The most characters this provider takes in one go. Longer text is refused before anything is sent.
    var maxCharacters: Int { get }
    func status() -> AIProviderStatus
    func generate(instruction: String, text: String) async throws -> String
}

enum AIProviders {
    /// The provider in use. One for now; a choice is added with the second provider.
    static var chosen: AIProviderKind { .apple }

    static func make(_ kind: AIProviderKind) -> AIProviding {
        switch kind {
        case .apple: return AppleOnDeviceProvider()
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
