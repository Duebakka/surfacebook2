// Shared helpers for the Surface Book 2 plugin.
//
// Pure functions only: anything environment-dependent (paths, processes,
// timers) stays in the QML files so this module stays fixture-testable.

function parseState(text) {
  if (!text) return null
  try {
    var state = JSON.parse(text)
    return typeof state === "object" && state !== null ? state : null
  } catch (e) {
    return null
  }
}

function modeLabel(mode) {
  switch (String(mode || "")) {
    case "laptop": return "Laptop mode"
    case "tablet": return "Tablet mode"
    case "studio": return "Studio mode"
    default: return "Unknown mode"
  }
}

function modeGlyph(mode) {
  switch (String(mode || "")) {
    case "tablet": return "tablet"
    case "studio": return "laptop"
    default: return "laptop"
  }
}

function latchLabel(latch) {
  switch (String(latch || "")) {
    case "open": return "Latch open"
    case "closed": return "Latch closed"
    default: return "Latch unknown"
  }
}

function baseLabel(base) {
  switch (String(base || "")) {
    case "attached": return "Base attached"
    case "detached": return "Base detached"
    default: return "Base unknown"
  }
}

// Touch status as stored by the watchdog: "on", "off", "none" (no device) or
// "unknown".
function touchLabel(touch) {
  switch (String(touch || "")) {
    case "on": return "Touchscreen on"
    case "off": return "Touchscreen off"
    case "none": return "No touchscreen detected"
    default: return "Touchscreen unknown"
  }
}

// Short description under the touchscreen toggle.
function touchDescription(touch, baseAttached) {
  switch (String(touch || "")) {
    case "on":
      if (baseAttached === false) return "On — locked while the base is detached"
      return "Tap with fingers or pen"
    case "off":
      return "Disabled — tap the row to enable"
    case "none":
      return "No touch hardware detected on this session"
    default:
      return "Unknown state"
  }
}

// Short one-liner for the bar pill tooltip / accessibility description.
function tooltip(state) {
  if (!state) return "Surface Book 2"

  var parts = []
  parts.push(modeLabel(state.mode))
  if (state.base) parts.push(baseLabel(state.base))
  if (state.latch) parts.push(latchLabel(state.latch))
  if (state.touch) parts.push(touchLabel(state.touch))
  if (state.rotation) parts.push(rotationLabel(state.rotation))
  if (state.keyboard_status) parts.push("Keyboard " + state.keyboard_status)
  if (state.watchdog === false) parts.push("tablet-mode service not running")
  return parts.join(" · ")
}

// Rotation mode as shown to the user.
function rotationLabel(rotation) {
  switch (String(rotation || "")) {
    case "auto": return "Auto-rotate"
    case "locked": return "Rotation locked"
    default: return "Rotation unknown"
  }
}

// Orientation labels (which edge of the screen is roughly up).
function orientationLabel(orientation) {
  switch (String(orientation || "")) {
    case "top-up": return "Portrait (upright)"
    case "bottom-up": return "Upside down"
    case "left-up": return "Landscape (left)" 
    case "right-up": return "Landscape (right)"
    case "flat": return "Held flat"
    default: return ""
  }
}

// Short description under the auto-rotate toggle.
function rotationDescription(rotation, orientation) {
  var ori = orientationLabel(orientation)
  var line = rotationLabel(rotation) + (ori ? " · " + ori : "")
  if (String(rotation || "") === "locked") line += "\nTap to follow the screen as you turn it"
  else line += "\nScreen follows the held orientation"
  return line
}

// On-screen keyboard (split thumb layout, injected via ydotool) state under
// its toggle.
function keyboardDescription(mode, running, clipboardMode) {
  var k = String(mode || "auto")
  if (k === "off") return "Off — tap the row for the on-screen keyboard"
  if (k === "on") return "Always on — split keyboard visible"
  if (String(clipboardMode || "") === "tablet") {
    return running === "on" ? "Visible — split keys for your thumbs"
                            : "Preparing…"
  }
  return "Raises when the clipboard detaches into tablet mode"
}

// True when the state comes from the tablet-mode watchdog service. Without it
// the bar has no trustworthy reading.
function hasService(state) {
  return state && (state.watchdog === true || state.updated > 0)
}