# replayr 0.4.0

Initial release.

* Import console and computer input recordings from current and historical
  emulator formats, including TAS editor projects and ZIP members.
* Store digital controls in compact logical arrays, with stable control IDs,
  readable labels, source metadata, and separate numeric channels.
* Support independent left and right stick representations: four directions,
  eight directions, angle, or angle and magnitude. Source X/Y values remain
  available in every mode.
* Retain stick clicks, light-gun controls, mouse movement, keypad controls,
  touchscreens, keyboards, motion sensors, and separately recorded emulator
  and cabinet controls.
* Preserve multi-controller M64 and DTM files as ordered poll streams when port labels
  are unavailable; accept a verified repeating port order for player assignment.
* Include original artificial samples, source-defined regression fixtures, article
  examples, and their deterministic generators.
