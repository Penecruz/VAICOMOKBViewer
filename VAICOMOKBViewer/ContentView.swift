import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: ConnectionSettingsStore

    @State private var reloadToken = UUID()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @State private var isInitialConnecting = false
    @State private var hasConnected = false
    @State private var initialConnectionToken = UUID()
    @State private var reconnectLoopToken = UUID()

    var body: some View {
        let url = settings.dashboardURL
        let showNoConnectionCard = shouldShowNoConnectionCard(for: url)

        ZStack {
            if let url = url {
                WebView(url: url, reloadToken: reloadToken, isLoading: $isLoading, errorMessage: $errorMessage)
                    .ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }

            if showNoConnectionCard {
                noConnectionPrompt
                disconnectedFooter
            }

            overlayView

            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Button {
                            reloadToken = UUID()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(settings.dashboardURL == nil)

                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                }
                .padding(.top, 10)
                .padding(.trailing, 52)
                Spacer()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(settings)
        }
        .onAppear {
            startReconnectLoop()
            startInitialConnectionAttempt()
        }
        .onChange(of: settings.dashboardURL?.absoluteString ?? "") {
            hasConnected = false
            errorMessage = nil
            startReconnectLoop()
            startInitialConnectionAttempt()
        }
        .onChange(of: isLoading) {
            if !isLoading, settings.dashboardURL != nil, errorMessage == nil {
                hasConnected = true
                isInitialConnecting = false
            }
        }
        .onChange(of: errorMessage) {
            if errorMessage != nil {
                hasConnected = false
            }
        }
    }

    private var noConnectionPrompt: some View {
        VStack(spacing: 16) {
            noConnectionLogo
            noConnectionCard
        }
        .padding(.top, 70)
    }

    private var noConnectionLogo: some View {
        Image("Vaicom_logo_X")
            .resizable()
            .scaledToFit()
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
    }

    private var disconnectedFooter: some View {
        VStack {
            Spacer()
            Text(appVersionLine)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thinMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appVersionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(version) - By PeneCruz"
    }

    @ViewBuilder
    private var overlayView: some View {
        if settings.dashboardURL != nil && isInitialConnecting && isLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text("Connecting…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var noConnectionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34, weight: .semibold))
            Text("VAICOM iOS Out")
                .font(.headline)
            Text(settings.dashboardURL == nil ? "Add your host LAN IP and port to start." : "No connection. The app will keep trying using saved settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Try Again") {
                errorMessage = nil
                reloadToken = UUID()
                startInitialConnectionAttempt()
            }
            .buttonStyle(.bordered)
            .disabled(settings.dashboardURL == nil)
            Button("Connection Settings") {
                showingSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 24)
    }

    private func shouldShowNoConnectionCard(for url: URL?) -> Bool {
        if url == nil {
            return true
        }

        if hasConnected {
            return false
        }

        if isInitialConnecting {
            return false
        }

        return true
    }

    private func startInitialConnectionAttempt() {
        guard settings.dashboardURL != nil else {
            isInitialConnecting = false
            return
        }

        isInitialConnecting = true
        let token = UUID()
        initialConnectionToken = token
        reloadToken = UUID()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            guard initialConnectionToken == token else { return }
            if !hasConnected {
                isInitialConnecting = false
            }
        }
    }

    private func startReconnectLoop() {
        let token = UUID()
        reconnectLoopToken = token
        scheduleReconnectTick(token)
    }

    private func scheduleReconnectTick(_ token: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            guard reconnectLoopToken == token else { return }

            if settings.dashboardURL != nil && !hasConnected && !isLoading {
                reloadToken = UUID()
            }

            scheduleReconnectTick(token)
        }
    }
}
