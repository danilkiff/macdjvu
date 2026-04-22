import Foundation

/// Page width in pixels at 100% zoom.
/// Chosen to fit comfortably in a typical window (~1000px)
/// while keeping scanned text readable.
public let baseWidth: CGFloat = 800

public struct DjVuRenderer: Sendable {

    // MARK: - Tool resolution

    private static let searchPaths = [
        "/opt/homebrew/bin",   // Apple Silicon Homebrew
        "/usr/local/bin",      // Intel Homebrew
        "/usr/bin",
    ]

    static func toolPath(_ name: String) -> String {
        for dir in searchPaths {
            let path = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return name // fallback to PATH lookup
    }

    // MARK: - Shell helpers

    private static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath(executable))
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DjVuError.processFailure(executable, Int(process.terminationStatus))
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Parsing (public for testing)

    public static func parsePageCount(from output: String) throws -> Int {
        guard let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw DjVuError.unexpectedOutput(output)
        }
        return count
    }

    public static func parsePageSize(from output: String) throws -> (width: Int, height: Int) {
        // "width=3433 height=4947"
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        guard parts.count == 2,
              let w = parts[0].split(separator: "=").last.flatMap({ Int($0) }),
              let h = parts[1].split(separator: "=").last.flatMap({ Int($0) })
        else {
            throw DjVuError.unexpectedOutput(output)
        }
        return (w, h)
    }

    // MARK: - Public API

    public static func pageCount(of file: URL) throws -> Int {
        let output = try run("djvused", [file.path, "-e", "n"])
        return try parsePageCount(from: output)
    }

    public static func pageSize(of file: URL, page: Int) throws -> (width: Int, height: Int) {
        let output = try run("djvused", [file.path, "-e", "select \(page); size"])
        return try parsePageSize(from: output)
    }

    /// Render a page to TIFF data. Call from a background thread.
    public static func renderPage(file: URL, page: Int, scalePercent: Int) throws -> Data {
        let (nativeW, nativeH) = try pageSize(of: file, page: page)
        let targetW = max(1, Int(baseWidth) * scalePercent / 100)
        let targetH = max(1, targetW * nativeH / nativeW)

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("tiff")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let _ = try run("ddjvu", [
            "-format=tiff",
            "-page=\(page)",
            "-size=\(targetW)x\(targetH)",
            file.path,
            tmpURL.path,
        ])

        return try Data(contentsOf: tmpURL)
    }

    /// Compute display height for a page at a given zoom.
    public static func scaledPageHeight(nativeWidth: Int, nativeHeight: Int, scalePercent: Int) -> CGFloat {
        let targetW = max(1, CGFloat(baseWidth) * CGFloat(scalePercent) / 100)
        return max(1, targetW * CGFloat(nativeHeight) / CGFloat(nativeWidth))
    }
}

public enum DjVuError: Error, LocalizedError {
    case processFailure(String, Int)
    case unexpectedOutput(String)

    public var errorDescription: String? {
        switch self {
        case .processFailure(let tool, let code):
            return "\(tool) failed with exit code \(code)"
        case .unexpectedOutput(let output):
            return "Unexpected output: \(output)"
        }
    }
}
