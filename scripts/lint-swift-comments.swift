import Foundation
import SwiftParser
import SwiftSyntax

func commentRanges(in trivia: Trivia, startingAt start: Int) -> [[Int]] {
    var offset = start
    var ranges: [[Int]] = []
    for piece in trivia {
        let end = offset + piece.sourceLength.utf8Length
        switch piece {
        case .lineComment, .docLineComment, .blockComment, .docBlockComment:
            ranges.append([offset, end])
        default:
            break
        }
        offset = end
    }
    return ranges
}

var findings: [String: [[Int]]] = [:]
for path in CommandLine.arguments.dropFirst() {
    let source = try String(contentsOfFile: path, encoding: .utf8)
    let syntax = Parser.parse(source: source)
    let ranges = syntax.tokens(viewMode: .sourceAccurate).flatMap { token in
        commentRanges(in: token.leadingTrivia, startingAt: token.position.utf8Offset)
            + commentRanges(in: token.trailingTrivia, startingAt: token.endPositionBeforeTrailingTrivia.utf8Offset)
    }
    if !ranges.isEmpty {
        findings[path] = ranges
    }
}
print(String(decoding: try JSONEncoder().encode(findings), as: UTF8.self))
