import Foundation

public enum DjVuRenderer {

    /// Page width in pixels at 100% zoom.
    public static let baseWidth: CGFloat = 800

    // MARK: - Tool resolution

    private static let searchPaths = [
        "/opt/homebrew/bin",   // Apple Silicon Homebrew
        "/usr/local/bin",      // Intel Homebrew
        "/usr/bin",
    ]

    static func toolPath(_ name: String) -> String? {
        for dir in searchPaths {
            let path = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    // MARK: - Shell helpers

    private static func run(_ executable: String, _ arguments: [String]) throws -> String {
        guard let path = toolPath(executable) else {
            throw DjVuError.toolNotFound(executable)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        // GUI apps launched from Finder have no LANG/LC_CTYPE.
        // DjVuLibre uses mbrtowc() to convert argv paths to UTF-8;
        // without a UTF-8 locale it misinterprets non-ASCII bytes.
        var env = ProcessInfo.processInfo.environment
        if env["LC_CTYPE"] == nil {
            env["LC_CTYPE"] = "C.UTF-8"
        }
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: errData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw DjVuError.processFailure(executable, Int(process.terminationStatus), stderr)
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Parsing (public for testing)

    public static func parsePageCount(from output: String) throws -> Int {
        guard let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)),
              count > 0 else {
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
    /// Returns the rendered data along with the page's native dimensions.
    public static func renderPage(file: URL, page: Int, scalePercent: Int) throws -> (data: Data, nativeSize: (width: Int, height: Int)) {
        let (nativeW, nativeH) = try pageSize(of: file, page: page)
        let targetW = max(1, Int(baseWidth) * scalePercent / 100)
        let targetH = max(1, targetW * nativeH / nativeW)

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("tiff")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        _ = try run("ddjvu", [
            "-format=tiff",
            "-page=\(page)",
            "-size=\(targetW)x\(targetH)",
            file.path,
            tmpURL.path,
        ])

        let data = try Data(contentsOf: tmpURL)
        return (data, (nativeW, nativeH))
    }

    /// Compute display height for a page at a given zoom.
    public static func scaledPageHeight(nativeWidth: Int, nativeHeight: Int, scalePercent: Int) -> CGFloat {
        let targetW = max(1, CGFloat(baseWidth) * CGFloat(scalePercent) / 100)
        return max(1, targetW * CGFloat(nativeHeight) / CGFloat(nativeWidth))
    }
}

public enum DjVuError: Error, LocalizedError {
    case processFailure(String, Int, String)
    case unexpectedOutput(String)
    case toolNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .processFailure(let tool, let code, let stderr):
            if stderr.isEmpty {
                return "\(tool) failed with exit code \(code)"
            }
            return "\(tool) failed with exit code \(code): \(stderr)"
        case .unexpectedOutput(let output):
            return "Unexpected output: \(output)"
        case .toolNotFound(let name):
            return "\(name) not found. Install DjVuLibre: brew install djvulibre"
        }
    }
}
