# Stable controller identities and compact movie columns

Without a movie, returns the fixed gamepad and peripheral registry. With
a movie, returns only its controller's columns, in matrix order.
`column` is a local matrix index; `id` and `key` identify the same
control across recordings. Unpressed controls supported by the
controller are retained. Peripheral controls are a separate group and
never occupy empty positions in a gamepad matrix. NES Power Pad sensors
retain their numbered identities (`power_pad_1` through `power_pad_12`)
and have kind `power_pad`. Their serial positions in a BK2 LogKey are
decoded independently of those sensor numbers.

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
controllers. Registered controls retain numeric IDs 1–79; a mixed layout
represents all IDs as character strings. Use keys or IDs for matching,
rather than coercing the complete ID column to integers. Source keyboard
code sets remain distinct.

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
