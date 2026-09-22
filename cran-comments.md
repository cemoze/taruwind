## First submission candidate: taruwind 0.1.0

Maintainer: Cem Özen <ozenc@itu.edu.tr>

This file records preparation, not a completed submission.

* Linux R 4.6.1: package installation, examples and tests pass. The initial
  full manual check was blocked by missing local TeX fonts/index tooling;
  this is being resolved before submission.
* GitHub Actions run 35756209012: Linux, Windows and macOS each completed
  R CMD check --no-manual --as-cran with Status: OK on 22 September 2026.
* The expected CRAN incoming NOTE identifies a new submission.
* Examples and tests use synthetic local inputs, do not require credentials,
  and do not download environmental datasets. Parallel tests use two workers.
* Download helpers default to session-temporary storage. Persistent caching
  requires a caller-specified directory.
* Bundled pocketfft notices are retained in the source header and installed
  COPYRIGHTS file for both source and binary distribution.

Scientific manuscript acceptance is not a prerequisite for this submission.
No journal acceptance, public DOI or completed CRAN acceptance is claimed.
