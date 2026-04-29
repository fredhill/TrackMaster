import Foundation

// ChordDetector tracks held buttons and fires the Quit chord when both
// bottom buttons are held simultaneously (with optional safety delay).
// All other buttons pass straight through — scroll modifier logic lives
// in EventInterceptor.handleScroll, not here.
//
// Runs on the main run loop thread — no locking needed.

@MainActor
final class ChordDetector {

    private var heldButtons: Set<ButtonID> = []
    private var consumedButtons: Set<ButtonID> = []  // suppressed because chord fired
    private var safetyDelayTimer: DispatchWorkItem?

    var onChordFired: (() -> Void)?
    var snapshot: MappingSnapshot?

    // MARK: - Public API

    func processButtonDown(_ id: ButtonID) -> ButtonDecision {
        heldButtons.insert(id)

        // Quit chord: both bottom buttons held simultaneously
        if heldButtons.contains(.bottomLeft) && heldButtons.contains(.bottomRight) {
            guard let chord = snapshot?.quitChord, chord.enabled else {
                // Chord disabled — both clicks pass through normally
                return .passThrough
            }
            consumedButtons.insert(.bottomLeft)
            consumedButtons.insert(.bottomRight)

            if let delay = snapshot?.chordQuitSafetyDelay, delay > 0 {
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

        // All other buttons: pass through immediately.
        // Scroll modifier behaviour is handled in EventInterceptor.handleScroll
        // by checking isHeld() at scroll time — not by suppressing button-down here.
        return .passThrough
    }

    func processButtonUp(_ id: ButtonID) -> ButtonDecision {
        heldButtons.remove(id)

        // Cancel safety delay if a chord button is released before the timer fires
        if id == .bottomLeft || id == .bottomRight {
            safetyDelayTimer?.cancel()
            safetyDelayTimer = nil
        }

        if consumedButtons.contains(id) {
            consumedButtons.remove(id)
            return .suppress
        }

        return .passThrough
    }

    /// Whether a button is currently physically held down.
    func isHeld(_ id: ButtonID) -> Bool {
        heldButtons.contains(id)
    }

    /// Returns the held button that acts as a scroll ring modifier, if any.
    func heldScrollModifier() -> ButtonID? {
        for mod in [ButtonID.bottomLeft, .bottomRight, .topRight] {
            if heldButtons.contains(mod) { return mod }
        }
        return nil
    }

    // MARK: - Private

    private func fireQuitChord() {
        safetyDelayTimer = nil
        onChordFired?()
    }
}

enum ButtonDecision {
    case passThrough
    case suppress
}
