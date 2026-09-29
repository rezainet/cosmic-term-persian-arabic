# How it works

## Where the problem comes from

cosmic-term builds the text of each line in `Terminal::update()` and puts U+2066 (left-to-right isolate) in front of it. That was added on purpose in pull request 38, because right-aligned lines look wrong for normal shell output. The side effect is that a Persian sentence is treated as left-to-right text with some right-to-left words in it. Issue 221 asks for the opposite behaviour and was closed with the note that a way to choose the direction would come later.

## Choosing the direction of a line

The cells of a line are read in the order they were typed. A line is right to left when both are true:

1. it contains at least one letter with the Unicode class R or AL
2. no more than 5 left-to-right words come before the first such letter

A word is a run of cells between blanks that holds a Latin letter or an ASCII digit. Symbols, icons from the private use area and Persian digits are not counted.

The limit of 5 is a guess that works well for me. It keeps a Persian sentence that starts with a product name right to left, and keeps file listings and log lines left to right.

## Mirroring a line

For a right-to-left line the prefix U+2066 is replaced with U+2067 (right-to-left isolate) and U+200F (right-to-left mark) is added at the end. Both prefixes are 3 bytes long, so the byte ranges of colours and styles stay valid.

The text engine still gets a left-to-right paragraph. Glyphs are placed from the left edge, one cell after another, so they stay on the grid. Inside the isolate the order is right to left, and the mark at the end keeps the empty cells inside it, which moves them to the left.

Letting cosmic-text handle the line as a right-to-left paragraph would be less code. It starts at the pixel width of the window though, and that is not a whole number of cells, so those lines would be a few pixels off.

## Mouse and cursor

cosmic-term turns a mouse position into a column with `x / cell_width`. On a mirrored line this gives the wrong cell. Mirroring the column number is not enough either, because an English word inside a Persian line keeps its own order.

While a line is built, the byte offset of every column is stored. For a mouse position the glyph under it is looked up, and its byte offset gives the column. For right-to-left glyphs the left and right half of the cell are swapped. The beam and underline cursors use the same table in the other direction.

Lines without right-to-left letters use the old calculation.

## Brackets

The text engine swaps `(` and `)` in right-to-left runs. Menlo and the fonts made from it swap them again in their `rtla` feature, so they come out reversed. The patch turns `rtla` off for terminal text.

## Tests

`src/bidi.rs` has 11 tests. Some of them lay out real lines with cosmic-text and check that every column is found again from the position of its glyph.

```bash
cd build/cosmic-term
cargo test --release bidi
BIDI_TEST_FONT="MesloLGS NF" cargo test --release bidi
```

If the xkbcommon development files are not installed, export the two variables that `install.sh` sets first (`PKG_CONFIG_PATH` and `RUSTFLAGS`, both pointing at `build/libs`).
