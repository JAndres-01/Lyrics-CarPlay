import SwiftUI

public struct LyricsDisplayView: View {
    let lyrics: [LyricLine]
    let currentSyncState: SyncState?

    public init(lyrics: [LyricLine], currentSyncState: SyncState?) {
        self.lyrics = lyrics
        self.currentSyncState = currentSyncState
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        let isCurrent = currentSyncState?.currentIndex == index

                        Text(line.text)
                            .font(isCurrent ? .title2.bold() : .body)
                            .foregroundColor(isCurrent ? .accentColor : .secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .scaleEffect(isCurrent ? 1.08 : 1.0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCurrent)
                            .id(index)
                    }
                }
                .padding(.vertical, 40)
            }
            .onChange(of: currentSyncState?.currentIndex) { newIndex in
                if let index = newIndex, index >= 0 {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }
}
