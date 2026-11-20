# Six-site local wall thickness

Requires MATLAB R2022a or newer and Image Processing Toolbox. Keep the `+wall`
folder beside `wall_thickness.m`. Extract into a new folder to avoid mixing
versions. The existing LV volume workflow remains available, but thickness
measurement does not require it and does not use ED/ES or calculate thickening
fractions. The former 3D workflow has been removed.

## Preview the layout

Run `demo_wall_thickness`. It calls the actual result display function using
synthetic images and curves; no DICOM is needed. The left panel shows six site
markers; the right shows six curves. One missing example measurement creates
a gap. This is a layout demonstration, not a measurement or accuracy test.

![Synthetic result layout (not a MATLAB screenshot)](docs/six_site_preview.png)

## Measure real data

1. Run `wall_thickness` to select a DICOM, or `wall_thickness(heart1)` to use
   loaded data. Alternatively, click **Wall thickness (6 sites)** in the viewer.
2. Verify the original length units (cm or mm) and select the first and last
   frame. Enter a frame interval in milliseconds only if it is known and
   constant; otherwise leave it blank.
3. Enter the long-axis slice number (the original viewer's Slice), thickness
   search range and translation search radius. The default 1-25 mm range is
   a search setting, not a physiological reference range.
4. On the first frame of the same slice, draw six lines in this order:
   **Left Upper, Left Middle, Left Lower, Right Upper, Right Middle, Right Lower**.
   Draw each line from inside the cavity through the wall to the outside,
   approximately perpendicular to the local wall. Double-click to finish.
   These labels describe screen positions, not anatomical wall names or
   standard myocardial segments.
5. Review all six sites in each frame. Colored solid lines show detected
   boundaries; dashed lines show the search line. Gray lines are other site
   references, which may come from the previous frame or accepted measurements
   in the current frame. The right panel shows brightness along the current
   line. Accepting advances to the next site, then to the next frame after
   all six sites have been reviewed.
6. **Correct / Redraw** lets you redraw the search line or manually draw the
   inner-to-outer boundary segment. **Skip** affects only this site in this
   frame; the other sites continue, and this site must be reselected in the
   next frame. **Stop** or closing the window retains accepted results;
   unfinished sites in the current frame are marked `not_measured`.
7. The final left panel shows the initial six locations on the first frame.
   The right panel shows six curves with matching colors. The x-axis is frame
   number, or seconds from the selected first frame if timing was provided.
   Thickness is in mm. Missing measurements are not interpolated.

## Save results

Each CSV row represents one frame and one site: `Frame`, `SiteID` (1-6),
`Site`, `Thickness_mm`, `Status`, and optional `Time_s`. Status is `skipped`,
`reviewed_auto`, `reviewed_corrected`, or `not_measured`. Missing values are
NaN, not zero. Site names are exported in English.

The MAT file also stores the first-frame image and initial lines, per-frame
and per-site boundary/search-line coordinates, units and settings.

## Limitations and validation

The algorithm uses brightness-gradient detection and local 2D translation
matching. It cannot guarantee tracking the same 3D tissue. Rotation,
out-of-plane motion, shadows and papillary muscles can affect results;
review is required. Oblique measurement lines can overestimate thickness.
The six lines track independently: check that they retain their intended
upper/middle/lower positions.

MATLAB is unavailable in the cloud environment. Numerical tests and actual
GUI interaction have not been executed there. Run locally:

```matlab
results = runtests('tests/test_wall_algorithms.m');
assertSuccess(results)
```

Also check initialization of all six lines, independent tracking in the
second frame, correcting/skipping one site, missing values after stopping
partway through a frame, and the correspondence between curves and CSV site
labels. Try a few frames before measuring a complete cycle.
