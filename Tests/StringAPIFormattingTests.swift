import Testing
@testable import StandupBuddy

@Suite("String+APIFormatting")
struct StringAPIFormattingTests {
    @Test func singleLineIsUnchanged() {
        #expect("Hello, world!".flattenedForSlack() == "Hello, world!")
    }

    @Test func trailingNewlineIsStripped() {
        #expect("Hello, world!\n".flattenedForSlack() == "Hello, world!")
    }

    @Test func leadingNewlineIsStripped() {
        #expect("\nHello, world!".flattenedForSlack() == "Hello, world!")
    }

    @Test func internalNewlineBecomesSpace() {
        let joke = "What was the pumpkin's favorite sport?\n\nSquash."
        #expect(joke.flattenedForSlack() == "What was the pumpkin's favorite sport? Squash.")
    }

    @Test func multipleInternalNewlinesCollapseToSingleSpace() {
        #expect("Line one\n\n\nLine two".flattenedForSlack() == "Line one Line two")
    }

    @Test func mixedWhitespaceAroundNewlinesIsTrimmed() {
        #expect("Line one  \n  Line two".flattenedForSlack() == "Line one Line two")
    }

    @Test func emptyStringReturnsEmpty() {
        #expect("".flattenedForSlack() == "")
    }

    @Test func onlyNewlinesReturnsEmpty() {
        #expect("\n\n\n".flattenedForSlack() == "")
    }
}
