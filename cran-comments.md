## Submission

This is an update of ballast, from 0.6.1 (accepted 30 October 2026) to 0.7.4.

The update corrects a CRAN policy defect introduced after 0.6.1: a plotting function added in 0.7.1, the
multi-row form of `plot_swarm()`, called `set.seed()` and left the user's random-number state changed. Every
function now restores the caller's state on exit, and a test checks this for the plotting functions.

The other changes since 0.6.1 are listed in NEWS.md. In brief: a default classification rule based on the
pre-specified confidence interval (the earlier rule stays available through an argument), new functions
`stress_direction()`, `plot_forest()`, `stress_path()`, `path_changes()` and `simulate_rare_trial()`, and display
fixes. No exported function was removed or renamed.

## Test environments

* local Windows 11, R 4.5.3 (`--as-cran`, examples with `--run-donttest`): 0 errors | 0 warnings | 0 notes
* GitHub Actions: windows-latest (release), macos-latest (release), ubuntu-latest (release, devel)

## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

None (the package was first published on CRAN on 30 October 2026).

## Notes for the reviewer

* Functions that take a `seed` argument, and the plotting functions that scatter points, set a seed only for the
  duration of the call and restore the caller's random-number state on exit; the global stream is never changed.
* Functions that write files (`stress_report()`, `stress_tables()`, `stress_html()`, `stress_log()`, `stress_sap()`)
  have no default output location, and every example, test and vignette writes to `tempdir()`.
* Examples that run multiple imputation, the deletion search or the simulation are wrapped in `\donttest{}` and run in
  under five seconds each on the test machines; no example, test or vignette uses more than two cores.
* Suggested packages (ggplot2, emmeans, nlme, MASS, flextable, officer, plotly, htmlwidgets, htmltools, jsonlite) are
  used conditionally with `requireNamespace()`.
* 'SAS', 'PROC MIXED' and 'PROC MI' in the Description refer to the SAS software conventions the package reproduces;
  the package does not call SAS.
