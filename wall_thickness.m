function wall_thickness(ds)
% WALL_THICKNESS Six-site local wall thickness tool (no volume measurement required).
% wall_thickness                 Select a DICOM and resample it
% wall_thickness(heart1)         Use an already loaded volume without resampling again
% MATLAB R2022a+; Image Processing Toolbox required.
% Run help wall_thickness, or use the Chinese instructions shown on startup.

instructions = {
    'Six sites: Left Upper, Left Middle, Left Lower, Right Upper, Right Middle, Right Lower.';
    'Labels describe screen positions, not anatomical wall names or standard myocardial segments.';
    'On the first frame of one long-axis slice, draw six lines from the cavity through the wall to the outside.';
    'Brightness gradients locate both boundaries. Each line is tracked independently; review every site in every frame.';
    'Draw approximately perpendicular to the local wall. A fixed slice cannot guarantee tracking the same 3D tissue.';
    'Correct or skip individual sites without affecting the other five sites.';
    'Select the frame range and verify length units. Without frame timing, the x-axis shows frame numbers.';
    'Volume measurement is not required. ED/ES, EF and volume results are not used.';
    'Stopping retains accepted results. Output includes six curves, CSV and MAT files.';
    'Run demo_wall_thickness to preview the result layout with synthetic data.'};
uiwait(helpdlg(instructions, 'How to use: six-site local wall thickness'));
if exist('imresize3', 'file') == 0
    error('wall:Toolbox', 'Image Processing Toolbox is required.');
end
if nargin == 0
    [file, folder] = uigetfile('*.dcm', 'Select a cardiac DICOM file');
    if isequal(file, 0), return; end
    ds = resampleDicom(fullfile(folder, file));
end
required = {'data','width','height','depth','NumVolumes','widthspan','heightspan','depthspan'};
assert(isstruct(ds) && isscalar(ds) && all(isfield(ds, required)), ...
    'wall:Data', 'Input must be a volume structure returned by resampleDicom.');
dims = [ds.width ds.height ds.depth ds.NumVolumes];
assert(numel(dims) == 4 && all(isfinite(dims)) && all(dims == fix(dims)) && ...
    all(dims(1:3) >= 3) && dims(4) >= 1 && isnumeric(ds.data) && isreal(ds.data) && ...
    ndims(ds.data) <= 4 && isequal(dims, ...
    [size(ds.data,1) size(ds.data,2) size(ds.data,3) size(ds.data,4)]), ...
    'wall:Dimensions', 'Invalid volume dimensions. Check that you are using the corrected resampleDicom.');
spacing = [ds.widthspan ds.heightspan ds.depthspan] ./ dims(1:3);
assert(all(isfinite(spacing) & spacing > 0), 'wall:Spacing', 'Voxel spacing must be finite and positive.');
unit = questdlg('Verify the original DICOM length units (not detected automatically):', ...
    'Confirm units', 'cm', 'mm', 'Cancel', 'Cancel');
if strcmp(unit, 'cm'), spacing = spacing * 10;
elseif ~strcmp(unit, 'mm'), return;
end
settings = inputdlg({'First frame (inclusive)','Last frame (inclusive)', ...
    'Frame interval in ms (known and constant only; otherwise leave blank)'}, 'Frame range', 1, ...
    {'1',num2str(ds.NumVolumes),''});
if isempty(settings), return; end
first = str2double(settings{1}); last = str2double(settings{2});
assert(all(isfinite([first last])) && first == fix(first) && last == fix(last) && ...
    first >= 1 && last <= ds.NumVolumes && first <= last, 'wall:Range', 'Invalid frame range.');
dt = nan;
if ~isempty(strtrim(settings{3}))
    dt = str2double(settings{3}) / 1000;
    assert(isfinite(dt) && dt > 0, 'wall:Time', 'Frame interval must be positive or left blank.');
end
result = wall.local(ds, spacing, first:last);
if isempty(result), return; end
result.spacing_mm = spacing;
result.frame_interval_s = dt;
result.source_dimensions = dims;
if isfinite(dt)
    result.table.Time_s = (result.table.Frame - first) * dt;
end
wall.plotResults(result);
disp(result.table);
choice = questdlg('Save a CSV summary and MAT data for review?', 'Save results', 'Save', 'Cancel', 'Save');
if strcmp(choice, 'Save')
    [file, folder] = uiputfile('*.mat', 'Save thickness results (also creates a CSV with the same name)', 'wall_results.mat');
    if ~isequal(file, 0)
        [~, stem] = fileparts(file);
        csvPath = fullfile(folder, [stem '.csv']);
        matPath = fullfile(folder, [stem '.mat']);
        if isfile(csvPath) || isfile(matPath)
            answer = questdlg('A MAT or CSV with this name already exists. Replace both files?', ...
                'Confirm overwrite', 'Replace', 'Cancel', 'Cancel');
            if ~strcmp(answer, 'Replace'), return; end
        end
        save(matPath, 'result', '-v7.3');
        writetable(result.table, csvPath);
    end
end
end
