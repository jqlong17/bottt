import AppKit
import SwiftUI

struct PetView: View {
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        let span = CGFloat(viewModel.petSpan)
        let canvas = PetMetrics.canvasSize(span: span)
        VStack(spacing: 0) {
            ZStack {
                if !viewModel.caption.isEmpty {
                    Text(viewModel.caption)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }
            .frame(width: canvas.width, height: PetMetrics.captionBand)
            .allowsHitTesting(false)
            PetSprite(
                talking: viewModel.mood == .talking,
                blinking: viewModel.blinking,
                bodyColor: viewModel.bodyColor,
                span: span
            )
            .overlay {
                PetClickSurface(
                    talking: viewModel.mood == .talking,
                    span: span,
                    settingsOpen: viewModel.showSettings,
                    onClick: {
                        NSApp.activate()
                        viewModel.copyPrompt()
                    },
                    onRightClick: {
                        NSApp.activate()
                        viewModel.showSettings = true
                    }
                )
            }
        }
        .popover(isPresented: $viewModel.showSettings, arrowEdge: .top) {
            PetSettingsPanel(viewModel: viewModel)
        }
        .fixedSize()
        .containerBackground(.clear, for: .window)
        .background(Color.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BOTTT")
        .accessibilityHint("Click to copy a summary prompt and hear a short confirmation. Right-click for color, size, and voice.")
        .accessibilityAddTraits(.isButton)
    }
}

private struct PetSettingsPanel: View {
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BOTTT")
                .font(.headline)
            ColorPicker("身体颜色", selection: $viewModel.bodyColor, supportsOpacity: false)
            VStack(alignment: .leading, spacing: 6) {
                Text("大小 \(Int(viewModel.petSpan.rounded()))")
                    .font(.subheadline)
                Slider(
                    value: $viewModel.petSpan,
                    in: Double(PetMetrics.minSpan)...Double(PetMetrics.maxSpan),
                    step: 1
                )
            }
            Picker("语音", selection: $viewModel.voiceID) {
                ForEach(viewModel.voiceChoices()) { choice in
                    Text(choice.title).tag(choice.id)
                }
            }
            ForEach(viewModel.blockedVoices(), id: \.0.id) { item in
                Text("\(item.0.title)：\(item.1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}

/// 只有宠物像素接收点击和拖动。空白处把鼠标还给桌面。
private struct PetClickSurface: NSViewRepresentable {
    var talking: Bool
    var span: CGFloat
    var settingsOpen: Bool
    var onClick: () -> Void
    var onRightClick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PetDragView {
        let view = PetDragView()
        view.onClick = onClick
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: PetDragView, context: Context) {
        nsView.onClick = onClick
        nsView.onRightClick = onRightClick
        nsView.talking = talking
        nsView.span = span
        nsView.settingsOpen = settingsOpen
        nsView.onWindow = { window in
            context.coordinator.attach(window, view: nsView)
        }
        if let window = nsView.window {
            context.coordinator.attach(window, view: nsView)
            context.coordinator.noteSpan(span, window: window)
        }
    }

    final class Coordinator {
        private var chromeReady = false
        private var didPark = false
        private var appliedSpan: CGFloat = 0
        private var hoverTimer: Timer?
        private weak var window: NSWindow?
        private weak var dragView: PetDragView?

        func attach(_ window: NSWindow, view: PetDragView) {
            self.window = window
            dragView = view
            window.identifier = NSUserInterfaceItemIdentifier("bottt")
            window.title = "BOTTT"
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .floating
            window.hidesOnDeactivate = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovable = true
            window.isMovableByWindowBackground = false
            window.styleMask.insert(.fullSizeContentView)
            window.styleMask.remove(.resizable)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
            window.contentView?.layer?.isOpaque = false
            if !chromeReady {
                window.ignoresMouseEvents = true
            }

            guard !chromeReady else { return }
            chromeReady = true
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                self?.updateClickThrough()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.park()
            }
            // 系统会在这之后把上次的大窗口框套回来，再摆一次才是小窗。
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.didPark = false
                self?.park()
            }
        }

        func noteSpan(_ span: CGFloat, window: NSWindow) {
            guard didPark, abs(span - appliedSpan) > 0.5 else { return }
            resizeKeepingFeet(window, span: span)
        }

        private func park() {
            guard !didPark, let window, let dragView else { return }
            let size = PetMetrics.windowSize(span: dragView.span)
            guard size.width >= PetMetrics.minSpan else { return }
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? window.screen ?? NSScreen.main
            guard let screen else { return }
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: min(max(visible.maxX - size.width - 24, visible.minX + 8), visible.maxX - size.width - 8),
                y: min(max(visible.minY + 24, visible.minY + 8), visible.maxY - size.height - 8)
            )
            window.setFrame(NSRect(origin: origin, size: size), display: true)
            appliedSpan = dragView.span
            didPark = true
        }

        private func resizeKeepingFeet(_ window: NSWindow, span: CGFloat) {
            let size = PetMetrics.windowSize(span: span)
            var frame = window.frame
            frame.origin.y += frame.height - size.height
            frame.size = size
            window.setFrame(frame, display: true)
            appliedSpan = span
        }

        private func updateClickThrough() {
            guard let window, let dragView else { return }
            if dragView.isDragging || dragView.settingsOpen {
                window.ignoresMouseEvents = false
                return
            }
            let overPet = dragView.containsPet(screenPoint: NSEvent.mouseLocation)
            window.ignoresMouseEvents = !overPet
        }

        deinit {
            hoverTimer?.invalidate()
        }
    }
}

private final class PetDragView: NSView {
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onWindow: ((NSWindow) -> Void)?
    var talking = false
    var span: CGFloat = PetMetrics.defaultSpan
    var settingsOpen = false
    private(set) var isDragging = false
    private var screenStart: NSPoint?
    private var windowStart: NSPoint?
    private var dragged = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onWindow?(window)
        }
    }

    func containsPet(screenPoint: NSPoint) -> Bool {
        guard let window else { return false }
        guard window.frame.contains(screenPoint) else { return false }
        let inWindow = window.convertPoint(fromScreen: screenPoint)
        let local = convert(inWindow, from: nil)
        return PetMetrics.isSolid(point: local, bounds: bounds, span: span, talking: talking)
    }

    override func mouseDown(with event: NSEvent) {
        screenStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin
        dragged = false
        isDragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let screenStart, let windowStart, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - screenStart.x
        let dy = now.y - screenStart.y
        if hypot(dx, dy) > 3 {
            dragged = true
        }
        window.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if !dragged {
            onClick?()
        }
        screenStart = nil
        windowStart = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }
}
