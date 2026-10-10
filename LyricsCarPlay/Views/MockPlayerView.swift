import SwiftUI

public struct MockPlayerView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var customTitle: String = "Bohemian Rhapsody"
    @State private var customArtist: String = "Queen"

    public var body: some View {
        VStack(spacing: 16) {
            Text("Simulador de Reproducción")
                .font(.headline)

            HStack {
                TextField("Título", text: $customTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("Artista", text: $customArtist)
                    .textFieldStyle(.roundedBorder)
            }

            Button(action: {
                let track = TrackInfo(
                    title: customTitle,
                    artist: customArtist,
                    duration: 300.0
                )
                Task {
                    await viewModel.loadLyricsAndStart(for: track)
                }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Cargar & Simular en CarPlay")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}
