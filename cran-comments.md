## CRAN submission snapshot: taruwind 0.1.0

Maintainer: Cem Özen <ozenc@itu.edu.tr>

The exact source archive was submitted to CRAN on 28 September 2026 and is
pending manual inspection. Submission is not acceptance or publication.

Submitted archive: `taruwind_0.1.0.tar.gz`

SHA256: `9b67abc562d369d7cd3ea9c727ca8898a5a3743adcd598c1218276127e18e414`

The private draft GitHub release attached to tag
`cran-submission-0.1.0-20260928` stores that exact archive. Downloading the
asset and comparing it byte for byte with the submitted local file succeeded.

* Linux R 4.6.1: full R CMD check --as-cran, including the PDF manual,
  completed with 0 errors, 0 warnings and 3 notes. Missing local TeX font/index
  tooling in the first attempts was resolved using the available Inconsolata
  font and a locally extracted makeindex executable.
* GitHub Actions run 35756209012: Linux, Windows and macOS each completed
  R CMD check --no-manual --as-cran with Status: OK on 22 September 2026 for
  the earlier base source snapshot.
* The exact submitted archive passed the official Windows R-devel win-builder
  check and the CRAN incoming pretests on Windows and Debian. Each reported
  0 errors, 0 warnings and 1 note. That note identifies a new submission;
  Debian also flagged the valid domain term "Downscaling" as possibly
  misspelled within the same note.
* The other local notes concern a compiler flag inherited from the installed
  R toolchain (-mno-omit-leaf-frame-pointer), not set by package Makevars, and
  the absence of HTML Tidy. The official hosted checks did not report these
  local toolchain notes.
* Examples and tests use synthetic local inputs, do not require credentials,
  and do not download environmental datasets. Parallel tests use two workers.
* Download helpers default to session-temporary storage. Persistent caching
  requires a caller-specified directory.
* Bundled pocketfft notices are retained in the source header and installed
  COPYRIGHTS file for both source and binary distribution.

Scientific manuscript acceptance is not a prerequisite for this submission.
No journal acceptance, public DOI or completed CRAN acceptance is claimed.
