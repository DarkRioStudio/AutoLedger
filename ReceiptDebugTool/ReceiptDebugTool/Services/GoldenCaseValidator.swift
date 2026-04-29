import Foundation

struct GoldenCaseValidator {
    func validate(candidatesURL: URL) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [RuntimePaths.goldenRegressionScript.path, candidatesURL.path]
        process.currentDirectoryURL = RuntimePaths.repoRoot
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw GoldenCaseValidatorError.failed(output)
        }
        return output
    }
}

enum GoldenCaseValidatorError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let output): output.isEmpty ? "Golden 验证失败。" : output
        }
    }
}
