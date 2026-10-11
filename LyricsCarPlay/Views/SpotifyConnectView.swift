import SwiftUI

public struct SpotifyConnectView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var showingAdvancedSettings: Bool = false
    @State private var clientIdInput: String = ""
    @State private var manualToken: String = ""

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "music.note.house.fill")
                    .foregroundColor(.green)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Spotify")
                        .font(.headline)
                    Text(viewModel.spotifyMonitor.isConnected ? "Conectado • Detectando música..." : "No conectado")
                        .font(.caption)
                        .foregroundColor(viewModel.spotifyMonitor.isConnected ? .green : .secondary)
                }

                Spacer()

                if viewModel.spotifyMonitor.isConnected {
                    Button(action: {
                        viewModel.spotifyMonitor.disconnect()
                    }) {
                        Text("Desconectar")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }

            if !viewModel.spotifyMonitor.isConnected {
                Button(action: {
                    if !clientIdInput.isEmpty {
                        viewModel.spotifyMonitor.clientId = clientIdInput
                    }
                    viewModel.spotifyMonitor.authenticateWithSpotify { success in
                        if success {
                            viewModel.startSpotifyMonitoring()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "waveform")
                        Text("Iniciar Sesión con Spotify")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                Button(action: {
                    showingAdvancedSettings.toggle()
                }) {
                    Text(showingAdvancedSettings ? "Ocultar opciones avanzadas" : "Ingresar token o Client ID manual")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if showingAdvancedSettings {
                    VStack(spacing: 8) {
                        TextField("Spotify Client ID", text: $clientIdInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)

                        HStack {
                            TextField("O pega Token de Spotify", text: $manualToken)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)

                            Button("Guardar") {
                                if !clientIdInput.isEmpty {
                                    viewModel.spotifyMonitor.clientId = clientIdInput
                                }
                                if !manualToken.isEmpty {
                                    viewModel.spotifyMonitor.accessToken = manualToken
                                    viewModel.spotifyMonitor.isConnected = true
                                    viewModel.startSpotifyMonitoring()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .font(.caption)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            if let error = viewModel.spotifyMonitor.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .onAppear {
            self.clientIdInput = viewModel.spotifyMonitor.clientId
        }
    }
}
