# Stable controller identities and compact movie columns

Without a movie, returns the fixed gamepad and peripheral registry. With
a movie, returns only its controller's columns, in matrix order.
`column` is a local matrix index; `id` and `key` identify the same
control across recordings. Unpressed controls supported by the
controller are retained. Matrices omit registry entries outside that
controller's layout. The registry contains 53 consecutive IDs. Keypad
digits and equally numbered Power Pad sensors share `numbered_0` through
`numbered_12` (IDs 40-52), with kind `numbered`. Microphone is ID 53.
Serial positions in a BK2 LogKey are decoded independently of those
sensor numbers.

## Usage

``` r
button_layout(movie = NULL)
```

## Arguments

- movie:

  An imported recording, or `NULL` for the fixed registry.

## Value

Data frame with column, id, key, mnemonic, name and kind.

## Details

Additional named controls, such as keyboard keys, have character IDs of
the form `control:<key>`. These are stable within their source key
namespace. They appear in the movie's layout without expanding unrelated
controllers. Equivalent device buttons share registered IDs: Wii Home
and libTAS Guide use Mode (19), Wii 1/2 use X/Y (9/10), and light-gun
triggers use A (8). Arcade Attack/Punch use A, Jump and Doom Use use B,
Kick uses X, and D uses Y. Mouse left/right/middle use A/B/X, and
buttons 4/5 use L1/R1. GunCon trigger, side A, side B, and offscreen
shot use A/B/X/Y. Keypad Enter/Clear use Start/Select; Star/Pound retain
qualified source IDs. Device-qualified openMSX controls also remain
distinct because multiple devices can occupy the same input stream. A
shared ID groups comparable controller roles; game actions can differ.
When aliases are present, `source_inputs` retains the decoded input
array and `source_layout` identifies its columns and their
`universal_key` mapping. If several source buttons map to one ID, that
column is active whenever any of them is pressed. Registered controls
use fixed numeric IDs; a mixed layout represents all IDs as character
strings. Use keys or IDs for matching, rather than coercing the complete
ID column to integers. Source keyboard code sets remain distinct.

## Examples

``` r
path <- system.file("extdata", "sample.m64", package = "replayr")
button_layout(read_movie(path))
#>    column id        key mnemonic    name   kind
#> 1       1  1 dpad_right        R   Right button
#> 2       2  2  dpad_left        L    Left button
#> 3       3  3  dpad_down        D    Down button
#> 4       4  4    dpad_up        U      Up button
#> 5       5  5      start        T   Start button
#> 6       6  7          b        B       B button
#> 7       7  8          a        A       A button
#> 8       8 11         l1        p      L1 button
#> 9       9 12         r1        q      R1 button
#> 10     10 18          z        Z       Z button
#> 11     11 20    c_right        > C-Right button
#> 12     12 21     c_left        <  C-Left button
#> 13     13 22     c_down        v  C-Down button
#> 14     14 23       c_up        ^    C-Up button
```
