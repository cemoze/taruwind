## Resubmission: taruwind 0.1.1

This resubmission addresses the manual-review feedback on version 0.1.0.

1. Regarding the reference request: the manuscript describing the
   package-specific reduced-mode and surface-memory formulation is not yet
   published, and there is currently no public method paper or preprint
   describing that formulation to cite. We have not added a manuscript
   citation or substituted a general literature review as its method reference.
2. Authors@R now includes every author and copyright holder named in the
   bundled PocketFFT header: Martin Reinecke and Peter Bell, Max-Planck-Society,
   Matteo Frigo, Massachusetts Institute of Technology, Tan Ping Liang and
   Cris Luengo. Third-party code authors have ctb roles and explicitly named
   copyright holders have cph roles. Each comment identifies the relevant
   PocketFFT component, so these credits do not imply authorship or ownership
   of the original TaruWind code.
3. The full upstream BSD-3-Clause notice remains unchanged in
   src/pocketfft_hdronly.h and inst/COPYRIGHTS. The MIT license of the original
   TaruWind code is unchanged. Cem Ozen remains the sole aut and cre.
4. Version metadata is increased to 0.1.1 to distinguish this candidate from
   the previous submission. Apart from the response provenance version string,
   no R calculation code, C++ code, numerical setting or prediction formula
   has changed.

### Checks for version 0.1.1

Linux R 4.6.1, full R CMD check --as-cran including the PDF manual:
0 errors, 0 warnings, 3 notes. All 106 test expectations pass, with no test
warnings or skips.

The notes concern:

- A new submission.
- A compiler flag (-mno-omit-leaf-frame-pointer) inherited from the installed
  R toolchain, not specified by the package.
- HTML Tidy not being available locally; the PDF manual check passed.

The existing source header and installed copyright notice are byte-for-byte
unchanged. A metadata audit confirms that Cem Ozen is the only aut and cre
and remains the only author in the package citation.

The first local check used an inherited Conda PROJ_DATA setting that pointed
terra to an incompatible PROJ database and caused three raster test errors.
Rerunning the same archive with PROJ_DATA=/usr/share/proj resolved these
environment-only failures without any package-code change.

No new hosted Windows or macOS check result is claimed here. The checks below
are historical results for version 0.1.0, not results for this candidate.

## Previous CRAN submission snapshot: taruwind 0.1.0

Maintainer: Cem Özen <ozenc@itu.edu.tr>

The exact source archive was submitted to CRAN on 28 September 2026 and was
returned for metadata corrections. Submission is not acceptance or publication.

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
