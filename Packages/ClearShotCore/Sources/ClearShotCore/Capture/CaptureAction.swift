/// What the capture bar makes: a screenshot, a scrolling capture or a recording.
public enum CaptureAction: String, CaseIterable, Sendable, Codable {
    case screenshot, scrolling, recording

    public var title: String {
        switch self {
        case .screenshot: "Screenshot"
        case .scrolling: "Scrolling"
        case .recording: "Record"
        }
    }

    /// SF Symbol name.
    public var symbol: String {
        switch self {
        case .screenshot: "camera.viewfinder"
        case .scrolling: "arrow.up.and.down"
        case .recording: "record.circle"
        }
    }
}
