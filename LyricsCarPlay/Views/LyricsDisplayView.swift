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
                VStack(spacing: 24) {
                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        let currentIndex = currentSyncState?.currentIndex ?? -1
                        let isCurrent = currentIndex == index
                        let isNext = (currentIndex + 1) == index

                        Text(line.text)
                            .font(.system(size: isCurrent ? 25 : (isNext ? 18 : 16), weight: isCurrent ? .bold : (isNext ? .semibold : .regular), design: .rounded))
                            .foregroundColor(isCurrent ? .accentColor : (isNext ? .primary.opacity(0.65) : .secondary.opacity(0.45)))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .scaleEffect(isCurrent ? 1.10 : (isNext ? 0.96 : 0.90))
                            .animation(.spring(response: 0.38, dampingFraction: 0.75), value: currentIndex)
                            .id(index)
                    }
                }
                .padding(.vertical, 50)
            }
            .onChange(of: currentSyncState?.currentIndex) { newIndex in
                if let index = newIndex, index >= 0 {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }
}
