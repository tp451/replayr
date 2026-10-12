# CRAN submission candidate

Initial submission: replayr 0.4.0.

## Test environments

* Windows 11 x64, R 4.6.0: R CMD check --as-cran, Status: OK.
* Ubuntu 24.04.4 under WSL, R-devel 4.7.0 (2026-10-08 r90650): Status: OK.

Both environments checked the same built source archive on 12 October 2026. Tests, examples,
vignettes, and PDF/HTML manual checks passed. Remote CRAN incoming checks
were disabled; public URL and incoming checks remain before submission.

## Examples and data

Package examples use original artificial recordings, with generators included
in the source. No third-party recordings, game images, save states, or
audiovisual data are bundled. External compatibility tests are optional.

Compatibility checks covered every distinct recording in the TASVideos
publication catalogue acquired on 11 October 2026, including obsolete
publications: 7,385 distinct recordings, represented by 7,469 local paths.
All 7,385 passed. Mixed GameCube/Wii framing is selected automatically
from source-verified Dolphin revision profiles. Source defects are retained
with warnings and observation flags. The external manifest records hashes,
source URLs, reader arguments, and outcomes. Separate format audits compare
decoded fields with independent parsers and original emulator decoders.

Additional checks compare controller assignments with game manuals and
TASVideos submission descriptions. Original one-button and distinct-axis
fixtures detect swapped buttons, ports, and axes. All 93 lsnes recordings
were independently checked, including every input subframe and the
declared Super Scope device.

Native ZIP inputs verify CRCs; tar readers validate member types and avoid
filesystem extraction. Original fixtures cover every supported extension.
Large BK2 inputs can be processed in bounded memory with read_bk2_chunks().

## Dependencies

Imports: jsonlite, xml2, zip (>= 3.0.2), and utils. These support controller
configuration, XML recordings, checked ZIP extraction, and standard utilities.
pisa requires replayr and is intended for submission after replayr is on CRAN.
