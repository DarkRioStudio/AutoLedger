import AutoLedgerCore
import Foundation

struct ReceiptDebugParser {
    private let interpreter = LedgerTextInterpreterCore()

    func parse(_ debugCase: ReceiptDebugCase) -> InterpretResult {
        interpreter.interpret(
            InterpretInput(
                rawText: debugCase.activeOCRText,
                sourceType: debugCase.sourceType,
                hints: LedgerInterpretHints(sourceHint: debugCase.sourceHint)
            )
        )
    }
}
