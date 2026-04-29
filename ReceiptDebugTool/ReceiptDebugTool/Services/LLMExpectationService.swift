import Foundation

protocol LLMExpectationService {
    var isEnabled: Bool { get }
}

struct DisabledLLMExpectationService: LLMExpectationService {
    let isEnabled = false
}
