import Foundation

/// 本机日程：早间举重、午间/傍晚说心情、偶尔忙碌姿势。
@MainActor
final class PetSchedule {
    enum Slot: String {
        case morningLift
        case middayMood
        case eveningMood
    }

    struct Window {
        let slot: Slot
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int
    }

    /// 6:00–7:30 举重说一句；11:30–12:30 / 17:30–18:30 说心情（错过可在窗口内补说）。
    static let windows: [Window] = [
        Window(slot: .morningLift, startHour: 6, startMinute: 0, endHour: 7, endMinute: 30),
        Window(slot: .middayMood, startHour: 11, startMinute: 30, endHour: 12, endMinute: 30),
        Window(slot: .eveningMood, startHour: 17, startMinute: 30, endHour: 18, endMinute: 30),
    ]

    private let defaults: UserDefaults
    private var timer: Timer?
    private var busyTask: Task<Void, Never>?
    private weak var host: PetViewModel?
    private var lastBusyAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func start(host: PetViewModel) {
        self.host = host
        timer?.invalidate()
        let tick = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluate()
            }
        }
        RunLoop.main.add(tick, forMode: .common)
        timer = tick
        evaluate()
        scheduleNextBusy()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        busyTask?.cancel()
        busyTask = nil
    }

    private func evaluate() {
        guard let host else { return }
        let now = Date()
        let calendar = Calendar.current
        for window in Self.windows {
            guard isInside(window, now: now, calendar: calendar) else { continue }
            guard !alreadyFired(window.slot, on: now, calendar: calendar) else { continue }
            fire(window.slot, host: host, on: now, calendar: calendar)
        }
    }

    private func fire(_ slot: Slot, host: PetViewModel, on day: Date, calendar: Calendar) {
        markFired(slot, on: day, calendar: calendar)
        switch slot {
        case .morningLift:
            host.performScheduledLift()
        case .middayMood, .eveningMood:
            host.performScheduledMood(slot: slot)
        }
    }

    private func scheduleNextBusy() {
        busyTask?.cancel()
        // 平时偶尔摆一下忙碌姿势，不出声。间隔大约 12–28 分钟。
        let delay = Double.random(in: 12 * 60...28 * 60)
        busyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, let host = self.host else { return }
            let now = Date()
            if let last = self.lastBusyAt, now.timeIntervalSince(last) < 10 * 60 {
                self.scheduleNextBusy()
                return
            }
            // 说话或其它日程姿势进行中就跳过这一轮。
            if host.pose == .stand {
                self.lastBusyAt = now
                host.flashBusyPose()
            }
            self.scheduleNextBusy()
        }
    }

    private func isInside(_ window: Window, now: Date, calendar: Calendar) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let start = window.startHour * 60 + window.startMinute
        let end = window.endHour * 60 + window.endMinute
        return minutes >= start && minutes < end
    }

    private func dayKey(_ slot: Slot) -> String {
        "bottt.schedule.\(slot.rawValue).day"
    }

    private func alreadyFired(_ slot: Slot, on day: Date, calendar: Calendar) -> Bool {
        let stamp = Self.dayStamp(day, calendar: calendar)
        return defaults.string(forKey: dayKey(slot)) == stamp
    }

    private func markFired(_ slot: Slot, on day: Date, calendar: Calendar) {
        defaults.set(Self.dayStamp(day, calendar: calendar), forKey: dayKey(slot))
    }

    private static func dayStamp(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
