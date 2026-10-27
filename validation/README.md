# Validation

This folder records how the readers of replayr were checked against real
files: which files, where each comes from, what was compared, and the scripts
that repeat the checks. It belongs to the repository and is not part of the
installed package. No recording is stored here: the tables name every file
by its source and its SHA-256 hash, and the scripts retrieve them.

The numbers below are those of `summary.csv`.

## Results

| Files | Number | Check | Result |
|---|---|---|---|
| Publications of [TASVideos](https://tasvideos.org/Movies), including obsolete ones | 7,385 distinct recordings under 34 extensions | Each is read in full, and every value is compared with a decoder written separately in Python from the format descriptions and the emulators' sources. | All are read; 19.0 billion values agree. In 21 the file itself is defective; they are read up to the defect, with a warning. |
| Doom-engine demos of the [Doom Speed Demos Archive](https://dsdarchive.com) | 352 demos of *Doom*, *Heretic* and *Hexen*, in source ports up to MBF21 | As above. | 2.7 million tics and 101.6 million values agree. |
| GoldSrc demos from the test material of four demo parsers and from nine collections of the [Internet Archive](https://archive.org) | 697 files | As above. In the demos that also record the player's key actions as console commands, each action is held against its key. | 684 demos agree in 9.7 million observations and 286 million values; 100 of them hold no commands of a player (broadcast recordings). 13 files are refused by both readers: five that a parser's tests break on purpose, and eight of demo protocol 4, which stores no commands. In 569 demos each action follows its key in 96.6 to 99.99 per cent of the observations. |
| Recordings of Gym Retro and of its successor stable-retro | 60, of which 58 are human demonstrations of the Sonic benchmark | Compared with a decoder that follows Gym Retro's own reading rule; the length of each demonstration is held against the number of steps that Gym Retro counted. | 9.7 million values agree; all 58 lengths are equal. |
| Tables of the Atari Grand Challenge data set (version 1) and of Atari-HEAD | 2,313 trajectories and 471 trials | Compared with a separate decoder; each trial of Atari-HEAD is held against the number of frames and the play time that the data set lists for it. | 130 million values agree; all 471 trials equal their listing. |
| FinalBurn recordings among the TASVideos publications | 62 | The text of the author after the input is compared with a separate reading of the same bytes. | 42 have such a text; all agree. |

## Performance

Every file was read once, one at a time: the 7,385 distinct TASVideos
recordings, with 1.04 billion observations, in 42 minutes, and the 3,880
files of the other collections, with 29.5 million observations, in 5
minutes. BizHawk recordings too long for a full import are read in chunks
with `read_bk2_chunks()`. For twelve TASVideos formats,
the Doom-engine and GoldSrc demos and each Atari data set, the files at the
median and at the 95th percentile of length were read five times each, and
artificial FM2 recordings of ten thousand to ten million frames three times.
The times were taken with replayr 0.4.0 and R 4.6.0 on Windows 11, on an
Intel Core Ultra 9 285K processor with 32 GB of memory and an NVMe disk.

## Tables

All tables are in `tables/`. `sha256` is the hash of the file as it was
checked.

| Table | One row for | Columns of note |
|---|---|---|
| `validation-manifest.csv` | each TASVideos recording | publication, address of the download, format, size, hash, outcome of the import (`status`, `representation`, `observations`), the game named for a FinalBurn recording with the source of its input layout, and any warning |
| `validation-summary.json` | the collection | counts by format |
| `independent-comparison.csv` | each distinct TASVideos recording | numbers of button, numeric and command values compared and of differences |
| `source-warning-findings.csv` | each recording that is read with a warning | what the warning was traced to (`classification`, `explanation`, `sources`) |
| `warning-audit-sources.json` | each source consulted for those findings | address, hash and the passage that was used |
| `doom-family-comparison.csv` | each Doom-engine demo | address of the archive, member, source port, values compared and differences |
| `goldsrc-comparison.csv` | each GoldSrc file | repository with revision, or collection with file and member; licence; game folder, map, network protocol; whether the demo holds commands of a player; values compared; warnings |
| `goldsrc-key-actions.csv` | each action | demos and observations in which the action could be held against its key, and the share that agree |
| `gymretro-comparison.csv` | each Gym Retro recording | address, game, observations, the step count of Gym Retro, values compared |
| `atari-comparison-by-file.csv` | each Atari table | data set, game, size, hash, observations, values compared, and for Atari-HEAD whether the trial equals its listing |
| `atari-comparison.csv` | each game of the two data sets | tables, observations, hours of play, values compared |
| `timing-tasvideos.csv` | each distinct TASVideos recording | size, observations, seconds for one read, size of the result, whether it was read whole or in chunks |
| `timing-other-collections.csv` | each file of the Doom-engine, GoldSrc, Gym Retro and Atari collections | collection, hash, size, observations, seconds for one read, size of the result |
| `timing-recordings.csv` | the TASVideos recordings at the median and at the 95th percentile of length in each of twelve formats | observations, controllers, controls, numeric channels, file size, median seconds of five reads, sizes of the result and of its logical array, peak memory |
| `timing-other-recordings.csv` | the files at the median and at the 95th percentile of length of the Doom-engine demos, the GoldSrc demos and each Atari data set | as `timing-recordings.csv`, with the collection and the hash of the file |
| `timing-sizes.csv` | each length of the artificial FM2 recordings | file size, median seconds of three reads, sizes of the result and of its logical array, bytes per button state, peak memory |
| `fbm-text-comparison.csv` | each FinalBurn recording | the text of its author, if any |

`summary.csv` holds one row for each number reported above and in the article
on replayr. `scripts/summarise.R` writes it from the tables and first checks
them for what is said of them: that every comparison agrees, that no file is
listed twice, that only FinalBurn recordings need an argument, and so on.

## Reproducing the results

The scripts are in `scripts/` and are run from this folder. They take the
folders for downloads and results as arguments or from the environment; none
names a path of its own. They need R with replayr, digest and jsonlite,
Python 3 with NumPy, and for the GoldSrc collections bsdtar (the `tar` of
Windows 10 and later, or libarchive elsewhere) to unpack RAR and 7z archives.
Every retrieval waits between requests and can be stopped and started again.

TASVideos (5.4 GB, about two and a half hours at one request per second):

```sh
export REPLAYR_VALIDATION_ROOT=recordings
Rscript scripts/retrieve-recordings.R            # or a part: fm2,smv 20
Rscript scripts/validate-recordings.R            # import and check every file
Rscript scripts/game-checks.R                    # checks against known controls of two games
Rscript scripts/timing-recordings.R              # time and memory for chosen recordings
Rscript scripts/timing-tasvideos.R               # every distinct recording once, about 45 minutes
Rscript scripts/timing-sizes.R                   # artificial FM2 recordings; needs no download
```

The separate decoders, `scripts/independent-decoders`. replayr's values are
exported first and then compared, by format; BizHawk archives have scripts of
their own:

```sh
export REPLAYR_VALIDATION_MANIFEST=tables/validation-manifest.csv
Rscript scripts/independent-decoders/export-replayr.R fm2,smv export
python scripts/independent-decoders/compare.py export comparison.csv
Rscript scripts/independent-decoders/export-bk2.R export-bk2 1 1
python scripts/independent-decoders/compare-bk2.py export-bk2 comparison-bk2.csv
```

Doom-engine demos: `Rscript scripts/retrieve-recordings.R doom` retrieves
the demos of `tables/doom-family-comparison.csv` and writes
`doom-family-manifest.csv` into the folder of the recordings. With
`REPLAYR_VALIDATION_MANIFEST` set to that file, the two commands above
compare the format `lmp`.

GoldSrc demos (2.6 GB of archives, kept in the third folder; 6.6 GB of
demos):

```sh
python scripts/goldsrc-retrieve.py demos goldsrc-sources.csv archives
python scripts/goldsrc-decode.py demos decoded
Rscript scripts/goldsrc-compare.R demos decoded goldsrc-sources.csv tables/goldsrc-comparison.csv
Rscript scripts/goldsrc-key-actions.R demos tables/goldsrc-key-actions.csv
```

Gym Retro (15 MB); the third file of the first command receives the step
counts of Gym Retro:

```sh
python scripts/gymretro-retrieve.py recordings gymretro-sources.csv gymretro-steps.txt
python scripts/gymretro-decode.py recordings decoded
Rscript scripts/gymretro-compare.R recordings decoded gymretro-sources.csv gymretro-steps.txt tables/gymretro-comparison.csv
```

The two Atari data sets, without their screen images (5.7 GB of text; Zenodo
answers slowly, so Atari-HEAD takes hours, and its games can be shared out
among several runs, as the script describes):

```sh
python scripts/atari-retrieve.py atari atari-sources.csv
python scripts/atari-decode.py atari atari-sources.csv atari-decoded
Rscript scripts/atari-compare.R atari atari-decoded atari-sources.csv tables/atari-comparison-by-file.csv tables/atari-comparison.csv
```

The text of the author in FinalBurn recordings, from the folder that holds
the retrieved `.fbm` files:

```sh
Rscript scripts/fbm-text-read.R recordings/tasvideos_archive/movies/Arcade tables/validation-manifest.csv fbm-text.csv
python scripts/fbm-text-compare.py recordings/tasvideos_archive/movies/Arcade fbm-text.csv tables/fbm-text-comparison.csv
```

The time to read the other collections, from the folders of the Doom-engine
demos, the GoldSrc demos, the Gym Retro recordings and the Atari data, as the
commands above name them (files are found by their hash):

```sh
Rscript scripts/timing-other-collections.R recordings demos recordings atari
```

Last, the summary:

```sh
Rscript scripts/summarise.R
```

## Licences

The recordings belong to their authors and are not redistributed. The
tables give, where a source states one, its licence: the parser
repositories are under Apache-2.0, MIT or LGPL-3.0; one collection of the
Internet Archive carries the Public Domain Mark and the others state none;
the Gym Retro libraries are under MIT, while the repository of the 58
demonstrations states no licence; Atari-HEAD is under CC BY 4.0, and the
Atari Grand Challenge data set states no licence.
