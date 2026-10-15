import AppKit
import AVFoundation
import ClearShotCore
import SwiftUI

/// What the toolbar shows besides the settings: the countdown, and whether the microphone may be used.
@Observable
final class RecordingToolbarModel {
    /// 3, 2, 1 after Record; nil before.
    var countdown: Int?
    var microphoneAllowed = true
    var microphones: [Microphone] = []
}

struct RecordingToolbarView: View {
    @Environment(AppSettings.self) private var settings
    let model: RecordingToolbarModel
    /// "Change Area", "Change Window", or nil for a full screen recording.
    let changeTitle: String?
    let onCancel: () -> Void
    let onChange: () -> Void
    let onRecord: () -> Void
    let onMicrophoneTurnedOn: () -> Void

    var body: some View {
        let counting = model.countdown != nil
        ToolbarCapsule {
            ToolbarCloseButton(help: "Cancel (Esc)", action: onCancel)
            options
                .disabled(counting)
                .opacity(counting ? 0.45 : 1)
            recordButton
        }
        .animation(.snappy(duration: 0.25), value: counting)
    }

    @ViewBuilder private var options: some View {
        @Bindable var settings = settings
        HStack(spacing: 6) {
            ToolbarSeparator()

            HStack(spacing: 0) {
                OptionChip(title: "Mic", symbol: microphoneOn ? "mic.fill" : "mic.slash.fill", isOn: microphoneOn,
                           help: model.microphoneAllowed
                               ? "Record the microphone"
                               : "ClearShot may not use the microphone. Allow it in System Settings → Privacy & Security → Microphone.") {
                    settings.recordsMicrophone.toggle()
                    if settings.recordsMicrophone { onMicrophoneTurnedOn() }
                }
                Menu {
                    Picker("Microphone", selection: $settings.microphoneID) {
                        Text("Default (\(Microphone.systemDefaultName ?? "System"))").tag(String?.none)
                        ForEach(model.microphones) { Text($0.name).tag(String?.some($0.id)) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Choose the microphone")
            }
            OptionChip(title: "Sound", symbol: settings.recordsSystemAudio ? "speaker.wave.2.fill" : "speaker.slash.fill",
                       isOn: settings.recordsSystemAudio, help: "Record the Mac's sound") {
                settings.recordsSystemAudio.toggle()
            }
            OptionChip(title: "Pointer", symbol: "cursorarrow", isOn: settings.recordingShowsPointer, help: "Show the mouse pointer") {
                settings.recordingShowsPointer.toggle()
            }
            OptionChip(title: "Clicks", symbol: "cursorarrow.click.2", isOn: settings.recordingShowsClicks,
                       help: "A ring pulses where you click") {
                settings.recordingShowsClicks.toggle()
            }

            ToolbarSeparator()

            Menu {
                Picker("Quality", selection: $settings.videoQuality) {
                    ForEach(VideoQuality.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                Text(settings.videoQuality.title).font(.callout.weight(.medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Smaller and Better record at normal size. Retina keeps every pixel and is about four times bigger.")

            if let changeTitle {
                ToolbarSeparator()
                ToolbarChangeButton(title: changeTitle, action: onChange)
            }
        }
    }

    private var recordButton: some View {
        ToolbarActionButton(fill: AnyShapeStyle(.red.opacity(0.9)), help: "Start recording (Enter)", action: onRecord) {
            if let count = model.countdown {
                Text("\(count)")
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            } else {
                Circle().fill(.white).frame(width: 8, height: 8)
                Text("Record")
            }
        }
        .disabled(model.countdown != nil)
        .animation(.snappy(duration: 0.25), value: model.countdown)
    }

    private var microphoneOn: Bool { settings.recordsMicrophone && model.microphoneAllowed }
}

/// A microphone the recording can use.
struct Microphone: Identifiable, Hashable {
    let id: String
    let name: String

    /// Every microphone connected now: built in, USB, Bluetooth, Continuity.
    static func all() -> [Microphone] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified)
            .devices
            .map { Microphone(id: $0.uniqueID, name: $0.localizedName) }
    }

    static var systemDefaultName: String? {
        AVCaptureDevice.default(for: .audio)?.localizedName
    }
}
