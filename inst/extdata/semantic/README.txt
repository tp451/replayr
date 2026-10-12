Original control identity fixtures
==================================

These seven small recordings were constructed from format specifications and
emulator source definitions. They contain no downloaded replay data, game code,
game assets, or emulator implementation code. They are distributed under the
replayr package license. Regenerate them with tools/make-semantic-fixtures.py;
Python 3 and its standard library are sufficient.

Each recording starts with a neutral sample and presses every supported digital
button individually in source-bit order. FMV and FCM finish with Right+B+A; SMV
finishes with Right+Y+B; GMV tests the two six-button controller nibbles separately
and finishes with Right+C. M64 adds A+Z and cardinal/diagonal stick positions.
PJM and PXM test L3 and R3 separately and move each stick through all four cardinal
directions while the other stick stays centered. These are decoder test vectors,
not examples of playable game sequences.

tests/testthat/test-semantic-controls.R checks the public read_movie() results
against independent physical-button expectations and raw stick coordinates. It
also checks the four stick representations, including N64's upward positive Y,
PlayStation's downward positive Y, separate left/right sticks, and asymmetric
PlayStation endpoint magnitudes. This distinguishes control identities even when
two buttons perform equivalent actions in a particular game.

Pinned source revisions are listed in the generator. None of these tests require
network access, an emulator, a ROM, or a third-party recording.
