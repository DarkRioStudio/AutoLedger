import Foundation

enum RuntimePaths {
    static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        return url
    }()

    static var defaultOutputDirectory: URL {
        repoRoot
            .appendingPathComponent(".tmp", isDirectory: true)
            .appendingPathComponent("receipt_debug_tool", isDirectory: true)
    }

    static var goldenRegressionScript: URL {
        repoRoot
            .appendingPathComponent("scripts", isDirectory: true)
            .appendingPathComponent("run_golden_regression.sh")
    }
}
