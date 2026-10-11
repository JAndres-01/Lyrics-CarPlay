import SwiftUI

public struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Music Source Picker
                Picker("Fuente de Música", selection: $viewModel.selectedSource) {
                    ForEach(MusicSource.allCases) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Source Specific Panels
                if viewModel.selectedSource == .mock {
                    MockPlayerView(viewModel: viewModel)
                        .padding(.horizontal)
                } else if viewModel.selectedSource == .spotify {
                    SpotifyConnectView(viewModel: viewModel)
                        .padding(.horizontal)
                } else if viewModel.selectedSource == .appleMusic {
                    HStack {
                        Image(systemName: "applelogo")
                            .foregroundColor(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Music")
                                .font(.headline)
                            Text("Detectando reproducción nativa del sistema...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }

                // Currently Playing Track Card
                VStack(spacing: 6) {
                    Text(viewModel.currentTrack.title)
                        .font(.headline.bold())
                        .lineLimit(1)

                    Text(viewModel.currentTrack.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Live Activity Indicator Badge
                    if #available(iOS 16.2, *) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(viewModel.liveActivityManager.isActivityActive ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(viewModel.liveActivityManager.isActivityActive ? "Live Activity Activa en CarPlay" : "Live Activity Inactiva")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                .padding(.horizontal)

                // Error Message / Loader
                if viewModel.isLoadingLyrics {
                    ProgressView("Buscando letra sincronizada en LRCLIB...")
                        .font(.caption)
                        .padding(.vertical, 4)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Active Lyrics Display with Fluid Scroll Animation
                LyricsDisplayView(lyrics: viewModel.lyrics, currentSyncState: viewModel.syncState)

                // Playback Control Bar (Only for Mock Mode)
                if viewModel.selectedSource == .mock {
                    HStack(spacing: 30) {
                        Button(action: {
                            viewModel.togglePlayPause()
                        }) {
                            Image(systemName: viewModel.syncEngine.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .padding(14)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Circle())
                        }

                        Button(action: {
                            viewModel.stop()
                        }) {
                            Image(systemName: "square.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                                .padding(14)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("CarPlay Lyrics 🎵")
            .onAppear {
                if viewModel.selectedSource == .mock {
                    Task {
                        await viewModel.loadLyricsAndStart(for: TrackInfo.mock)
                    }
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
