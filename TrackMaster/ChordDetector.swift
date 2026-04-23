import Foundation

// ChordDetector tracks which buttons are currently held and detects multi-button chords.
// It is driven by the CGEvent tap (not IOKit) so it operates on the main run loop thread.
// No locking needed — all access is from the main thread.

@MainActor
final class ChordDetector {

    // MARK: - State

    private var heldButtons: Set<ButtonID> = []
    private var consumedButtons: Set<ButtonID> = []  // suppressed because a chord fired
    private var chordPendingTimer: DispatchWorkItem? = nil
    private var safetyDelayTimer: DispatchWorkItem? = nil

    // MARK: - Callbacks (set by EventInterceptor)

    var onChordFired: (() -> Void)?       // bottom-left + bottom-right chord
    var onButtonDown: ((ButtonID) -> Void)?
    var onButtonUp: ((ButtonID) -> Void)?

    // Snapshot injected from PreferencesManager after each save
    var snapshot: MappingSnapshot?

    // MARK: - Public API

    /// Returns true if the event should be suppressed (button is held as a modifier or consumed by chord).
    func processButtonDown(_ id: ButtonID) -> ButtonDecision {
        heldButtons.insert(id)

        // Check if this completes the Quit chord (bottom-left + bottom-right)
        if heldButtons.contains(.bottomLeft) && heldButtons.contains(.bottomRight) {
            cancelChordPending()
            guard let chord = snapshot?.quitChord, chord.enabled else {
                // Chord disabled — pass both events through normally
                return .passThrough
            }
            consumedButtons.insert(.bottomLeft)
            consumedButtons.insert(.bottomRight)

            let delay = snapshot?.chordQuitSafetyDelay
            if let delay, delay > 0 {
                let work = DispatchWorkItem { [weak self] in
                    self?.fireQuitChord()
                }
                safetyDelayTimer = work
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            } else {
                fireQuitChord()
            }
            return .suppress
        }

        // For all other buttons — start the chord coincidence window (~50ms)
        // and fire single-button action if no chord forms within that window
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if !self.consumedButtons.contains(id) {
                self.onButtonDown?(id)
            }
        }
        chordPendingTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)

        // If this button is a scroll modifier (held during scroll), suppress the click
        if isScrollModifier(id) {
            consumedButtons.insert(id)
            return .suppress
        }

        return .pendingChordWindow
    }

    func processButtonUp(_ id: ButtonID) -> ButtonDecision {
        heldButtons.remove(id)

        // Cancel safety delay if one of the chord buttons is released early
        if id == .bottomLeft || id == .bottomRight {
            safetyDelayTimer?.cancel()
            safetyDelayTimer = nil
        }

        if consumedButtons.contains(id) {
            consumedButtons.remove(id)
            return .suppress
        }

        onButtonUp?(id)
        return .passThrough
    }

    func isHeld(_ id: ButtonID) -> Bool {
        heldButtons.contains(id)
    }

    func heldModifier() -> ButtonID? {
        // Returns the held button that acts as a scroll modifier, if any
        for mod in [ButtonID.bottomLeft, .bottomRight, .topRight] where heldButtons.contains(mod) {
            return mod
        }
        return nil
    }

    // MARK: - Private

    private func cancelChordPending() {
        chordPendingTimer?.cancel()
        chordPendingTimer = nil
    }

    private func fireQuitChord() {
        safetyDelayTimer = nil
        onChordFired?()
    }

    private func isScrollModifier(_ id: ButtonID) -> Bool {
        [ButtonID.bottomLeft, .bottomRight, .topRight].contains(id)
    }
}

enum ButtonDecision {
    case passThrough
    case suppress
    case pendingChordWindow  // let CGEvent tap decide after 50ms
}
