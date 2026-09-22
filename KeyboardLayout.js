// Keyboard layout data for the split two-thumb on-screen keyboard.
//
// Each key is an object:
//   label   - text drawn on the key
//   w       - relative width weight within its row (row widths sum to fill)
//   type    - "char" | "key" | "shift" | "super" | "sym" | "space" |
//             "backspace" | "enter" | "dismiss"
//   char    - character to inject (type "char")
//   shifted - caps/shifted variant of char, injected when shift is latched
//   code    - evdev keycode (type "key", plus space/backspace/enter helpers)
//             see /usr/include/linux/input-event-codes.h
//
// Layout: two thumb-reach halves (left/right) separated by a gutter, three
// letter rows each, plus a control row in each half (no full-width bar).

var PAGE_LETTERS = "letters";
var PAGE_SYMBOLS = "symbols";

function c(label, shifted) {
  return { label: label, type: "char", char: label, shifted: shifted || label };
}

function act(type, label, w, extra) {
  var k = { label: label, type: type, w: w || 1 };
  for (var p in (extra || {})) k[p] = extra[p];
  return k;
}

// Rows for the current page. left[] and right[] are arrays of rows; each row
// is an array of keys. Shift latches caps for the next char on the letters
// page (upper-case Latin); on the symbols page shift swaps to the mirrored
// set already shown, so it simply types its label.
function rows(page) {
  if (page === PAGE_SYMBOLS) {
    return {
      left: [
        [c("1", "!"), c("2", "@"), c("3", "#"), c("4", "$"), c("5", "%")],
        [c("6", "^"), c("7", "&"), c("8", "*"), c("9", "("), c("0", ")")],
        [c("-", "_"), c("=", "+"), c("[", "{"), c("]", "}"), c("\\", "|")]
      ],
      right: [
        [c("!", "!"), c("@", "@"), c("#", "#"), c("$", "$"), c("%", "%")],
        [c("^", "^"), c("&", "&"), c("*", "*"), c("(", "("), c(")", ")")],
        [c("_", "_"), c("+", "+"), c("{", "{"), c("}", "}"), c("|", "|")]
      ]
    };
  }
  return {
    left: [
      [c("q", "Q"), c("w", "W"), c("e", "E"), c("r", "R"), c("t", "T")],
      [c("a", "A"), c("s", "S"), c("d", "D"), c("f", "F"), c("g", "G")],
      [act("shift", "⇧", 1.35), c("z", "Z"), c("x", "X"), c("c", "C"), c("v", "V")]
    ],
    right: [
      [c("y", "Y"), c("u", "U"), c("i", "I"), c("o", "O"), c("p", "P")],
      [c("h", "H"), c("j", "J"), c("k", "K"), c("l", "L"), c(";", ":")],
      [c("b", "B"), c("n", "N"), c("m", "M"), c(",", "<"), c(".", ">")]
    ]
  };
}

// Control row for each half. Space/backspace/enter are sent as bare keycodes
// so ydotool never has to parse a raw space character as an argument. The
// super key latches (like shift): tap it, then tap a letter for a SUPER+key
// chord (Omarchy shortcuts), or tap it twice to release without a chord.
function controlRows(page) {
  return {
    left: [
      act("super", "⊞", 1.3),
      act("sym", page === PAGE_LETTERS ? "?123" : "ABC", 1.25),
      act("backspace", "⌫", 1.3, { code: 14 }),
      act("dismiss", "Hide", 1.2)
    ],
    right: [
      act("enter", "⏎", 1.35, { code: 28 }),
      act("space", "␣", 2.7, { code: 57 })
    ]
  };
}