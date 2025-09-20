import Foundation

protocol DJTransport {
    func connect(sessionId: String) async throws
    func disconnect() async
    func startStream() async throws
    func stopStream() async
    func sendNowPlaying(_ track: CurrentTrack) async
}

final class NoopDJTransport: DJTransport {
    func connect(sessionId: String) async throws {}
    func disconnect() async {}
    func startStream() async throws {}
    func stopStream() async {}
    func sendNowPlaying(_ track: CurrentTrack) async {}
}

final class FakeMeteringTransport: DJTransport, ObservableObject {
    @Published var level: Float = 0 // 0..1
    private var timer: Timer?
    func connect(sessionId: String) async throws {}
    func disconnect() async { timer?.invalidate(); timer = nil }
    func startStream() async throws {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.level = Float.random(in: 0...1)
        }
    }
    func stopStream() async { await disconnect() }
    func sendNowPlaying(_ track: CurrentTrack) async {}
}

// Placeholder for a real backend transport; implement WebRTC/RTMP/etc. as needed
final class RealBackendTransport: DJTransport {
    private var sessionId: String?
    private var webSocket: URLSessionWebSocketTask?
    private var keepAliveTimer: Timer?
    private let session: URLSession = .shared
    private var endpoint: URL { URL(string: (UserDefaults.standard.string(forKey: "streaming.endpoint") ?? "wss://example.invalid/ws"))! }
    private var reconnectAttempts: Int = 0
    private var shouldReconnect: Bool = false
    private var reconnectWorkItem: DispatchWorkItem?

    func connect(sessionId: String) async throws {
        self.sessionId = sessionId
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        var query = components.queryItems ?? []
        query.append(URLQueryItem(name: "sessionId", value: sessionId))
        components.queryItems = query
        let url = components.url ?? endpoint
        let task = session.webSocketTask(with: url)
        task.resume()
        webSocket = task
        startReceive()
        startKeepAlive()
        shouldReconnect = true
        reconnectAttempts = 0
        AnalyticsService.shared.logDJ(action: "transport_connect", props: ["url": url.absoluteString])
    }
    func disconnect() async {
        keepAliveTimer?.invalidate(); keepAliveTimer = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        sessionId = nil
        shouldReconnect = false
        reconnectWorkItem?.cancel(); reconnectWorkItem = nil
        AnalyticsService.shared.logDJ(action: "transport_disconnect", props: [:])
    }
    func startStream() async throws {
        try? await sendJSON(["type": "start"]) 
    }
    func stopStream() async {
        try? await sendJSON(["type": "stop"]) 
    }
    func sendNowPlaying(_ track: CurrentTrack) async {
        let payload: [String: Any] = [
            "type": "now_playing",
            "trackId": track.trackId,
            "title": track.title,
            "artist": track.artistName,
            "album": track.albumName ?? "",
            "artworkUrl": track.artworkUrl ?? "",
            "startedAt": track.startedAt.timeIntervalSince1970,
            "duration": track.duration ?? 0
        ]
        try? await sendJSON(payload)
    }

    // MARK: - Internals
    private func startReceive() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            defer { self.startReceive() }
            switch result {
            case .success(let message):
                switch message {
                case .data(let data): self.handleMessageData(data)
                case .string(let text): self.handleMessageData(Data(text.utf8))
                @unknown default: break
                }
            case .failure(let error):
                AnalyticsService.shared.logDJ(action: "transport_receive_error", props: ["error": error.localizedDescription])
                scheduleReconnect()
            }
        }
    }
    private func startKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.webSocket?.sendPing { _ in }
        }
    }
    private func sendJSON(_ dict: [String: Any]) async throws {
        guard let webSocket else { return }
        let data = try JSONSerialization.data(withJSONObject: dict)
        await withCheckedContinuation { cont in
            webSocket.send(.data(data)) { _ in cont.resume() }
        }
    }
    private func handleMessageData(_ data: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return }
        switch type {
        case "ack":
            AnalyticsService.shared.logDJ(action: "transport_ack", props: [:])
        case "error":
            let msg = obj["message"] as? String ?? "unknown"
            CrashReporter.shared.logMessage("Transport error: \(msg)")
            AnalyticsService.shared.logDJ(action: "transport_error", props: ["message": msg])
        default:
            break
        }
    }
    private func scheduleReconnect() {
        guard shouldReconnect, let sessionId else { return }
        reconnectWorkItem?.cancel()
        reconnectAttempts += 1
        let delay = RealBackendTransport.backoffDelay(attempt: reconnectAttempts)
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            Task { try? await self.connect(sessionId: sessionId) }
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        AnalyticsService.shared.logDJ(action: "transport_reconnect_scheduled", props: ["attempt": reconnectAttempts, "delayMs": Int(delay*1000)])
    }
    static func backoffDelay(attempt: Int) -> TimeInterval {
        let capped = min(attempt, 6)
        let base = pow(2.0, Double(capped))
        let jitter = Double.random(in: 0...0.5)
        return min(30.0, base) + jitter
    }
}


