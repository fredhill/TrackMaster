import IOKit
import IOKit.hid
import Foundation
import SwiftUI

// HIDManager owns the IOHIDManager, handles device connect/disconnect,
// and feeds raw button/scroll events to the rest of the pipeline.
// All callbacks are scheduled on the main run loop.

@MainActor
final class HIDManager: ObservableObject {

    static let vendorID  = 0x047D
    static let productID = 0x1020

    // Callbacks wired up by AppDelegate
    var onDeviceConnected: (() -> Void)?
    var onDeviceDisconnected: (() -> Void)?
    var onButtonDown: ((ButtonID) -> Void)?
    var onButtonUp: ((ButtonID) -> Void)?
    var onScroll: ((Int) -> Void)?          // delta: positive = up/forward

    @Published var isDeviceConnected = false

    // Log entries exposed to the debug HID logger
    @Published var logEntries: [HIDLogEntry] = []

    private var hidManager: IOHIDManager?

    // MARK: - Lifecycle

    func start() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let matching: [String: Any] = [
            kIOHIDVendorIDKey:  HIDManager.vendorID,
            kIOHIDProductIDKey: HIDManager.productID,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterInputValueCallback(manager, hidValueCallback, selfPtr)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceConnectedCallback, selfPtr)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceRemovedCallback, selfPtr)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        self.hidManager = manager
    }

    func stop() {
        guard let manager = hidManager else { return }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        hidManager = nil
    }

    // MARK: - Internal handlers (called from C callbacks via MainActor.assumeIsolated)

    // Called with pre-extracted primitives so no CF type crosses the actor boundary
    fileprivate func handleHIDData(usagePage: UInt32, usage: UInt32, intValue: Int, timestamp: UInt64) {
        appendLog(usagePage: usagePage, usage: usage, value: intValue, timestamp: timestamp)

        switch (usagePage, usage) {
        case (UInt32(kHIDPage_Button), let btn):
            guard let buttonID = ButtonID(rawValue: Int(btn)) else { return }
            if intValue == 1 {
                onButtonDown?(buttonID)
            } else {
                onButtonUp?(buttonID)
            }

        case (UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Wheel)):
            onScroll?(Int(intValue))

        default:
            break
        }
    }

    fileprivate func handleDeviceConnected() {
        isDeviceConnected = true
        onDeviceConnected?()
    }

    fileprivate func handleDeviceRemoved() {
        isDeviceConnected = false
        onDeviceDisconnected?()
    }

    // MARK: - Log

    private func appendLog(usagePage: UInt32, usage: UInt32, value: Int, timestamp: UInt64) {
        let entry = HIDLogEntry(
            timestamp: timestamp,
            usagePage: usagePage,
            usage: usage,
            value: value
        )
        logEntries.append(entry)
        if logEntries.count > 500 { logEntries.removeFirst() }
    }
}

// MARK: - Log Entry

struct HIDLogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: UInt64
    let usagePage: UInt32
    let usage: UInt32
    let value: Int

    var description: String {
        let page = usagePage == UInt32(kHIDPage_Button) ? "Button" : String(format: "Page 0x%02X", usagePage)
        return String(format: "[%llu]  %@  usage=0x%02X  value=%d", timestamp, page, usage, value)
    }
}

// MARK: - C-style IOKit callbacks (scheduled on main run loop)

private let hidValueCallback: IOHIDValueCallback = { context, _, _, value in
    guard let context else { return }
    let manager = Unmanaged<HIDManager>.fromOpaque(context).takeUnretainedValue()
    // Extract all data from the CF types here, before crossing the actor boundary
    let element   = IOHIDValueGetElement(value)
    let usagePage = IOHIDElementGetUsagePage(element)
    let usage     = IOHIDElementGetUsage(element)
    let intValue  = Int(IOHIDValueGetIntegerValue(value))
    let timestamp = IOHIDValueGetTimeStamp(value)
    MainActor.assumeIsolated {
        manager.handleHIDData(usagePage: usagePage, usage: usage, intValue: intValue, timestamp: timestamp)
    }
}

private let deviceConnectedCallback: IOHIDDeviceCallback = { context, _, _, _ in
    guard let context else { return }
    let manager = Unmanaged<HIDManager>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { manager.handleDeviceConnected() }
}

private let deviceRemovedCallback: IOHIDDeviceCallback = { context, _, _, _ in
    guard let context else { return }
    let manager = Unmanaged<HIDManager>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { manager.handleDeviceRemoved() }
}
