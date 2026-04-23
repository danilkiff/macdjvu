import Foundation
import Testing
@testable import MacDjVuCore

@Suite("DjVuTextParser")
struct DjVuTextParserTests {

    // MARK: - parsePageText: basic cases

    @Test func parsePageText_singleWord() {
        let output = """
        (page 0 0 100 200
         (word 10 20 30 40 "Hello"))
        """
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.words.count == 1)
        #expect(result.words[0].text == "Hello")
        #expect(result.words[0].xmin == 10)
        #expect(result.words[0].ymin == 20)
        #expect(result.words[0].xmax == 30)
        #expect(result.words[0].ymax == 40)
    }

    @Test func parsePageText_multipleWords() {
        let output = """
        (page 0 0 40 30
         (line 5 10 35 25
          (word 5 10 18 25 "Hello")
          (word 20 10 35 25 "world")))
        """
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.words.count == 2)
        #expect(result.words[0].text == "Hello")
        #expect(result.words[0].xmin == 5)
        #expect(result.words[0].ymin == 10)
        #expect(result.words[0].xmax == 18)
        #expect(result.words[0].ymax == 25)
        #expect(result.words[1].text == "world")
        #expect(result.words[1].xmin == 20)
    }

    @Test func parsePageText_deepNesting() {
        let output = """
        (page 0 0 2480 3508
         (column 100 100 2400 3400
          (region 100 100 2400 3400
           (para 100 3300 2400 3400
            (line 100 3300 2400 3400
             (word 100 3300 300 3400 "deep"))))))
        """
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.words.count == 1)
        #expect(result.words[0].text == "deep")
    }

    @Test func parsePageText_multipleLines() {
        let output = """
        (page 0 0 100 100
         (line 0 50 100 100
          (word 0 50 40 100 "first")
          (word 50 50 100 100 "line"))
         (line 0 0 100 50
          (word 0 0 50 50 "second")))
        """
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.words.count == 3)
        #expect(result.words[0].text == "first")
        #expect(result.words[1].text == "line")
        #expect(result.words[2].text == "second")
    }

    // MARK: - parsePageText: empty / missing text

    @Test func parsePageText_emptyString() {
        let result = DjVuRenderer.parsePageText(from: "")
        #expect(result.words.isEmpty)
    }

    @Test func parsePageText_whitespaceOnly() {
        let result = DjVuRenderer.parsePageText(from: "   \n  \t  ")
        #expect(result.words.isEmpty)
    }

    @Test func parsePageText_emptyPage() {
        let result = DjVuRenderer.parsePageText(from: "(page 0 0 0 0 \"\")")
        #expect(result.words.isEmpty)
    }

    @Test func parsePageText_pageWithEmptyString() {
        // djvused returns this for pages without OCR text
        let result = DjVuRenderer.parsePageText(from: "(page 0 0 40 30 \"\")")
        #expect(result.words.isEmpty)
    }

    // MARK: - parsePageText: escapes

    @Test func parsePageText_escapedQuotes() {
        let output = #"(page 0 0 100 100 (word 0 0 10 10 "say \"hello\""))"#
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.words.count == 1)
        #expect(result.words[0].text == "say \"hello\"")
    }

    @Test func parsePageText_escapedBackslash() {
        let output = #"(page 0 0 100 100 (word 0 0 10 10 "path\\file"))"#
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.words.count == 1)
        #expect(result.words[0].text == "path\\file")
    }

    @Test func parsePageText_octalEscapes() {
        // \110\145\154\154\157 = "Hello" in octal
        let output = "(page 0 0 100 100 (word 0 0 10 10 \"\\110\\145\\154\\154\\157\"))"
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.words.count == 1)
        #expect(result.words[0].text == "Hello")
    }

    @Test func parsePageText_unicodeText() {
        let output = "(page 0 0 100 100 (word 0 0 10 10 \"\u{043C}\u{0438}\u{0440}\"))"
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.words.count == 1)
        #expect(result.words[0].text == "\u{043C}\u{0438}\u{0440}")
    }

    // MARK: - parsePageText: line-level text

    @Test func parsePageText_lineWithStringInsteadOfWords() {
        // Some DjVu files store text at line level without word subdivision.
        let output = """
        (page 0 0 100 100
         (line 0 0 100 50 "full line text"))
        """
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.words.count == 1)
        #expect(result.words[0].text == "full line text")
    }

    // MARK: - parsePageText: plainText computed property

    @Test func parsePageText_plainText() {
        let output = """
        (page 0 0 100 100
         (line 0 0 100 100
          (word 0 0 50 100 "Hello")
          (word 50 0 100 100 "world")))
        """
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.plainText == "Hello world")
    }

    @Test func parsePageText_plainTextEmpty() {
        let result = DjVuRenderer.parsePageText(from: "")
        #expect(result.plainText == "")
    }

    @Test func parsePageText_plainTextSingleWord() {
        let output = "(page 0 0 100 100 (word 0 0 10 10 \"only\"))"
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.plainText == "only")
    }

    // MARK: - parsePageText: malformed input

    @Test func parsePageText_malformedMissingCoords() {
        let output = "(page 0 0 (word \"broken\"))"
        let result = DjVuRenderer.parsePageText(from: output)
        // Should not crash; may return partial or no results
        #expect(result.words.count >= 0)
    }

    @Test func parsePageText_unbalancedParens() {
        let output = "(page 0 0 100 100 (word 0 0 10 10 \"ok\")"
        let result = DjVuRenderer.parsePageText(from: output)
        #expect(result.words.count == 1)
        #expect(result.words[0].text == "ok")
    }

    // MARK: - djvuToScreenRect

    @Test func djvuToScreenRect_basicConversion() {
        let word = DjVuWord(text: "x", xmin: 100, ymin: 200, xmax: 300, ymax: 250)
        let native = PageSize(width: 1000, height: 1000)
        let display = CGSize(width: 500, height: 500)

        let rect = DjVuRenderer.djvuToScreenRect(word: word, nativeSize: native, displaySize: display)
        // x = 100 * 0.5 = 50
        // y = (1000 - 250) * 0.5 = 375
        // w = (300 - 100) * 0.5 = 100
        // h = (250 - 200) * 0.5 = 25
        #expect(rect.origin.x == 50)
        #expect(rect.origin.y == 375)
        #expect(rect.size.width == 100)
        #expect(rect.size.height == 25)
    }

    @Test func djvuToScreenRect_yAxisFlip() {
        // Word at bottom of DjVu page should appear at top of screen
        let word = DjVuWord(text: "x", xmin: 0, ymin: 0, xmax: 100, ymax: 50)
        let native = PageSize(width: 100, height: 100)
        let display = CGSize(width: 100, height: 100)

        let rect = DjVuRenderer.djvuToScreenRect(word: word, nativeSize: native, displaySize: display)
        // y = (100 - 50) * 1.0 = 50 (bottom of DjVu → lower half of screen)
        #expect(rect.origin.y == 50)
    }

    @Test func djvuToScreenRect_fullPageWord() {
        let word = DjVuWord(text: "x", xmin: 0, ymin: 0, xmax: 200, ymax: 300)
        let native = PageSize(width: 200, height: 300)
        let display = CGSize(width: 800, height: 1200)

        let rect = DjVuRenderer.djvuToScreenRect(word: word, nativeSize: native, displaySize: display)
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 0)
        #expect(rect.size.width == 800)
        #expect(rect.size.height == 1200)
    }

    @Test func djvuToScreenRect_nonSquareAspectRatio() {
        let word = DjVuWord(text: "x", xmin: 0, ymin: 0, xmax: 100, ymax: 50)
        let native = PageSize(width: 200, height: 100)
        let display = CGSize(width: 800, height: 400)

        let rect = DjVuRenderer.djvuToScreenRect(word: word, nativeSize: native, displaySize: display)
        // scaleX = 4.0, scaleY = 4.0
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 200) // (100 - 50) * 4
        #expect(rect.size.width == 400) // 100 * 4
        #expect(rect.size.height == 200) // 50 * 4
    }

    @Test func djvuToScreenRect_zeroNativeSize() {
        let word = DjVuWord(text: "x", xmin: 0, ymin: 0, xmax: 10, ymax: 10)
        let native = PageSize(width: 0, height: 0)
        let display = CGSize(width: 800, height: 600)

        let rect = DjVuRenderer.djvuToScreenRect(word: word, nativeSize: native, displaySize: display)
        #expect(rect == .zero)
    }

    // MARK: - findMatches

    @Test func findMatches_caseInsensitive() {
        let pageText = DjVuPageText(words: [
            DjVuWord(text: "Hello", xmin: 0, ymin: 0, xmax: 10, ymax: 10),
        ])
        let matches = DjVuRenderer.findMatches(in: pageText, query: "hello", page: 1)
        #expect(matches.count == 1)
        #expect(matches[0].page == 1)
        #expect(matches[0].wordIndices == [0])
    }

    @Test func findMatches_noMatch() {
        let pageText = DjVuPageText(words: [
            DjVuWord(text: "Hello", xmin: 0, ymin: 0, xmax: 10, ymax: 10),
            DjVuWord(text: "world", xmin: 0, ymin: 0, xmax: 10, ymax: 10),
        ])
        let matches = DjVuRenderer.findMatches(in: pageText, query: "xyz", page: 1)
        #expect(matches.isEmpty)
    }

    @Test func findMatches_multipleMatchesSamePage() {
        let pageText = DjVuPageText(words: [
            DjVuWord(text: "apple", xmin: 0, ymin: 0, xmax: 10, ymax: 10),
            DjVuWord(text: "banana", xmin: 0, ymin: 0, xmax: 10, ymax: 10),
            DjVuWord(text: "avocado", xmin: 0, ymin: 0, xmax: 10, ymax: 10),
        ])
        let matches = DjVuRenderer.findMatches(in: pageText, query: "a", page: 3)
        #expect(matches.count == 3)
        #expect(matches[0].page == 3)
        #expect(matches[0].wordIndices == [0])
        #expect(matches[1].wordIndices == [1])
        #expect(matches[2].wordIndices == [2])
    }

    @Test func findMatches_emptyQuery() {
        let pageText = DjVuPageText(words: [
            DjVuWord(text: "Hello", xmin: 0, ymin: 0, xmax: 10, ymax: 10),
        ])
        let matches = DjVuRenderer.findMatches(in: pageText, query: "", page: 1)
        #expect(matches.isEmpty)
    }

    @Test func findMatches_emptyWords() {
        let pageText = DjVuPageText(words: [])
        let matches = DjVuRenderer.findMatches(in: pageText, query: "test", page: 1)
        #expect(matches.isEmpty)
    }

    @Test func findMatches_partialWordMatch() {
        let pageText = DjVuPageText(words: [
            DjVuWord(text: "Hello", xmin: 0, ymin: 0, xmax: 10, ymax: 10),
        ])
        let matches = DjVuRenderer.findMatches(in: pageText, query: "ell", page: 1)
        #expect(matches.count == 1)
    }

    @Test func findMatches_exactMatch() {
        let pageText = DjVuPageText(words: [
            DjVuWord(text: "test", xmin: 0, ymin: 0, xmax: 10, ymax: 10),
        ])
        let matches = DjVuRenderer.findMatches(in: pageText, query: "test", page: 2)
        #expect(matches.count == 1)
        #expect(matches[0].page == 2)
    }
}
