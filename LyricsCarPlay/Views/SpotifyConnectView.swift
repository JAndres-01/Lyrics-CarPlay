import SwiftUI
import UIKit

public struct SpotifyConnectView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var showingSetupGuide: Bool = false
    @State private var clientIdInput: String = ""
    @State private var manualToken: String = ""
    @State private var copiedRedirect: Bool = false

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "music.note.house.fill")
                    .foregroundColor(.green)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Spotify")
                        .font(.headline)
                    Text(viewModel.spotifyMonitor.isConnected ? "Conectado • Detectando música..." : "No conectado (OAuth 2.0 PKCE)")
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Ingresa tu Spotify Client ID:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    TextField("Pega tu Spotify Client ID aquí", text: $clientIdInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    HStack {
                        Button(action: {
                            UIPasteboard.general.string = "lyricscarplay://spotify-callback"
                            copiedRedirect = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedRedirect = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: copiedRedirect ? "checkmark.circle.fill" : "doc.on.doc")
                                Text(copiedRedirect ? "¡Copiado!" : "Copiar Redirect URI")
                            }
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.15))
                            .cornerRadius(6)
                        }

                        Spacer()

                        if let url = URL(string: "https://developer.spotify.com/dashboard") {
                            Link("Abrir Spotify Dashboard ↗", destination: url)
                                .font(.caption2.bold())
                        }
                    }
                }

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
                        Text("Conectar con Spotify")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                Button(action: {
                    showingSetupGuide.toggle()
                }) {
                    Text(showingSetupGuide ? "Ocultar ayuda / token manual" : "¿Cómo obtener mi Client ID en 30 seg?")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if showingSetupGuide {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pasos rápidos en developer.spotify.com/dashboard:")
                            .font(.caption2.bold())
                        Text("• Toca 'Create App' y pon cualquier nombre.")
                            .font(.caption2)
                        Text("• En Redirect URIs pega: lyricscarplay://spotify-callback")
                            .font(.caption2.bold())
                        Text("• Guarda, copia el 'Client ID' y pégalo arriba.")
                            .font(.caption2)

                        Divider().padding(.vertical, 2)

                        HStack {
                            TextField("O pega un Access Token directo", text: $manualToken)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption2)

                            Button("Usar") {
                                if !manualToken.isEmpty {
                                    viewModel.spotifyMonitor.accessToken = manualToken
                                    viewModel.spotifyMonitor.isConnected = true
                                    viewModel.startSpotifyMonitoring()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .font(.caption2)
                        }
                    }
                    .padding(8)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
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
