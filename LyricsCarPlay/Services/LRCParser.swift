import Foundation

/// Parser for `.lrc` formatted synced lyrics strings into structured `[LyricLine]`.
public struct LRCParser {
    
    /// Parses raw `.lrc` text into an array of `LyricLine` objects sorted by timestamp.
    /// - Parameter lrcText: The raw LRC string returned from LRCLIB or local file.
    /// - Returns: Array of `LyricLine` sorted chronologically.
    public static func parse(_ lrcText: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = lrcText.components(separatedBy: .newlines)
        
        // Regex pattern matching [mm:ss.xx] or [mm:ss:xx] or [mm:ss]
        let timestampPattern = #"(?:\[(\d{2}):(\d{2})(?:[.:](\d{2,3}))?\])+"#
        guard let regex = try? NSRegularExpression(pattern: timestampPattern, options: []) else {
            return []
        }
        
        for rawLine in rawLines {
            let lineRange = NSRange(rawLine.startIndex..<rawLine.endIndex, in: rawLine)
            let matches = regex.matches(in: rawLine, options: [], range: lineRange)
            
            guard !matches.isEmpty else { continue }
            
            // Extract the lyric text after all timestamp tags
            var lyricText = rawLine
            for match in matches.reversed() {
                if let range = Range(match.range, in: lyricText) {
                    lyricText.removeSubrange(range)
                }
            }
            lyricText = lyricText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Extract each timestamp found in the line
            for match in matches {
                guard let minuteRange = Range(match.range(at: 1), in: rawLine),
                      let secondRange = Range(match.range(at: 2), in: rawLine),
                      let minutes = Double(rawLine[minuteRange]),
                      let seconds = Double(rawLine[secondRange]) else {
                    continue
                }
                
                var fraction: Double = 0.0
                if match.numberOfRanges > 3, let fractionRange = Range(match.range(at: 3), in: rawLine) {
                    let fractionStr = String(rawLine[fractionRange])
                    if let rawFraction = Double(fractionStr) {
                        fraction = fractionStr.count == 3 ? rawFraction / 1000.0 : rawFraction / 100.0
                    }
                }
                
                let totalTime = (minutes * 60.0) + seconds + fraction
                lines.append(LyricLine(timestamp: totalTime, text: lyricText))
            }
        }
        
        // Sort chronologically by timestamp
        return lines.sorted { $0.timestamp < $1.timestamp }
    }
}
