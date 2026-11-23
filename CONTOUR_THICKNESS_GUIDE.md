# Manual contour wall thickness

This workflow measures a closed myocardial ring on one fixed 2D plane over a
user-selected frame range. It complements the existing six-line workflow.
It does not require LV volume measurement, ED/ES assignment or automatic segmentation.
All controls, result labels and exports are in English.

## Start in MATLAB

Keep `wall_contours.m` and the entire `+wall` folder together. Use MATLAB R2022a
or newer with Image Processing Toolbox and an interactive display.

```matlab
result = wall_contours;          % Select a DICOM and resample once
% Or, if already loaded:
result = wall_contours(heart1);  % No second resampling
```

The main viewer also provides **Wall thickness (contours)**. To preview the
result layout without DICOM, run `demo_wall_contours`. Its circular contours
and thickness changes are synthetic, not patient measurements.

## Measure a cycle

1. Enter the **first and last frame**, inclusive. Choose a range that covers
   the cycle you intend to measure; the program does not identify a cycle.
   Leave the frame interval blank unless its constant value is known. The
   plot then uses frame numbers rather than inventing a time scale.
2. Keep **200 samples** initially. These are computational measurement points,
   not the number of vertices you need to draw. Enter a descriptive region name.
3. For a whole-ring mean, keep **start = 0, extent = 360**. For a local region,
   choose an angular sector: right = 0 degrees, up = 90, left = 180, down = 270.
   Extent increases counterclockwise; start 315 and extent 90 crosses 0 degrees.
   Start 0 and extent 90 selects the upper-right quadrant. These are image
   directions, not automatically identified anatomical segments.
4. In the maximized plane preview, select a data-axis dimension and use the
   slider to find a plane showing a **closed LV myocardial ring**. Click
   **Use this plane for all frames**. Dimension 3 is initially shown but is
   not guaranteed to be anatomically short-axis. Oblique reformatting is not
   implemented. A long-axis cavity open at the valve cannot be measured as
   a closed ring with this workflow.
5. Click **Draw / replace inner contour** and trace the endocardial wall
   boundary. Click vertices and double-click to finish. Papillary muscles
   projecting into the cavity are not the compact myocardial wall boundary;
   do not trace their individual outlines as part of the wall.
6. Click **Draw / replace outer contour** and trace the epicardial wall
   boundary. The outer contour must completely enclose the inner contour.
   Drag vertices to correct either contour. Crossing, touching, degenerate
   and self-intersecting contours are rejected instead of silently repaired.
7. Click **Preview thickness**. Green segments show the selected local
   measurements. Yellow dashed rays show the sector limits when applicable.
   The sidebar displays the regional mean in both mm and cm and the sample
   count. Review the boundaries and selected region, then click
   **Accept frame / Next** once. Accept also recomputes after any edits.
8. On the next frame, faint dotted/dashed contours show the **last accepted
   frame**, whose number is displayed above the image. These are fixed
   positional guides. Draw new contours or click **Use previous contours as
   editable copies**, then adjust the colored copies to the current anatomy.
   The faint references stay unchanged. Copying is not automatic tracking.
9. **Skip frame** leaves a gap and does not advance the reference contours.
   **Stop (keep earlier frames)** or closing the window discards the current
   unaccepted frame and retains earlier results. All remaining frames in the
   requested range are exported as `not_measured`. A new run starts without
   previous contours.

The result window shows the first accepted frame with its local distances,
and a curve of **regional mean thickness per frame**. Skipped/unmeasured
frames remain NaN, with gaps in the curve. The curve is a whole-ring mean
only when the chosen extent is 360 degrees. A single-frame range is valid.

## Exact measurement definition

- Map image coordinates to physical coordinates with the plane's separate
  column and row voxel spacing. Drawing and measurement use the same mapping.
- Treat each manually drawn contour as a closed, piecewise-linear polygon.
  Do not automatically smooth or reshape the user's boundaries.
- Sample the inner polygon uniformly by **physical arc length**. With inner
  perimeter `L` and `N` samples, sample `k` is at `(k + 0.5) * L/N`, for
  `k = 0,...,N-1`. Canonical contour orientation and start vertex make the
  result independent of drawing direction or which existing vertex came first.
  Adding collinear vertices does not give a region more weight.
- At every sample, compute the **shortest Euclidean distance to any outer
  polygon segment**, using projection onto the segment, not nearest-vertex
  distance. This is a one-sided, inner-to-outer 2D distance estimate. It is
  not a surface-normal thickness or a Laplace-based 3D thickness estimate.
- For a sector, retain samples whose physical angle about the current inner
  polygon's area centroid falls within the chosen start and extent. The
  centroid follows translation; the sector orientation stays in image
  coordinates. At least three selected samples are required. Samples are
  still uniform in inner arc length, not in angle.
- Report the arithmetic mean of selected distances. No physiological-range
  clipping or automatic outlier deletion is applied. The median is saved as
  a secondary diagnostic, not substituted for the mean. If a selected shortest
  path crosses back through the cavity, the frame is rejected for review;
  such paths are not silently omitted from the average.

The same plane, sample count, distance rule and sector settings apply to all
frames in a run. Arc spacing and the selected sample count can change as the
wall changes shape; both are exported. Sample indices do **not** identify the
same tissue through time. For comparisons across visits, choose corresponding
anatomical levels and regions and align cardiac phase yourself. A fixed plane
or angular sector does not compensate for rotation or out-of-plane motion.

## Units

As previously requested for this project, original X/Y/Z spacing is **assumed
to be cm**, including the private depth spacing. The reported DICOM unit tags
were 0 (None), so this assumption is not verified calibration. The new entry
point converts its local spacing vector to mm exactly once, without changing
the loaded dataset. Resampling alone does not establish a physical unit.
`10 mm = 1 cm`; the same mean is displayed/exported in both units.

## Save and inspect

Choose a basename in the save dialog to create:

- `<name>.mat`: `result`, including all accepted contours, sample endpoints,
  selection masks, settings, source dimensions and unit-assumption metadata.
- `<name>.csv`: one row per requested frame; mean in mm/cm, secondary median
  in mm, status, selected sample count, inner arc spacing, plane/slice, sector,
  distance definition and source-unit assumption. Known timing adds `Time_s`.
- `<name>_samples.csv`: one row per sample of each accepted frame, including
  endpoints in image pixels, local thickness, angle and `IncludedInMean`.
  Samples outside the sector are retained for audit but do not affect the
  reported mean. Skipped/unmeasured frames have no fabricated sample rows.

Canceling the save dialog keeps the displayed result. If called with an
output variable, it also remains available as `result` in your MATLAB workspace.

## Validation

The cloud environment does not have MATLAB. Automated MATLAB tests and the
interactive GUI therefore still need to be run locally:

```matlab
assertSuccess(runtests('tests/test_contour_thickness.m'))
demo_wall_contours
```

The tests cover known concentric-circle thickness, unequal voxel spacing,
uniform sampling despite uneven vertices, contour-order invariance, segment
projection, sector wrap/translation, invalid polygons, image/spacing axis
mapping and local-distance exports. They do not validate real ultrasound
boundary identification.

Before measuring a full cycle, try three frames. Preview and edit both
contours, accept one frame, skip one, and verify that the final frame still
shows the first accepted frame's faint references. Close a review window and
check that unaccepted data stay missing. Compare the displayed mean with the
mean of sample-CSV rows having `IncludedInMean = true`. Verify the chosen
region remains anatomically appropriate through motion and across visits.
