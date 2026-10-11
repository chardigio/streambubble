import AppKit
import StreamBubbleKit
import SwiftUI

@main
struct StreamBubbleApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        switch model.state {
        case .recording:
            Label { Text(AppModel.clock(model.flow.elapsedSeconds)) } icon: { Image(nsImage: .menuBarGlyph(paused: false)) }
                .labelStyle(.titleAndIcon)
        case .paused:
            Label { Text(AppModel.clock(model.flow.elapsedSeconds)) } icon: { Image(nsImage: .menuBarGlyph(paused: true)) }
                .labelStyle(.titleAndIcon)
        case let .countingDown(n):
            Label { Text("\(n)") } icon: { Image(nsImage: .menuBarGlyph(paused: false)) }
                .labelStyle(.titleAndIcon)
        case .idle, .preparing, .starting, .finishing:
            Image(nsImage: .menuBarGlyph(paused: false))
        }
    }
}

extension NSImage {
    /// The menu bar glyph as a template image, so macOS tints it for a light or dark menu bar.
    /// The drawing handler runs at each display scale, so the lines stay sharp.
    static func menuBarGlyph(paused: Bool) -> NSImage {
        let image = NSImage(size: MenuBarGlyph.size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            MenuBarGlyph.draw(in: context, paused: paused)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = paused ? "StreamBubble, paused" : "StreamBubble"
        return image
    }
}

private struct MenuContent: View {
    @Bindable var model: AppModel

    var body: some View {
        Text(model.statusTitle)
        if let warning = model.hotKeyWarning {
            Text(warning)
        }

        Divider()

        Button(model.toggleTitle) { model.flow.toggle() }
            .keyboardShortcut("l", modifiers: [.command, .control, .option, .shift])
            .disabled(!model.state.canToggle)

        if model.state.canPauseToggle {
            Button(model.state == .paused ? "Resume" : "Pause") { model.flow.togglePause() }
                .keyboardShortcut("p", modifiers: [.command, .control, .option, .shift])
        }

        Divider()

        Picker("Record", selection: $model.captureMode) {
            ForEach(CaptureMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.inline)
        .disabled(model.state.isBusy)

        Divider()

        Toggle("Show Camera Bubble", isOn: Binding(
            get: { model.isBubbleShown },
            set: { shown in Task { await model.setBubbleShown(shown) } }
        ))
        Picker("Bubble Size", selection: Binding(
            get: { model.bubbleSize },
            set: { model.setBubbleSize($0) }
        )) {
            ForEach(BubbleSize.allCases) { size in
                Text(size.title).tag(size)
            }
        }
        .pickerStyle(.menu)
        .disabled(!model.isBubbleShown)
        Menu("Bubble Border") {
            Toggle("White Ring", isOn: $model.bubbleStyle.showsRing)
            Toggle("Drop Shadow", isOn: $model.bubbleStyle.showsShadow)
        }
        // The checkmark shows the macOS Portrait state. A click opens the system panel, because
        // only the user can turn the effect on or off there.
        Toggle("Blur Background…", isOn: Binding(
            get: { model.isBackgroundBlurOn },
            set: { _ in model.openVideoEffects() }
        ))
        .disabled(!model.isBubbleShown)

        Divider()

        Button("Open Recordings Folder") { model.openRecordingsFolder() }
        Button("Quit StreamBubble") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
            .disabled(model.state.isBusy)
    }
}
