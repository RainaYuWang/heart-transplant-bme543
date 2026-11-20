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
5. All six candidate boundary segments appear together in a maximized window.
   Drag any colored segment or its endpoints to correct it. The sidebar lists
   thickness in both mm and cm, and the selected-site brightness profile.
   Use the site selector for **Redraw search line**, **Draw manual boundaries**,
   or **Skip selected site**. There are no per-site confirmation dialogs.
6. Click **Accept frame / Next** once after reviewing all six sites. Any site
   with no valid boundaries must be drawn or explicitly skipped first. Skipping
   affects only that site. In the next frame, a skipped site needs a new search
   line or manual boundaries. **Stop (keep earlier frames)** or closing the
   window retains earlier accepted frames; unaccepted current-frame edits are
   discarded and shown as `not_measured` if earlier results exist.
7. The final left panel shows the initial six locations on the first frame.
   The right panel shows six curves with matching colors. The x-axis is frame
   number, or seconds from the selected first frame if timing was provided.
   Thickness is in mm. Missing measurements are not interpolated.

## Save results

Each CSV row represents one frame and one site: `Frame`, `SiteID` (1-6),
`Site`, `Thickness_mm`, `Thickness_cm`, `Status`, and optional `Time_s`. Status is `skipped`,
`reviewed_auto`, `reviewed_corrected`, or `not_measured`. Missing values are
NaN, not zero. Site names are exported in English.

The MAT file also stores the first-frame image and initial lines, per-frame
and per-site boundary/search-line coordinates, units and settings, including the declared source unit and its unverified calibration status.

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

## Verify units before interpreting values

The unit selection describes the original spacing unit, not the display unit.
Choosing cm multiplies the stored spacing by 10 for mm output; choosing mm does
not. For identical points, a 1-4 mm result would become 10-40 mm if cm were
selected. This is not a way to calibrate against an expected range.

Run `diagnose_dicom_units`, select the original DICOM, and save the small
`dicom_units_report_v3.txt`. Version 3 also includes a separate scan matching the supplied Sonos reader
(including its six-byte OB skip). The standard scan inspects the flat explicit-little-endian
header used by the legacy reader, reports metadata field names and handles
metadata struct arrays/cells. Unsupported layouts are identified explicitly.
It includes only whitelisted geometry/unit values
and the raw spacing used by the legacy reader; no patient identifiers, dates,
paths or image pixels are exported. Ultrasound region unit code 3 denotes cm
for the corresponding axis, but the depth spacing comes from a private tag
and must be verified separately. No automatic unit inference has been added.

A report containing `Fields: {}` has not established the source units. The
reported raw voxel spacing alone supports a field-of-view plausibility check,
not a verified calibration. The report prints field of view under both cm and
mm assumptions to make that distinction explicit.

The uploaded study exceeded the 32 MiB attachment-transfer limit, so its actual
metadata and images have not been inspected in the cloud. The UI improvements
are independent of this unresolved calibration. Do not treat current absolute
thickness measurements as validated until calibration and boundaries are checked.
