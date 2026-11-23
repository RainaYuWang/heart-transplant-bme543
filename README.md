# heart-transplant-bme543

## Contour-based regional mean wall thickness

Run `result = wall_contours` to select a DICOM, or
`result = wall_contours(heart1)` with loaded data. The viewer also provides
**Wall thickness (contours)**. Select an inclusive frame range and a fixed
plane, then draw the inner and outer myocardial contours on each frame.
Faint outlines show the last accepted frame; optionally copy and edit them.
Uniform physical arc-length samples on the inner contour are measured to
the closest outer contour segments. Choose a whole-ring mean or a fixed
angular region; the result plots its mean thickness per frame.
Run `demo_wall_contours` for a synthetic preview. See the
[contour workflow guide](CONTOUR_THICKNESS_GUIDE.md) for usage, the exact
distance definition, exports and limitations. This is manual 2D analysis;
the former automatic 3D workflow has not been restored.

## Six-site local wall thickness

Run `wall_thickness` to select one DICOM, or `wall_thickness(heart1)` with
already loaded data. The viewer also has a **Wall thickness (6 sites)** button.
On one long-axis slice, draw six lines: screen left upper/middle/lower and
screen right upper/middle/lower. Each site is tracked independently and reviewed together in one maximized window.
Drag boundary endpoints and accept all six sites once per frame.
The result shows six color-matched curves; missing measurements stay missing.
No volume measurement or ED/ES linkage is required or used. The 3D workflow
has been removed. Download the whole repository, including `+wall`.
Run `demo_wall_thickness` to preview the actual MATLAB result layout with
synthetic data, without DICOM. See [User guide](WALL_THICKNESS_GUIDE.md).
This project assumes original X/Y/Z spacing is in cm, as requested by the user.
The wall workflow converts spacing to mm once and labels the assumption in
results. The DICOM unit tags did not verify this convention.
Run `diagnose_dicom_units` only if further metadata investigation is needed.
Real-image accuracy, unit calibration and MATLAB GUI behavior still require local validation.

## MATLAB workflow

Use MATLAB R2022a or newer with Image Processing Toolbox (`imresize3`)
and an interactive display. Put the study files
`p045_2a.dcm`, `p045a.dcm`, and `p045_3a.dcm` beside `ht_exploration.m`.
The supplied `resampleDicom.m` is included. It reads each study with
`readDicom3D` and uses `imresize3` to resample each frame to isotropic
spacing equal to the smallest original voxel spacing.

The script calls `resampleDicom(filename)` for each study. Its single output
must be a struct with `data` arranged as `[width height depth NumVolumes]`,
the corresponding dimension fields, and `widthspan`, `heightspan`, and
`depthspan` in **centimetres**, updated consistently after resampling.
The included resampler returns this struct and updates dimensions and spans.
Units are inherited from the DICOM reader; confirm they are centimetres for
your study. Run `ht_exploration` from MATLAB.

Browse the frames to identify one cardiac cycle and choose a long-axis slice.
Click **Measure cycle range**, enter the first and last frame (inclusive),
and measure every frame in that range. The application does not detect the
cycle automatically. For each frame, click the two annulus hinge points,
the apex, and the endpoints of two perpendicular cavity diameters on the
displayed cross-section. Accept or redo each measurement.

Starting with the second frame in a cycle measurement, gray dashed lines and
open circles show the previous accepted frame's annulus points, apex, and
short-axis diameter endpoints. Current measurements remain colored. The label
identifies the reference frame; short-axis views also show both depth indices
and flag different depths, since these are positional guides rather than
tracked anatomy. Click all points anew for the current frame. Only **Yes**
advances the reference; **No** keeps the previous accepted frame as the guide.
Each new measurement run starts without reference points, including standalone
current-frame measurements.

**Measure current LV volume** measures just the frame currently displayed;
it does not compute EF. Both modes show a per-frame LV volume table and
curve. Use **Save CSV** in the results window to save dataset, slice, frame,
LV volume in mL, and annulus diameter in cm. Each run replaces the viewer's
previous results for that dataset; existing result windows keep their own
tables, which can still be exported.

LV volume is an ellipsoid estimate, `pi/6 * longDiameter * shortDiameter1 *
shortDiameter2`, not a segmented voxel volume. The existing cross-section is
a fixed data-depth slice near the long-axis midpoint; it is not an oblique
plane reconstructed perpendicular to the measured long axis. EF is computed
from the maximum and minimum volumes only after all frames in the selected
cycle range have been accepted. Cancelling partway retains accepted volumes
but does not report cycle EF; cancelling before accepting any measurements
preserves the previous results.

## Validation

The cloud environment has no MATLAB installation or study data. Interactive
execution and resampling integration therefore require validation in MATLAB
with the supplied resampler and real study files. Check a valid cycle range,
invalid/noninteger/out-of-bounds ranges, redo and cancellation, a single-frame
measurement, dataset switching, and CSV export. Confirm resampled physical
spans and voxel spacing before interpreting the volume measurements.
For reference overlays, measure two consecutive frames and check both views;
redo the second frame to confirm the first frame remains the reference. Accept
the second frame and check that the third now references it. Check the depth
label when short-axis depth changes, and verify that a new range or another
dataset starts without old reference points.
