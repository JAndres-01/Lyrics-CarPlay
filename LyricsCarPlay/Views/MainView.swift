import SwiftUI

public struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 12) {
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
                            Text("Sincronización de baja latencia (60ms)...")
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

                // Currently Playing Track Card + Sync Offset Control
                VStack(spacing: 8) {
                    Text(viewModel.currentTrack.title)
                        .font(.headline.bold())
                        .lineLimit(1)

                    Text(viewModel.currentTrack.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Divider()
                        .padding(.vertical, 2)

                    HStack {
                        // Interactive Live Activity Toggle (Point 1 ON/OFF)
                        if #available(iOS 16.2, *) {
                            Button(action: {
                                viewModel.isLiveActivityEnabled.toggle()
                            }) {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(viewModel.isLiveActivityEnabled ? Color.green : Color.gray)
                                        .frame(width: 8, height: 8)
                                    Text(viewModel.isLiveActivityEnabled ? "Live Activity: ON" : "Live Activity: OFF")
                                        .font(.caption2.bold())
                                        .foregroundColor(viewModel.isLiveActivityEnabled ? .primary : .secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }

                        Spacer()

                        // Real-time Lyric Sync Offset Calibrator
                        HStack(spacing: 8) {
                            Button(action: {
                                viewModel.adjustOffset(by: -0.2)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.secondary)
                            }

                            Text(String(format: "Sync: %+.1fs", viewModel.lyricOffset))
                                .font(.caption2.monospacedDigit().bold())
                                .foregroundColor(.accentColor)

                            Button(action: {
                                viewModel.adjustOffset(by: 0.2)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
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
            .navigationTitle("CarPlay Lyrics")
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
