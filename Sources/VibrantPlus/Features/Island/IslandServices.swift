// SPDX-FileCopyrightText: 2026 ARJO LAB
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Darwin
import EventKit
import IOKit.ps
import IOKit.pwr_mgt
import Observation
import VibrantPlusKit

// MARK: - Calendar

/// Today's events and the next meeting, read-only through EventKit.
@Observable
final class CalendarService {
    static let shared = CalendarService()

    struct Event: Identifiable, Equatable {
        var id: String
        var title: String
        var start: Date
        var end: Date
        var allDay: Bool
        var color: NSColor?
        var meeting: (service: MeetingLinks.Service, url: URL)?

        static func == (a: Event, b: Event) -> Bool { a.id == b.id && a.start == b.start && a.title == b.title }
    }

    private(set) var today: [Event] = []
    private(set) var next: Event?
    private(set) var access: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    private(set) var calendars: [(id: String, title: String)] = []

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observer: NSObjectProtocol?

    var granted: Bool { access == .fullAccess }

    func start() {
        guard timer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        timer = Timer.repeating(every: 60) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        reload()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    func requestAccess() {
        Task {
            _ = try? await store.requestFullAccessToEvents()
            self.access = EKEventStore.authorizationStatus(for: .event)
            self.reload()
        }
    }

    func reload() {
        access = EKEventStore.authorizationStatus(for: .event)
        guard granted else { today = []; next = nil; return }
        let cal = Calendar.current
        let now = Date.now
        let startOfDay = cal.startOfDay(for: now)
        let end = now.addingTimeInterval(24 * 3600)
        let eventCalendars = store.calendars(for: .event)
        calendars = eventCalendars.map { ($0.calendarIdentifier, $0.title) }
            .sorted { $0.1.localizedStandardCompare($1.1) == .orderedAscending }
        let selected = Prefs.shared.selectedCalendarIDs
        let allowed = selected.isEmpty ? nil : eventCalendars.filter { selected.contains($0.calendarIdentifier) }
        let predicate = store.predicateForEvents(withStart: startOfDay, end: max(end, cal.date(byAdding: .day, value: 1, to: startOfDay)!), calendars: allowed)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }.map { e in
            Event(id: e.calendarItemIdentifier, title: e.title ?? "Ohne Titel", start: e.startDate, end: e.endDate,
                  allDay: e.isAllDay, color: e.calendar.map { NSColor(cgColor: $0.cgColor) } ?? nil,
                  meeting: MeetingLinks.find(in: [e.url?.absoluteString, e.location, e.notes]))
        }
        today = events.filter { cal.isDateInToday($0.start) || ($0.start < now && $0.end > now) }
        next = events.first { !$0.allDay && $0.end > now }
    }

    /// Fictional events for snapshots and marketing images.
    func loadSample() {
        access = .fullAccess
        let now = Date.now
        let review = Event(id: "s1", title: "Design-Review", start: now.addingTimeInterval(12 * 60), end: now.addingTimeInterval(57 * 60),
                           allDay: false, color: .systemBlue, meeting: (.meet, URL(string: "https://meet.google.com/abc-defg-hij")!))
        let lunch = Event(id: "s2", title: "Mittagessen mit Team", start: now.addingTimeInterval(3 * 3600), end: now.addingTimeInterval(4 * 3600),
                          allDay: false, color: .systemOrange, meeting: nil)
        today = [review, lunch]
        next = review
    }

    func open(_ event: Event) {
        // Calendar shows the day; EventKit offers no public deep link to one event.
        let interval = event.start.timeIntervalSinceReferenceDate
        if let url = URL(string: "ical://ekevent/\(Int(interval))") { NSWorkspace.shared.open(url) }
    }
}

// MARK: - Weather

/// Weather from Open-Meteo. Only the city name the person typed is sent; never the location.
@Observable
final class WeatherService {
    static let shared = WeatherService()

    struct Current: Equatable {
        var place: String
        var temperature: Double
        var feelsLike: Double
        var code: Int
        var isDay: Bool
        var high: Double
        var low: Double
        var sunrise: String
        var sunset: String
        /// Temperature of the next hours, from this hour on (at most 12).
        var hours: [Double] = []
        var fetched: Date = .now
    }

    private(set) var current: Current?
    private(set) var error: String?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var lastCity = ""

    /// Fictional weather for snapshots and marketing images.
    func loadSample() {
        current = Current(place: "Zürich", temperature: 14, feelsLike: 12, code: 1, isDay: true, high: 16, low: 8,
                          sunrise: "07:21", sunset: "16:58", hours: [14, 15, 16, 16, 15, 13, 12, 11, 10, 9, 8, 8], fetched: .now)
    }

    func start() {
        guard timer == nil else { return }
        // Live: every 10 minutes, and again when the island opens (refreshIfStale).
        timer = Timer.repeating(every: 10 * 60) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(force: true) }
        }
        refresh(force: true)
    }

    /// Reads again when the last reading is older than 10 minutes.
    func refreshIfStale() {
        guard timer != nil else { return }
        if current.map({ Date.now.timeIntervalSince($0.fetched) > 10 * 60 }) ?? true { refresh(force: true) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        task?.cancel()
        task = nil
    }

    func refresh(force: Bool = false) {
        let city = Prefs.shared.weatherCity.trimmingCharacters(in: .whitespaces)
        guard !city.isEmpty else { current = nil; error = nil; task?.cancel(); task = nil; return }
        if !force && city == lastCity && current != nil { return }
        lastCity = city
        // A newer request makes an older one moot: it must never overwrite the newer answer.
        task?.cancel()
        task = Task {
            do {
                let answer = try await Self.fetch(city: city)
                guard !Task.isCancelled, city == self.lastCity else { return }
                self.current = answer
                self.error = nil
            } catch {
                guard !Task.isCancelled, city == self.lastCity else { return }
                self.error = "Wetter nicht verfügbar"
            }
        }
    }

    nonisolated static func fetch(city: String) async throws -> Current {
        struct Geo: Decodable { struct R: Decodable { var name: String; var latitude: Double; var longitude: Double }; var results: [R]? }
        struct Forecast: Decodable {
            struct C: Decodable { var time: String; var temperature_2m: Double; var apparent_temperature: Double?; var weather_code: Int; var is_day: Int }
            struct H: Decodable { var time: [String]; var temperature_2m: [Double] }
            struct D: Decodable { var temperature_2m_max: [Double]; var temperature_2m_min: [Double]; var sunrise: [String]; var sunset: [String] }
            var current: C
            var daily: D
            var hourly: H?
        }
        var g = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        g.queryItems = [.init(name: "name", value: city), .init(name: "count", value: "1"), .init(name: "language", value: "de")]
        let (gd, _) = try await URLSession.shared.data(from: g.url!)
        guard let place = try JSONDecoder().decode(Geo.self, from: gd).results?.first else { throw URLError(.badServerResponse) }
        var f = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        f.queryItems = [.init(name: "latitude", value: String(place.latitude)), .init(name: "longitude", value: String(place.longitude)),
                        .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
                        .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,sunrise,sunset"),
                        .init(name: "hourly", value: "temperature_2m"),
                        // Two days, so the next twelve hours are there in the evening too.
                        .init(name: "forecast_days", value: "2"), .init(name: "timezone", value: "auto")]
        let (fd, _) = try await URLSession.shared.data(from: f.url!)
        let w = try JSONDecoder().decode(Forecast.self, from: fd)
        func time(_ s: [String]) -> String { s.first.map { String($0.suffix(5)) } ?? "–" }
        return Current(place: place.name, temperature: w.current.temperature_2m, feelsLike: w.current.apparent_temperature ?? w.current.temperature_2m,
                       code: w.current.weather_code, isDay: w.current.is_day == 1,
                       high: w.daily.temperature_2m_max.first ?? 0, low: w.daily.temperature_2m_min.first ?? 0,
                       sunrise: time(w.daily.sunrise), sunset: time(w.daily.sunset),
                       hours: w.hourly.map { WeatherHours.next(times: $0.time, values: $0.temperature_2m, now: w.current.time) } ?? [],
                       fetched: .now)
    }
}

// MARK: - System stats

/// CPU, memory, disk and battery. Measured only while someone looks (the island is open),
/// plus a slow check for the health notes.
@Observable
final class SystemStats {
    static let shared = SystemStats()

    private(set) var cpu: Double = 0
    private(set) var memoryUsed: Double = 0     // GB
    private(set) var memoryTotal: Double = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    private(set) var diskFree: Double = 0       // GB
    private(set) var battery: Int?
    private(set) var charging = false
    private(set) var memoryCritical = false
    private(set) var alerts: [HealthAlerts.Alert] = []

    @ObservationIgnored private var lastTicks: (busy: UInt64, total: UInt64)?
    @ObservationIgnored private var fastTimer: Timer?
    @ObservationIgnored private var slowTimer: Timer?
    @ObservationIgnored private var pressure: DispatchSourceMemoryPressure?
    @ObservationIgnored var onNewAlert: ((HealthAlerts.Alert) -> Void)?

    func startSlow() {
        guard slowTimer == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical, .normal], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let p = self.pressure else { return }
                self.memoryCritical = p.data.contains(.critical)
                self.checkAlerts()
            }
        }
        source.resume()
        pressure = source
        slowTimer = Timer.repeating(every: 120) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample(); self?.checkAlerts() }
        }
        sample()
        checkAlerts()
    }

    func stopSlow() {
        slowTimer?.invalidate(); slowTimer = nil
        pressure?.cancel(); pressure = nil
    }

    /// While the island is open: every 2 seconds.
    func setLive(_ live: Bool) {
        if live, fastTimer == nil {
            sample()
            fastTimer = Timer.repeating(every: 2) { [weak self] _ in
                MainActor.assumeIsolated { self?.sample() }
            }
        } else if !live {
            fastTimer?.invalidate(); fastTimer = nil
        }
    }

    func sample() {
        cpu = Self.cpuUsage(&lastTicks)
        memoryUsed = Self.memoryUsedGB()
        if let free = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage {
            diskFree = Double(free) / 1_000_000_000
        }
        (battery, charging) = Self.batteryState()
    }

    private func checkAlerts() {
        guard Prefs.shared.healthNotes else { alerts = []; return }
        let new = HealthAlerts.alerts(freeDiskGB: diskFree, memoryPressureCritical: memoryCritical, battery: battery,
                                      charging: charging, thermal: ProcessInfo.processInfo.thermalState.rawValue)
        for a in new where !alerts.contains(a) { onNewAlert?(a) }
        alerts = new
    }

    nonisolated static func cpuUsage(_ last: inout (busy: UInt64, total: UInt64)?) -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return 0 }
        let user = UInt64(info.cpu_ticks.0), sys = UInt64(info.cpu_ticks.1), idle = UInt64(info.cpu_ticks.2), nice = UInt64(info.cpu_ticks.3)
        let busy = user + sys + nice, total = busy + idle
        defer { last = (busy, total) }
        guard let l = last, total > l.total else { return 0 }
        return Double(busy - l.busy) / Double(total - l.total)
    }

    nonisolated static func memoryUsedGB() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return 0 }
        let page = Double(sysconf(_SC_PAGESIZE))
        // Activity Monitor's "Memory Used": app memory + wired + compressed.
        let app = Double(stats.internal_page_count) - Double(stats.purgeable_count)
        let used = (app + Double(stats.wire_count) + Double(stats.compressor_page_count)) * page
        return used / 1_073_741_824
    }

    nonisolated static func compressorShare() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return 0 }
        let internalPages = UInt64(max(0, Int64(stats.internal_page_count) - Int64(stats.purgeable_count)))
        return MemoryPressurePlan.compressorShare(compressor: UInt64(stats.compressor_page_count),
                                                  wired: UInt64(stats.wire_count),
                                                  internalPages: internalPages)
    }

    nonisolated static func batteryHealth() -> (percent: Int?, cycles: Int?) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return (nil, nil) }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let maxCap = d[kIOPSMaxCapacityKey] as? Int
            let design = d["DesignCapacity"] as? Int
            let cycles = d["CycleCount"] as? Int ?? d["Cycle Count"] as? Int
            return (BatteryHealthPlan.percent(maxCapacity: maxCap, designCapacity: design), cycles)
        }
        return (nil, nil)
    }

    nonisolated static func batteryState() -> (Int?, Bool) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return (nil, false) }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let cap = d[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = d[kIOPSMaxCapacityKey] as? Int ?? 100
            let charging = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return (max > 0 ? cap * 100 / max : cap, charging)
        }
        return (nil, false)
    }
}

// MARK: - Clipboard history

/// The clipboard history: texts and small images. History stays in memory only; only what
/// you pin is saved (pinned.json). Items that password managers mark as concealed or
/// transient are skipped.
@Observable
final class ClipboardHistory {
    static let shared = ClipboardHistory()
    init() {}

    private(set) var list = ClipList()
    private(set) var images: [UUID: NSImage] = [:]
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var changedAt = Date.now
    @ObservationIgnored private var sleepObserver: NSObjectProtocol?
    @ObservationIgnored private var lastChange = NSPasteboard.general.changeCount
    @ObservationIgnored private let file = JSONFile<[ClipItem]>(url: Paths.pinnedClips)

    /// Newest first, pinned on top.
    var items: [ClipItem] { list.visible(matching: "") }

    func start() {
        guard timer == nil else { return }
        if list.items.isEmpty, let pinned = file.load() { list = ClipList(items: pinned) }
        changedAt = .now
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { if Prefs.shared.clipboardClearOnSleep { ClipboardHistory.shared.clearSystemClipboard() } }
        }
        timer = Timer.repeating(every: 1) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil; list = ClipList(); images = [:]
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        sleepObserver = nil
    }

    private func clearSystemClipboard() {
        NSPasteboard.general.clearContents()
        lastChange = NSPasteboard.general.changeCount
        changedAt = .now
    }

    private func poll() {
        let pb = NSPasteboard.general
        if pb.changeCount == lastChange {
            let delay = Prefs.shared.clipboardClearAfter
            if delay > 0 && Date.now.timeIntervalSince(changedAt) >= delay && !(pb.types ?? []).isEmpty { clearSystemClipboard() }
            return
        }
        lastChange = pb.changeCount
        changedAt = .now
        let skip: [NSPasteboard.PasteboardType] = [.init("org.nspasteboard.ConcealedType"), .init("org.nspasteboard.TransientType"),
                                                   .init("org.nspasteboard.AutoGeneratedType")]
        if pb.types?.contains(where: skip.contains) == true { return }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty, urls.allSatisfy(\.isFileURL) {
            _ = list.add(files: urls.map(\.path))
        } else if let text = pb.string(forType: .string) {
            ingest(text)
        } else if let image = NSImage(pasteboard: pb), image.size.width > 0 {
            let item = list.add(image: "Bild \(Int(image.size.width)) × \(Int(image.size.height))")
            images[item.id] = image
            // Keep memory small: drop images that fell out of the list.
            let alive = Set(list.items.map(\.id))
            images = images.filter { alive.contains($0.key) }
        }
    }

    func ingest(_ text: String) { list.add(text: text) }

    func copy(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text: pb.setString(item.text, forType: .string)
        case .image: if let image = images[item.id] { pb.writeObjects([image]) }
        case .file:
            let urls = item.text.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }.filter { FileManager.default.fileExists(atPath: $0.path) }
            if !urls.isEmpty { pb.writeObjects(urls as [NSURL]) }
        }
        lastChange = pb.changeCount
    }

    func paste(_ item: ClipItem) {
        copy(item)
        InputTools.postKey(9, flags: .maskCommand)
    }

    func togglePin(_ item: ClipItem) {
        // Images are not saved to disk: they cannot be pinned.
        guard item.kind == .text else { return }
        list.togglePin(item.id)
        persistPinned()
    }

    func remove(_ item: ClipItem) {
        list.remove(item.id)
        images[item.id] = nil
        persistPinned()
    }

    func clearUnpinned() {
        list.clearUnpinned()
        let alive = Set(list.items.map(\.id))
        images = images.filter { alive.contains($0.key) }
    }

    private func persistPinned() { SaveReport.attempt("Angeheftete Texte") { try file.save(list.pinned) } }
}

// MARK: - Recent apps

@Observable
final class RecentApps {
    static let shared = RecentApps()
    private(set) var apps: [NSRunningApplication] = []
    @ObservationIgnored private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                                     object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, let app, app.activationPolicy == .regular, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
                self.apps.removeAll { $0.processIdentifier == app.processIdentifier }
                self.apps.insert(app, at: 0)
                self.apps = Array(self.apps.filter { !$0.isTerminated }.prefix(8))
            }
        }
        if let front = NSWorkspace.shared.frontmostApplication, front.activationPolicy == .regular { apps = [front] }
    }

    func stop() {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
    }
}

// MARK: - System controls

/// Focus rules: what a focus session switches on the Mac, and puts back afterwards.
@MainActor
final class FocusMode {
    static let shared = FocusMode()
    private var before: FocusSnapshot?
    private var applied = FocusRules()

    func began() {
        let rules = Prefs.shared.focusRules
        let c = SystemControls.shared
        c.refresh()
        let snapshot = FocusSnapshot(darkMode: c.darkMode, desktopIconsHidden: c.desktopIconsHidden, keepAwake: c.keepAwake)
        before = snapshot
        applied = rules
        run(FocusPlan.start(rules, current: snapshot))
    }

    func ended() {
        guard let before else { return }
        run(FocusPlan.end(applied, before: before))
        self.before = nil
    }

    func run(_ actions: [FocusPlan.Action]) {
        let c = SystemControls.shared
        for a in actions {
            switch a {
            case .toggleDoNotDisturb: c.toggleFocus()
            case .setDarkMode(let on): c.setDarkMode(on)
            case .setDesktopIconsHidden(let on): c.setDesktopIconsHidden(on)
            case .setKeepAwake(let on): c.setKeepAwake(on)
            }
        }
    }
}

/// Switches from the Controls tile. Each one changes something a person can switch back.
@Observable
final class SystemControls {
    static let shared = SystemControls()

    private(set) var darkMode = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    private(set) var desktopIconsHidden = UserDefaults(suiteName: "com.apple.finder")?.object(forKey: "CreateDesktop") as? Bool == false
    private(set) var hiddenFilesShown = UserDefaults(suiteName: "com.apple.finder")?.bool(forKey: "AppleShowAllFiles") ?? false
    private(set) var keepAwake = false
    var message: String?
    @ObservationIgnored private var assertion: IOPMAssertionID = 0

    func refresh() {
        // The global domain is part of the standard search list.
        darkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    func setDarkMode(_ on: Bool) {
        do {
            try Script.run("tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)")
            darkMode = on
            message = nil
        } catch Script.Failure.notAllowed {
            message = "Erlaube Vibrant+ in Systemeinstellungen › Datenschutz › Automation, System Events zu steuern."
        } catch {
            message = "Der Dunkelmodus liess sich nicht umstellen."
        }
    }

    func setDesktopIconsHidden(_ hidden: Bool) {
        finderDefault("CreateDesktop", value: hidden ? "false" : "true")
        desktopIconsHidden = hidden
    }

    func setHiddenFilesShown(_ shown: Bool) {
        finderDefault("AppleShowAllFiles", value: shown ? "true" : "false")
        hiddenFilesShown = shown
    }

    private func finderDefault(_ key: String, value: String) {
        Task {
            _ = await Run.async("/usr/bin/defaults", ["write", "com.apple.finder", key, "-bool", value])
            _ = await Run.async("/usr/bin/killall", ["Finder"])
        }
    }

    func setKeepAwake(_ on: Bool) {
        if on, assertion == 0 {
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Vibrant+ hält den Mac wach" as CFString, &assertion)
        } else if !on, assertion != 0 {
            IOPMAssertionRelease(assertion)
            assertion = 0
        }
        keepAwake = assertion != 0
    }

    /// Asks first: emptying the Trash cannot be undone.
    func emptyTrash() {
        let alert = NSAlert()
        alert.messageText = "Papierkorb leeren?"
        alert.informativeText = "Die Objekte im Papierkorb werden endgültig gelöscht. Das lässt sich nicht widerrufen."
        alert.addButton(withTitle: "Papierkorb leeren")
        alert.addButton(withTitle: "Abbrechen")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            // A full Trash takes a while; Finder keeps going even if this answer times out.
            try Script.run("tell application \"Finder\" to empty the trash", timeout: 30)
        } catch Script.Failure.notAllowed {
            message = "Erlaube Vibrant+ in Systemeinstellungen › Datenschutz › Automation, den Finder zu steuern."
        } catch {}
    }

    /// Do Not Disturb through a Shortcuts shortcut the person creates once.
    func toggleFocus() {
        Task {
            let r = await Run.async("/usr/bin/shortcuts", ["run", "Vibrant DND"], timeout: 15)
            if r.status != 0 {
                message = "Lege in Kurzbefehle einen Kurzbefehl «Vibrant DND» mit der Aktion «Fokus festlegen» (Nicht stören umschalten) an."
            }
        }
    }

    func displaySleep() { Task { _ = await Run.async("/usr/bin/pmset", ["displaysleepnow"]) } }
    func sleepNow() { Task { _ = await Run.async("/usr/bin/pmset", ["sleepnow"]) } }

    /// ⌃⌘Q, the system shortcut for the lock screen. Needs Accessibility.
    func lockScreen() {
        guard Permission.accessibilityTrusted else {
            displaySleep()
            return
        }
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x0C, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x0C, keyDown: false)
        down?.flags = [.maskCommand, .maskControl]
        up?.flags = [.maskCommand, .maskControl]
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

// MARK: - Developer bar

/// Git branch of the followed project and servers listening on local ports.
@Observable
final class DevStatus {
    static let shared = DevStatus()
    private(set) var project: String?
    private(set) var branch: String?
    private(set) var servers: [ListeningPorts.Server] = []
    @ObservationIgnored private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        timer = Timer.repeating(every: 15) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func stop() { timer?.invalidate(); timer = nil; servers = []; branch = nil }

    func refresh() {
        // The project chosen in Settings, else the folder of the latest Claude Code session.
        let folder = Prefs.shared.devProject ?? AgentStore.shared.sortedSessions.first?.cwd
        if let folder, let root = GitHead.repositoryRoot(from: folder) {
            project = (root as NSString).lastPathComponent
            branch = GitHead.branch(at: root)
        } else {
            project = folder.map { ($0 as NSString).lastPathComponent }
            branch = nil
        }
        Task {
            let r = await Run.async("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"], timeout: 5)
            servers = ListeningPorts.parse(r.output).filter { $0.port >= 1024 }
        }
    }

    func open(_ server: ListeningPorts.Server) {
        if let url = URL(string: "http://localhost:\(server.port)") { NSWorkspace.shared.open(url) }
    }
}
