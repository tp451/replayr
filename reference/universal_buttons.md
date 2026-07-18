# Universal button mnemonics

One-character symbol per universal-button slot. Length 40. Indexed by
slot number using one-based R semantics: slot 1 = "R" (Right), slot 8 =
"A", and so on. Slots 31..40 are the Intellivision / ColecoVision
numeric keypad (digits 0-9). INTV's Enter/Clear and Coleco's Star/Pound
do not have dedicated slots — they fold into Start (slot 5) and Select
(slot 6) since they're functionally Start/Select on those platforms
(pressed once at boot).

## Usage

``` r
universal_buttons()
```

## Value

Character vector of length 40.

## Details

![replayr universal-button layout: gamepad slots 1-30 plus INTV/Coleco
numeric-keypad slots 31-40](figures/universal_buttons_layout.svg)

## See also

[`universal_button_names()`](universal_button_names.md)

## Examples

``` r
universal_buttons()
#>  [1] "R" "L" "D" "U" "T" "S" "B" "A" "x" "y" "p" "q" "C" "Z" "M" "#" ">" "<" "v"
#> [20] "^" "e" "f" "n" "g" "w" "h" "s" "i" "[" "]" "0" "1" "2" "3" "4" "5" "6" "7"
#> [39] "8" "9"
```
