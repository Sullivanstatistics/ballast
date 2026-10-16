## Test environments

* local Windows 11, R 4.5.3
* GitHub Actions: windows-latest (release), macos-latest (release), ubuntu-latest (release, devel)

## R CMD check results

0 errors | 0 warnings | 1 note (new submission)

## Notes

* Examples that run multiple imputation, the deletion search or the calibration are wrapped in \donttest and run in
  under five seconds each on the test machines.
* Suggested packages (ggplot2, emmeans, nlme, MASS, flextable, officer, plotly, htmlwidgets, htmltools, jsonlite) are
  used conditionally.
