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

    private final class ProcessCancellationController: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var cancellationRequested = false

        func setProcess(_ process: Process) {
            lock.withLock {
                self.process = process
                if cancellationRequested, process.isRunning {
                    process.terminate()
                }
            }
        }

        func terminateIfCancellationRequested() {
            lock.withLock {
                if cancellationRequested, process?.isRunning == true {
                    process?.terminate()
                }
            }
        }

        func cancel() {
            lock.withLock {
                cancellationRequested = true
                if process?.isRunning == true {
                    process?.terminate()
                }
            }
        }
    }

    private final class PipeReadResult: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()

        func set(_ newData: Data) {
            lock.withLock {
                data = newData
            }
        }

        func value() -> Data {
            lock.withLock { data }
        }
    }

    private static func readPipeAsync(_ pipe: Pipe, into result: PipeReadResult, group: DispatchGroup) {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            result.set(data)
            group.leave()
        }
    }

    private static func run(
        _ executable: String,
        _ arguments: [String],
        cancellationController: ProcessCancellationController? = nil
    ) throws -> String {
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

        let outData = PipeReadResult()
        let errData = PipeReadResult()
        let pipeReads = DispatchGroup()
        readPipeAsync(outPipe, into: outData, group: pipeReads)
        readPipeAsync(errPipe, into: errData, group: pipeReads)

        cancellationController?.setProcess(process)
        try process.run()
        cancellationController?.terminateIfCancellationRequested()

        process.waitUntilExit()
        pipeReads.wait()
        try Task.checkCancellation()

        guard process.terminationStatus == 0 else {
            let stderr = String(data: errData.value(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw DjVuError.processFailure(executable, Int(process.terminationStatus), stderr)
        }

        return String(data: outData.value(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func runCancellable(_ executable: String, _ arguments: [String]) async throws -> String {
        let cancellationController = ProcessCancellationController()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try run(executable, arguments, cancellationController: cancellationController)
        } onCancel: {
            cancellationController.cancel()
        }
    }

    // MARK: - Parsing (public for testing)

    public static func parsePageCount(from output: String) throws -> Int {
        guard let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)),
              count > 0 else {
            throw DjVuError.unexpectedOutput(output)
        }
        return count
    }

    public static func parsePageSize(from output: String) throws -> PageSize {
        // "width=3433 height=4947" — parse as key=value pairs, order-independent
        let dict = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .reduce(into: [String: Int]()) { acc, part in
                let kv = part.split(separator: "=")
                if kv.count == 2, let v = Int(kv[1]) { acc[String(kv[0])] = v }
            }
        guard let w = dict["width"], let h = dict["height"], w > 0, h > 0 else {
            throw DjVuError.unexpectedOutput(output)
        }
        return PageSize(width: w, height: h)
    }

    // MARK: - Public API

    public static func pageCount(of file: URL) throws -> Int {
        let output = try run("djvused", [file.path(percentEncoded: false), "-e", "n"])
        return try parsePageCount(from: output)
    }

    public static func pageSize(of file: URL, page: Int) throws -> PageSize {
        let output = try run("djvused", [file.path(percentEncoded: false), "-e", "select \(page); size"])
        return try parsePageSize(from: output)
    }

    private static func pageSizeCancellable(of file: URL, page: Int) async throws -> PageSize {
        let output = try await runCancellable("djvused", [file.path(percentEncoded: false), "-e", "select \(page); size"])
        return try parsePageSize(from: output)
    }

    /// Render a page to TIFF data. Call from a background thread.
    /// Returns the rendered data along with the page's native dimensions.
    public static func renderPage(file: URL, page: Int, scalePercent: Int) throws -> (data: Data, nativeSize: PageSize) {
        let native = try pageSize(of: file, page: page)
        let targetW = max(1, Int(baseWidth) * scalePercent / 100)
        let targetH = max(1, targetW * native.height / native.width)

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("tiff")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        _ = try run("ddjvu", [
            "-format=tiff",
            "-page=\(page)",
            "-size=\(targetW)x\(targetH)",
            file.path(percentEncoded: false),
            tmpURL.path(percentEncoded: false),
        ])

        let data = try Data(contentsOf: tmpURL)
        return (data, native)
    }

    /// Render a page to TIFF data and terminate DjVuLibre processes if the calling task is cancelled.
    public static func renderPageCancellable(file: URL, page: Int, scalePercent: Int) async throws -> (data: Data, nativeSize: PageSize) {
        let native = try await pageSizeCancellable(of: file, page: page)
        try Task.checkCancellation()

        let targetW = max(1, Int(baseWidth) * scalePercent / 100)
        let targetH = max(1, targetW * native.height / native.width)

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("tiff")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        _ = try await runCancellable("ddjvu", [
            "-format=tiff",
            "-page=\(page)",
            "-size=\(targetW)x\(targetH)",
            file.path(percentEncoded: false),
            tmpURL.path(percentEncoded: false),
        ])

        try Task.checkCancellation()
        let data = try Data(contentsOf: tmpURL)
        return (data, native)
    }

    // MARK: - Text extraction

    public static func pageText(of file: URL, page: Int) throws -> DjVuPageText {
        let output = try run("djvused", [file.path(percentEncoded: false), "-u", "-e", "select \(page); print-txt"])
        return parsePageText(from: output)
    }

    public static func pageTextCancellable(of file: URL, page: Int) async throws -> DjVuPageText {
        let output = try await runCancellable("djvused", [file.path(percentEncoded: false), "-u", "-e", "select \(page); print-txt"])
        return parsePageText(from: output)
    }

    /// Compute display height for a page at a given zoom.
    public static func scaledPageHeight(_ size: PageSize, scalePercent: Int) -> CGFloat {
        let targetW = max(1, CGFloat(baseWidth) * CGFloat(scalePercent) / 100)
        return max(1, targetW * CGFloat(size.height) / CGFloat(size.width))
    }
}

public struct PageSize: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
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
