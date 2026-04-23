import Foundation

// MARK: - Data model

public struct DjVuWord: Equatable, Sendable {
    public let text: String
    /// Bounding box in DjVu page coordinates (origin bottom-left).
    public let xmin: Int
    public let ymin: Int
    public let xmax: Int
    public let ymax: Int

    public init(text: String, xmin: Int, ymin: Int, xmax: Int, ymax: Int) {
        self.text = text
        self.xmin = xmin
        self.ymin = ymin
        self.xmax = xmax
        self.ymax = ymax
    }
}

public struct DjVuPageText: Equatable, Sendable {
    public let words: [DjVuWord]

    /// Full text of the page (words joined by spaces).
    public var plainText: String {
        words.map(\.text).joined(separator: " ")
    }

    public init(words: [DjVuWord]) {
        self.words = words
    }
}

public struct SearchMatch: Equatable, Sendable {
    public let page: Int
    /// Indices into `DjVuPageText.words` for the words that contain this match.
    public let wordIndices: [Int]

    public init(page: Int, wordIndices: [Int]) {
        self.page = page
        self.wordIndices = wordIndices
    }
}

// MARK: - S-expression parser

extension DjVuRenderer {

    /// Parse `djvused print-txt` s-expression output into words with bounding boxes.
    /// Returns empty result for empty output (missing text layer is normal, not an error).
    public static func parsePageText(from output: String) -> DjVuPageText {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return DjVuPageText(words: [])
        }
        var tokens = tokenize(trimmed)
        var index = tokens.startIndex
        let words = extractWords(from: &tokens, index: &index)
        return DjVuPageText(words: words)
    }

    /// Convert DjVu word coordinates to screen-space CGRect.
    /// DjVu origin is bottom-left; screen origin is top-left.
    public static func djvuToScreenRect(
        word: DjVuWord,
        nativeSize: PageSize,
        displaySize: CGSize
    ) -> CGRect {
        guard nativeSize.width > 0, nativeSize.height > 0 else {
            return .zero
        }
        let scaleX = displaySize.width / CGFloat(nativeSize.width)
        let scaleY = displaySize.height / CGFloat(nativeSize.height)

        let x = CGFloat(word.xmin) * scaleX
        // DjVu y-axis points up (ymax is the top edge), screen y-axis points down,
        // so we flip: screenY = (pageHeight - ymax) scaled to display height.
        let y = (CGFloat(nativeSize.height) - CGFloat(word.ymax)) * scaleY
        let w = CGFloat(word.xmax - word.xmin) * scaleX
        let h = CGFloat(word.ymax - word.ymin) * scaleY

        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Find case-insensitive substring matches in a page's words.
    package static func findMatches(in pageText: DjVuPageText, query: String, page: Int) -> [SearchMatch] {
        guard !query.isEmpty else { return [] }
        let lowerQuery = query.lowercased()
        var matches: [SearchMatch] = []
        for (index, word) in pageText.words.enumerated() {
            if word.text.lowercased().contains(lowerQuery) {
                matches.append(SearchMatch(page: page, wordIndices: [index]))
            }
        }
        return matches
    }
}

// MARK: - Tokenizer

private enum SExprToken {
    case leftParen
    case rightParen
    case string(String)
    case atom(String)
}

private func tokenize(_ input: String) -> [SExprToken] {
    var tokens: [SExprToken] = []
    var it = input.unicodeScalars.makeIterator()
    var current = it.next()

    while let ch = current {
        switch ch {
        case "(":
            tokens.append(.leftParen)
            current = it.next()
        case ")":
            tokens.append(.rightParen)
            current = it.next()
        case "\"":
            // Quoted string — handle escapes
            var s = ""
            current = it.next()
            while let c = current, c != "\"" {
                if c == "\\" {
                    current = it.next()
                    if let escaped = current {
                        if escaped == "\"" {
                            s.append("\"")
                        } else if escaped == "\\" {
                            s.append("\\")
                        } else if escaped == "n" {
                            s.append("\n")
                        } else if escaped == "t" {
                            s.append("\t")
                        } else if escaped >= "0" && escaped <= "7" {
                            // Octal escape: up to 3 digits
                            var octal = String(escaped)
                            for _ in 0..<2 {
                                let peek = it.next()
                                if let p = peek, p >= "0", p <= "7" {
                                    octal.append(String(p))
                                } else {
                                    current = peek
                                    break
                                }
                            }
                            if let code = UInt32(octal, radix: 8), let scalar = Unicode.Scalar(code) {
                                s.append(Character(scalar))
                            }
                            // current already advanced past octal; skip the next() below
                            if octal.count == 3 {
                                current = it.next()
                            }
                            continue
                        } else {
                            s.append(Character(escaped))
                        }
                        current = it.next()
                    }
                } else {
                    s.append(Character(c))
                    current = it.next()
                }
            }
            tokens.append(.string(s))
            current = it.next() // skip closing quote
        case " ", "\t", "\n", "\r":
            current = it.next() // skip whitespace
        default:
            // Bare atom (type name or integer)
            var atom = String(ch)
            current = it.next()
            while let c = current, c != "(" && c != ")" && c != " " && c != "\t" && c != "\n" && c != "\r" && c != "\"" {
                atom.append(Character(c))
                current = it.next()
            }
            tokens.append(.atom(atom))
        }
    }

    return tokens
}

// MARK: - Recursive extraction

/// Recursively parse s-expression nodes, collecting word-level entries.
///
/// Grammar:
/// ```
/// node = "(" type int int int int (node... | string) ")"
/// type = "page" | "column" | "region" | "para" | "line" | "word"
/// ```
private func extractWords(from tokens: inout [SExprToken], index: inout Int) -> [DjVuWord] {
    var words: [DjVuWord] = []

    while index < tokens.count {
        guard case .leftParen = tokens[index] else {
            index += 1
            continue
        }
        index += 1 // skip (

        // Expect: type xmin ymin xmax ymax (children | string)
        guard index < tokens.count, case .atom(let nodeType) = tokens[index] else {
            skipToMatchingParen(tokens: tokens, index: &index)
            continue
        }
        index += 1 // skip type

        // Parse 4 coordinate integers
        var coords: [Int] = []
        for _ in 0..<4 {
            guard index < tokens.count, case .atom(let numStr) = tokens[index], let num = Int(numStr) else {
                break
            }
            coords.append(num)
            index += 1
        }

        guard coords.count == 4 else {
            skipToMatchingParen(tokens: tokens, index: &index)
            continue
        }

        let (xmin, ymin, xmax, ymax) = (coords[0], coords[1], coords[2], coords[3])

        // Children: either nested nodes or a single string
        if nodeType == "word" {
            // Word node: expect a string, then closing paren
            if index < tokens.count, case .string(let text) = tokens[index] {
                index += 1
                words.append(DjVuWord(text: text, xmin: xmin, ymin: ymin, xmax: xmax, ymax: ymax))
            }
            skipToMatchingParen(tokens: tokens, index: &index)
        } else {
            // Container node (page, column, region, para, line): recurse into children
            // If the node has a string child instead of sub-nodes, treat it as a single word-like entry
            if index < tokens.count, case .string(let text) = tokens[index] {
                index += 1
                if !text.isEmpty {
                    words.append(DjVuWord(text: text, xmin: xmin, ymin: ymin, xmax: xmax, ymax: ymax))
                }
                skipToMatchingParen(tokens: tokens, index: &index)
            } else {
                // Recurse into child nodes
                let childWords = extractWords(from: &tokens, index: &index)
                words.append(contentsOf: childWords)
            }
        }
    }

    return words
}

/// Skip tokens until the matching closing paren (or end of tokens).
private func skipToMatchingParen(tokens: [SExprToken], index: inout Int) {
    // We're inside a node after consuming its header — skip until the corresponding ")"
    var depth = 1
    while index < tokens.count && depth > 0 {
        switch tokens[index] {
        case .leftParen: depth += 1
        case .rightParen: depth -= 1
        default: break
        }
        index += 1
    }
}
