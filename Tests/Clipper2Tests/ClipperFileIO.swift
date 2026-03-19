import Foundation
@testable import Clipper2

struct TestCase {
    let caption: String
    let clipType: ClipType
    let fillRule: FillRule
    let area: Int64
    let count: Int
    let subj: Paths64
    let subjOpen: Paths64
    let clip: Paths64
    let testNum: Int
}

enum ClipperFileIO {

    static func loadTestCases(_ filename: String) throws -> [TestCase] {
        guard let url = Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "Resources")
                ?? Bundle.module.url(forResource: (filename as NSString).deletingPathExtension,
                                     withExtension: (filename as NSString).pathExtension,
                                     subdirectory: "Resources") else {
            throw NSError(domain: "ClipperFileIO", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Resource not found: \(filename)"])
        }
        let content = try String(contentsOf: url, encoding: .utf8)
        var lines = content.components(separatedBy: .newlines)
        lines.append("")

        var caption = ""
        var ct: ClipType = .noClip
        var fillRule: FillRule = .evenOdd
        var area: Int64 = 0
        var count = 0
        var getIdx = 0
        var subj: Paths64 = []
        var subjOpen: Paths64 = []
        var clip: Paths64 = []

        var cases: [TestCase] = []

        for s in lines {
            if s.trimmingCharacters(in: .whitespaces).isEmpty {
                if getIdx != 0 {
                    cases.append(TestCase(
                        caption: caption,
                        clipType: ct,
                        fillRule: fillRule,
                        area: area,
                        count: count,
                        subj: subj,
                        subjOpen: subjOpen,
                        clip: clip,
                        testNum: cases.count + 1
                    ))
                    subj = []
                    subjOpen = []
                    clip = []
                    getIdx = 0
                }
                continue
            }

            if s.hasPrefix("CAPTION: ") {
                caption = String(s.dropFirst(9))
                continue
            }

            if s.hasPrefix("CLIPTYPE: ") {
                if s.contains("INTERSECTION") {
                    ct = .intersection
                } else if s.contains("UNION") {
                    ct = .union
                } else if s.contains("DIFFERENCE") {
                    ct = .difference
                } else {
                    ct = .xor
                }
                continue
            }

            if s.hasPrefix("FILLTYPE: ") || s.hasPrefix("FILLRULE: ") {
                if s.contains("EVENODD") {
                    fillRule = .evenOdd
                } else if s.contains("POSITIVE") {
                    fillRule = .positive
                } else if s.contains("NEGATIVE") {
                    fillRule = .negative
                } else {
                    fillRule = .nonZero
                }
                continue
            }

            if s.hasPrefix("SOL_AREA: ") {
                area = Int64(s.dropFirst(10).trimmingCharacters(in: .whitespaces)) ?? 0
                continue
            }

            if s.hasPrefix("SOL_COUNT: ") {
                count = Int(s.dropFirst(11).trimmingCharacters(in: .whitespaces)) ?? 0
                continue
            }

            if s.hasPrefix("SUBJECTS_OPEN") {
                getIdx = 2
                continue
            } else if s.hasPrefix("SUBJECTS") {
                getIdx = 1
                continue
            } else if s.hasPrefix("CLIPS") {
                getIdx = 3
                continue
            }

            let paths = pathFromStr(s)
            if paths.isEmpty || paths[0].isEmpty {
                if s.hasPrefix("SUBJECTS_OPEN") {
                    getIdx = 2
                } else if s.hasPrefix("CLIPS") {
                    getIdx = 3
                }
                continue
            }
            if getIdx == 1 && !paths[0].isEmpty {
                subj.append(paths[0])
            } else if getIdx == 2 {
                subjOpen.append(paths[0])
            } else {
                clip.append(paths[0])
            }
        }

        return cases
    }

    static func pathFromStr(_ s: String) -> Paths64 {
        var p: Path64 = []
        var pp: Paths64 = []
        let chars = Array(s.unicodeScalars)
        let len = chars.count
        var i = 0

        while i < len {
            // skip whitespace
            while i < len && chars[i].value < 33 {
                i += 1
            }
            if i >= len { break }

            // get X
            let isNegX = chars[i] == "-"
            if isNegX { i += 1 }
            if i >= len || chars[i].value < 48 || chars[i].value > 57 { break }
            let xStart = i
            i += 1
            while i < len && chars[i].value >= 48 && chars[i].value <= 57 {
                i += 1
            }
            guard let x = Int64(String(s[s.index(s.startIndex, offsetBy: xStart)..<s.index(s.startIndex, offsetBy: i)])) else { break }
            let finalX = isNegX ? -x : x

            // skip space or comma between X & Y
            while i < len && (chars[i] == " " || chars[i] == ",") {
                i += 1
            }

            // get Y
            if i >= len { break }
            let isNegY = chars[i] == "-"
            if isNegY { i += 1 }
            if i >= len || chars[i].value < 48 || chars[i].value > 57 { break }
            let yStart = i
            i += 1
            while i < len && chars[i].value >= 48 && chars[i].value <= 57 {
                i += 1
            }
            guard let y = Int64(String(s[s.index(s.startIndex, offsetBy: yStart)..<s.index(s.startIndex, offsetBy: i)])) else { break }
            let finalY = isNegY ? -y : y

            p.append(Point64(finalX, finalY))

            // skip trailing space, comma
            var nlCnt = 0
            while i < len && (chars[i].value < 33 || chars[i] == ",") {
                if chars[i] == "\n" {
                    nlCnt += 1
                    if nlCnt == 2 {
                        if !p.isEmpty {
                            pp.append(p)
                        }
                        p = []
                    }
                }
                i += 1
            }
        }
        if !p.isEmpty {
            pp.append(p)
        }
        return pp
    }
}
