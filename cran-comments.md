## Submission

This is a new submission.

## Test environments

* local Windows 11, R 4.5.3
* GitHub Actions: windows-latest (release), macos-latest (release), ubuntu-latest (release, devel)
* win-builder (devel): [to be added]

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes for the reviewer

* Functions that take a `seed` argument set it only for the duration of the call and restore the caller's
  random-number state on exit; the global stream is never changed.
* Functions that write files (`stress_report()`, `stress_tables()`, `stress_html()`, `stress_log()`, `stress_sap()`)
  have no default output location, and every example, test and vignette writes to `tempdir()`.
* Examples that run multiple imputation, the deletion search or the simulation are wrapped in `\donttest{}` and run in
  under five seconds each on the test machines; no example, test or vignette uses more than two cores.
* Suggested packages (ggplot2, emmeans, nlme, MASS, flextable, officer, plotly, htmlwidgets, htmltools, jsonlite) are
  used conditionally with `requireNamespace()`.
* 'SAS', 'PROC MIXED' and 'PROC MI' in the Description refer to the SAS software conventions the package reproduces;
  the package does not call SAS.
