import SwiftUI

public struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Music Source Picker
                Picker("Fuente de Música", selection: $viewModel.selectedSource) {
                    ForEach(MusicSource.allCases) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if viewModel.selectedSource == .mock {
                    MockPlayerView(viewModel: viewModel)
                        .padding(.horizontal)
                }

                // Currently Playing Track Card
                VStack(spacing: 8) {
                    Text(viewModel.currentTrack.title)
                        .font(.title3.bold())
                        .lineLimit(1)

                    Text(viewModel.currentTrack.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Live Activity Indicator Badge
                    if #available(iOS 16.2, *) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(viewModel.liveActivityManager.isActivityActive ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(viewModel.liveActivityManager.isActivityActive ? "Live Activity Activa en CarPlay" : "Live Activity Inactiva")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                .padding(.horizontal)

                // Error Message / Loader
                if viewModel.isLoadingLyrics {
                    ProgressView("Buscando letra sincronizada en LRCLIB...")
                        .padding()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }

                // Active Lyrics Display
                LyricsDisplayView(lyrics: viewModel.lyrics, currentSyncState: viewModel.syncState)

                // Playback Control Bar
                HStack(spacing: 30) {
                    Button(action: {
                        viewModel.togglePlayPause()
                    }) {
                        Image(systemName: viewModel.syncEngine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .padding()
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Circle())
                    }

                    Button(action: {
                        viewModel.stop()
                    }) {
                        Image(systemName: "square.fill")
                            .font(.title)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("CarPlay Lyrics 🎵")
            .onAppear {
                Task {
                    await viewModel.loadLyricsAndStart(for: TrackInfo.mock)
                }
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
