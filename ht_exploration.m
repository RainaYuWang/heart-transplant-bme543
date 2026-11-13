% import and read files
% heart1 - p045_2a 11 months post op
% heart2 - p045_a  15 months post op
% heart3 - p045_3a 21 months post op

if exist('resampleDicom', 'file') == 0
    error('heartViewer:MissingResampler', ...
        'Add the supplied resampleDicom.m to the MATLAB path before running this script.');
end
dataDir = fileparts(mfilename('fullpath'));
heart1 = resampleDicom(fullfile(dataDir, 'p045_2a.dcm'));
heart2 = resampleDicom(fullfile(dataDir, 'p045a.dcm'));
heart3 = resampleDicom(fullfile(dataDir, 'p045_3a.dcm'));

% check sizes and voxel dimensions of the 3D heart images
hearts = {heart1, heart2, heart3};
names  = {'11 mo post-op', '15 mo post-op', '21 mo post-op'};
for k = 1:3
    v = hearts{k};
    validateHeartData(v);
    fprintf('%s: %d x %d x %d voxels, %d frames | voxel = %.3f x %.3f x %.3f | span = %.1f x %.1f x %.1f\n', ...
        names{k}, v.width, v.height, v.depth, v.NumVolumes, ...
        v.widthspan/v.width, v.heightspan/v.height, v.depthspan/v.depth, ...
        v.widthspan, v.heightspan, v.depthspan);
end

% interactive viewer
heartViewer(hearts, names);


%% ---------------- local functions ----------------

function validateHeartData(v)
    % Resampling must return data plus updated physical geometry in cm.
    fields = {'data', 'width', 'height', 'depth', 'NumVolumes', ...
        'widthspan', 'heightspan', 'depthspan'};
    if ~isstruct(v) || ~isscalar(v) || ~all(isfield(v, fields))
        error('heartViewer:ResamplerOutput', ...
            'resampleDicom must return a scalar volume struct with data, dimensions, NumVolumes and spans in cm.');
    end
    dims = [v.width v.height v.depth v.NumVolumes];
    spans = [v.widthspan v.heightspan v.depthspan];
    if numel(dims) ~= 4 || any(~isfinite(dims) | dims < 1 | dims ~= fix(dims)) || ...
            numel(spans) ~= 3 || any(~isfinite(spans) | spans <= 0) || ...
            ~(isnumeric(v.data) && isreal(v.data)) || ndims(v.data) > 4 || ...
            ~isequal([size(v.data,1) size(v.data,2) size(v.data,3) size(v.data,4)], dims)
        error('heartViewer:ResamplerGeometry', ...
            'Resampled data must match [width height depth NumVolumes] with positive physical spans in cm.');
    end
    if any(dims(1:3) < 2) || any(~isfinite(v.data(:)))
        error('heartViewer:ResamplerData', 'Viewer requires finite 3D data with at least two voxels per spatial axis.');
    end
end

function heartViewer(hearts, names)

    ds = hearts{1};
    F = ds.NumVolumes;
    H = size(ds.data, 2);
    c0 = round(H / 2);

    fig = figure('Name', 'Heart viewer', 'Color', 'k', 'NumberTitle', 'off');
    ax = axes(fig, 'Position', [0.03 0.28 0.77 0.65]);

    S.hearts = hearts;
    S.ax = ax;
    S.img = imagesc(ax, squeeze(ds.data(:, c0, :, 1)).');
    colormap(ax, gray); axis(ax, 'image', 'off');
    clim(ax, double([min(ds.data(:)) max(ds.data(:))]));
    S.title = title(ax, '', 'Color', 'w');
    S.k = 1;

    n = numel(hearts);
    S.vols = cell(1, n);  S.vframes = cell(1, n);
    S.EDV = nan(1, n);  S.EDframe = nan(1, n);
    S.ESV = nan(1, n);  S.ESframe = nan(1, n);
    S.completeCycle = false(1, n);

    % dataset dropdown
    S.popup = uicontrol(fig, 'Style', 'popupmenu', 'String', names, 'Units', 'normalized', ...
        'Position', [0.82 0.88 0.15 0.05], 'Callback', @(src, ~) switchHeart(fig, src.Value));

    % generate volumes button + results text
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Measure cycle range', 'Units', 'normalized', ...
        'Position', [0.82 0.80 0.15 0.07], 'Callback', @(~,~) generateVolumes(fig));
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Measure current LV volume', 'Units', 'normalized', ...
        'Position', [0.82 0.72 0.15 0.07], 'Callback', @(~,~) generateVolumes(fig, true));
    S.resultText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.81 0.28 0.18 0.43], 'BackgroundColor', 'k', 'ForegroundColor', 'w', ...
        'HorizontalAlignment', 'left', 'FontSize', 11);

    % frame slider + typed box
    uicontrol(fig, 'Style', 'text', 'String', 'Frame', 'Units', 'normalized', ...
        'Position', [0.03 0.13 0.15 0.04], 'BackgroundColor', 'k', 'ForegroundColor', 'w');
    S.frameSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.2 0.13 0.5 0.04], 'Min', 1, 'Max', F, 'Value', 1, ...
        'SliderStep', [1/max(F-1,1) 5/max(F-1,1)], 'Callback', @(~,~) updateView(fig));
    S.frameEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.72 0.13 0.08 0.04], 'String', '1', ...
        'Callback', @(~,~) typedValue(fig, 'frame'));

    % slice slider + typed box
    uicontrol(fig, 'Style', 'text', 'String', 'Slice', 'Units', 'normalized', ...
        'Position', [0.03 0.07 0.15 0.04], 'BackgroundColor', 'k', 'ForegroundColor', 'w');
    S.colSlider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.2 0.07 0.5 0.04], 'Min', 1, 'Max', H, 'Value', c0, ...
        'SliderStep', [1/(H-1) 10/(H-1)], 'Callback', @(~,~) updateView(fig));
    S.colEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
        'Position', [0.72 0.07 0.08 0.04], 'String', num2str(c0), ...
        'Callback', @(~,~) typedValue(fig, 'slice'));

    % play button
    S.playBtn = uicontrol(fig, 'Style', 'togglebutton', 'String', 'Play', 'Units', 'normalized', ...
        'Position', [0.82 0.12 0.15 0.05], 'Callback', @(~,~) playFrames(fig));

    guidata(fig, S);
    updateView(fig);

end

function typedValue(fig, which)
    S = guidata(fig);
    ds = S.hearts{S.k};
    switch which
        case 'frame'
            v = str2double(S.frameEdit.String);
            if isnan(v), v = S.frameSlider.Value; end
            S.frameSlider.Value = min(max(round(v), 1), ds.NumVolumes);
        case 'slice'
            v = str2double(S.colEdit.String);
            if isnan(v), v = S.colSlider.Value; end
            S.colSlider.Value = min(max(round(v), 1), size(ds.data, 2));
    end
    updateView(fig);
end

function switchHeart(fig, k)
    S = guidata(fig);
    S.playBtn.Value = 0;  S.playBtn.String = 'Play';
    ds = S.hearts{k};
    F = ds.NumVolumes;
    H = size(ds.data, 2);
    S.k = k;
    S.frameSlider.Max = F;  S.frameSlider.Value = 1;
    S.frameSlider.SliderStep = [1/max(F-1,1) 5/max(F-1,1)];
    S.colSlider.Max = H;    S.colSlider.Value = round(H / 2);
    S.colSlider.SliderStep = [1/(H-1) 10/(H-1)];
    clim(S.ax, double([min(ds.data(:)) max(ds.data(:))]));
    guidata(fig, S);
    updateView(fig);
end

function updateView(fig)
    S = guidata(fig);
    ds = S.hearts{S.k};
    f = round(S.frameSlider.Value);  S.frameSlider.Value = f;
    c = round(S.colSlider.Value);    S.colSlider.Value = c;
    S.frameEdit.String = num2str(f);
    S.colEdit.String = num2str(c);
    S.img.CData = squeeze(ds.data(:, c, :, f)).';
    S.title.String = sprintf('%s   |   Frame %d / %d   |   Slice %d', ...
        S.popup.String{S.k}, f, ds.NumVolumes, c);
    updateResults(S);
    drawnow limitrate;
end

function updateResults(S)
    k = S.k;
    L = {S.popup.String{k}, ''};
    if isempty(S.vols{k})
        L{end+1} = 'No volumes yet.';
        L{end+1} = 'Measure a cycle or current frame.';
    else
        f = round(S.frameSlider.Value);
        i = find(S.vframes{k} == f, 1);
        if ~isempty(i)
            L{end+1} = sprintf('Frame %d LV = %.1f mL', f, S.vols{k}(i));
        else
            L{end+1} = sprintf('Frame %d: not measured', f);
        end
        if ~S.completeCycle(k)
            L{end+1} = 'No complete cycle measured; EF unavailable.';
            S.resultText.String = L;
            return;
        end
        L{end+1} = sprintf('ED (max): frame %d', S.EDframe(k));
        L{end+1} = sprintf('EDV = %.1f mL', S.EDV(k));
        L{end+1} = '';
        L{end+1} = sprintf('ES (min): frame %d', S.ESframe(k));
        L{end+1} = sprintf('ESV = %.1f mL', S.ESV(k));
        L{end+1} = '';
        L{end+1} = sprintf('SV = %.1f mL', S.EDV(k) - S.ESV(k));
        L{end+1} = sprintf('EF = %.1f %%', (S.EDV(k) - S.ESV(k)) / S.EDV(k) * 100);
    end
    S.resultText.String = L;
end

function playFrames(fig)
    S = guidata(fig);
    if S.playBtn.Value == 0
        S.playBtn.String = 'Play';
        return;
    end
    S.playBtn.String = 'Pause';
    nF = S.hearts{S.k}.NumVolumes;
    while isvalid(fig) && S.playBtn.Value == 1
        f = round(S.frameSlider.Value) + 1;
        if f > nF, f = 1; end
        S.frameSlider.Value = f;
        updateView(fig);
        pause(0.05);                 % playback speed: larger = slower
    end
    if isvalid(fig), S.playBtn.String = 'Play'; end
end

%% ---------------- volume over time (ellipsoid method)  ----------------

function generateVolumes(fig, currentOnly)
    if nargin < 2, currentOnly = false; end
    S = guidata(fig);
    S.playBtn.Value = 0;  S.playBtn.String = 'Play';
    k  = S.k;
    ds = S.hearts{k};
    c  = round(S.colSlider.Value);          % long-axis slice used for every frame
    F  = ds.NumVolumes;

    if currentOnly
        frames = round(S.frameSlider.Value);
    else
        % User identifies one cardiac cycle; both endpoints are included.
        while true
            ans_ = inputdlg({sprintf('First frame of one cycle (1-%d):', F), ...
                sprintf('Last frame of that cycle (1-%d):', F)}, ...
                'Select one cardiac cycle', 1, {num2str(round(S.frameSlider.Value)), num2str(F)});
            if isempty(ans_), return; end
            first = str2double(ans_{1}); last = str2double(ans_{2});
            if isfinite(first) && isfinite(last) && first == fix(first) && ...
                    last == fix(last) && first >= 1 && last <= F && first < last
                break;
            end
            uiwait(errordlg('Enter integer frames satisfying 1 <= first < last <= frame count.', 'Invalid range'));
        end
        frames = first:last;
    end
    vols = nan(size(frames));
    ann  = nan(size(frames));

    % voxel size in cm (spans are in cm)
    dx = ds.widthspan  / ds.width;
    dy = ds.heightspan / ds.height;
    dz = ds.depthspan  / ds.depth;

    % Reference belongs only to this run/dataset/slice and advances on Yes.
    previousPoints = [];
    n = 1;
    while n <= numel(frames)
        [V, A, status, points] = measureFrame(ds, c, frames(n), dx, dy, dz, n, numel(frames), previousPoints);
        switch status
            case 'yes'
                vols(n) = V; ann(n) = A;
                previousPoints = points;
                n = n + 1;
            case 'no'      % redo the same frame
            case 'cancel', break;
        end
    end

    valid = isfinite(vols) & vols > 0;
    if ~any(valid)
        fprintf('No measurements accepted; previous results retained.\n');
        return;
    end
    fr = frames(valid);  v = vols(valid);
    completeCycle = ~currentOnly && all(valid);
    S = guidata(fig);
    S.vols{k} = v;  S.vframes{k} = fr;
    S.completeCycle(k) = completeCycle;
    S.EDV(k) = nan; S.ESV(k) = nan;
    S.EDframe(k) = nan; S.ESframe(k) = nan;

    results = table(repmat(S.popup.String(k), numel(fr), 1), ...
        repmat(c, numel(fr), 1), fr(:), v(:), reshape(ann(valid), [], 1), ...
        'VariableNames', {'Dataset', 'Slice', 'Frame', 'LVVolume_mL', 'AnnulusDiameter_cm'});
    disp(results);
    if completeCycle
        [EDV, iED] = max(v);
        [ESV, iES] = min(v);
        S.EDV(k) = EDV; S.EDframe(k) = fr(iED);
        S.ESV(k) = ESV; S.ESframe(k) = fr(iES);
        EF = (EDV - ESV) / EDV * 100;
        fprintf('Selected cycle %d-%d: EDV %.1f mL, ESV %.1f mL, SV %.1f mL, EF %.1f %%\n', ...
            frames(1), frames(end), EDV, ESV, EDV - ESV, EF);
        S.frameSlider.Value = fr(iED);
    else
        fprintf('LV volumes retained; EF not computed without a fully measured cycle range.\n');
        S.frameSlider.Value = fr(1);
    end
    guidata(fig, S);
    updateView(fig);

    resultFig = figure('Name', 'LV volume measurements (ellipsoid estimate)', 'NumberTitle', 'off');
    uitable(resultFig, 'Data', table2cell(results), ...
        'ColumnName', results.Properties.VariableNames, 'Units', 'normalized', ...
        'Position', [0.02 0.15 0.96 0.83]);
    uicontrol(resultFig, 'Style', 'pushbutton', 'String', 'Save CSV', ...
        'Units', 'normalized', 'Position', [0.72 0.03 0.25 0.08], ...
        'Callback', @(~,~) saveVolumeResults(results));

    figure('Name', 'LV volume curve', 'NumberTitle', 'off');
    plot(fr, v, '-o', 'LineWidth', 1.2); hold on;
    xlabel('Frame'); ylabel('LV volume (mL)'); grid on;
    if completeCycle
        plot(fr(iED), EDV, 'r*', 'MarkerSize', 12);
        plot(fr(iES), ESV, 'b*', 'MarkerSize', 12);
        title(sprintf('%s | EDV %.1f, ESV %.1f, EF %.1f%%', S.popup.String{k}, EDV, ESV, EF));
        legend('Volume', 'ED (max)', 'ES (min)', 'Location', 'best');
    else
        title(sprintf('%s | LV volume (no cycle EF)', S.popup.String{k}));
    end

    figure('Name', 'Mitral annulus', 'NumberTitle', 'off');
    plot(fr, ann(valid), '-o', 'LineWidth', 1.2); grid on;
    xlabel('Frame'); ylabel('Annulus diameter (cm)');
    title([S.popup.String{k} ' | mitral annulus diameter']);
end

function saveVolumeResults(results)
    [file, folder] = uiputfile('*.csv', 'Save LV volume measurements', 'lv_volumes.csv');
    if isequal(file, 0), return; end
    try
        writetable(results, fullfile(folder, file));
    catch err
        errordlg(err.message, 'Could not save measurements');
    end
end

function [V, annDiam, status, points] = measureFrame(ds, c, f, dx, dy, dz, n, nTotal, previousPoints)
    V = nan;  annDiam = nan;  status = 'cancel'; points = [];
    gmin = double(min(ds.data(:)));  gmax = double(max(ds.data(:)));

    % long-axis slice
    img = squeeze(ds.data(:, c, :, f)).';
    [nz, nx] = size(img);
    xcm = ((1:nx) - 0.5) * dx;
    zcm = ((1:nz) - 0.5) * dz;

    fg = figure('Name', 'Long axis', 'NumberTitle', 'off', 'Color', 'k');
    ax = axes(fg);
    imagesc(ax, xcm, zcm, img); colormap(ax, gray); hold(ax, 'on');
    axis(ax, 'image');  clim(ax, [gmin gmax]);
    styleAxes(ax, xcm, zcm);
    drawPreviousPoints(ax, previousPoints, 'long', []);

    ttl = sprintf('Frame %d (%d of %d): click the two MITRAL ANNULUS hinge points', f, n, nTotal);
    [xa, ya] = clickLine(fg, ax, ttl, 'c');
    if isempty(xa), if isvalid(fg), close(fg); end, return; end
    plot(ax, xa, ya, 'c-o', 'LineWidth', 1.5);
    mid = [mean(xa) mean(ya)];
    plot(ax, mid(1), mid(2), 'y+', 'MarkerSize', 12, 'LineWidth', 2);
    annDiam = norm([diff(xa), diff(ya)]);

    ttl = sprintf('Frame %d (%d of %d): click the APEX (annulus = %.2f cm)', f, n, nTotal, annDiam);
    [xp, yp] = clickLine(fg, ax, ttl, 'r', mid);
    if isempty(xp), if isvalid(fg), close(fg); end, return; end
    x0 = xp(end);  y0 = yp(end);
    plot(ax, [x0 mid(1)], [y0 mid(2)], 'r-+', 'LineWidth', 1.5);
    Dmaj = norm([mid(1) - x0, mid(2) - y0]);
    pause(0.3);
    close(fg);

    % short-axis slice
    % halfway along the long axis
    xmid = (mid(1) + x0) / 2;
    zmid = (mid(2) + y0) / 2;
    d0 = min(max(round(zmid / dz + 0.5), 1), size(ds.data, 3));

    img2 = squeeze(ds.data(:, :, d0, f)).';
    [ny, nx2] = size(img2);
    xcm2 = ((1:nx2) - 0.5) * dx;
    ycm2 = ((1:ny) - 0.5) * dy;

    fg2 = figure('Name', 'Short axis', 'NumberTitle', 'off', 'Color', 'k');
    ax2 = axes(fg2);
    imagesc(ax2, xcm2, ycm2, img2); colormap(ax2, gray); hold(ax2, 'on');
    axis(ax2, 'image');  clim(ax2, [gmin gmax]);
    styleAxes(ax2, xcm2, ycm2);
    drawPreviousPoints(ax2, previousPoints, 'short', d0);
    plot(ax2, xmid, (c - 0.5) * dy, 'y+', 'MarkerSize', 14, 'LineWidth', 2);

    ttl = sprintf('Frame %d: SHORT AXIS 1 (depth %d). Click wall to wall across the cavity (long axis = %.2f cm)', f, d0, Dmaj);
    [xs1, ys1] = clickLine(fg2, ax2, ttl, 'g');
    if isempty(xs1), if isvalid(fg2), close(fg2); end, return; end
    plot(ax2, xs1, ys1, 'g-+', 'LineWidth', 1.5);
    s1 = norm([diff(xs1), diff(ys1)]);

    ttl = sprintf('Frame %d: SHORT AXIS 2. Click wall to wall, perpendicular to the first line (first = %.2f cm)', f, s1);
    [xs2, ys2] = clickLine(fg2, ax2, ttl, 'm');
    if isempty(xs2), if isvalid(fg2), close(fg2); end, return; end
    plot(ax2, xs2, ys2, 'm-+', 'LineWidth', 1.5);
    s2 = norm([diff(xs2), diff(ys2)]);

    V = (4/3) * pi * (Dmaj/2) * (s1/2) * (s2/2);     % cm^3 = mL
    if ~isfinite(V) || V <= 0
        uiwait(errordlg('Diameters must be positive. Please measure this frame again.', 'Invalid measurement'));
        if isvalid(fg2), close(fg2); end
        status = 'no';
        return;
    end

    title(ax2, sprintf('Frame %d: long %.2f, short %.2f x %.2f, annulus %.2f cm, volume %.1f mL', ...
        f, Dmaj, s1, s2, annDiam, V), 'Color', 'w', 'FontSize', 12);
    resp = questdlg('Are you satisfied with these clicked points?', 'Confirm', 'Yes', 'No', 'Cancel', 'Yes');
    if isvalid(fg2), close(fg2); end

    switch resp
        case 'Yes'
            status = 'yes';
            % All coordinates are physical cm, matching the displayed axes.
            points = struct('frame', f, 'depth', d0, ...
                'annulus', [xa(:) ya(:)], 'apex', [x0 y0], ...
                'short1', [xs1(:) ys1(:)], 'short2', [xs2(:) ys2(:)]);
        case 'No',     status = 'no';
        otherwise,     status = 'cancel';
    end
end

function drawPreviousPoints(ax, previous, view, currentDepth)
    if isempty(previous), return; end
    referenceColor = [0.65 0.65 0.65];
    if strcmp(view, 'long')
        mid = mean(previous.annulus, 1);
        lines = {previous.annulus, [mid; previous.apex]};
        label = sprintf('Gray dashed: accepted frame %d (reference only)', previous.frame);
    else
        lines = {previous.short1, previous.short2};
        label = sprintf('Gray dashed: accepted frame %d, depth %d (current depth %d)', ...
            previous.frame, previous.depth, currentDepth);
        if previous.depth ~= currentDepth
            label = {label, 'Different depth slices: use points only as a positional guide.'};
        end
    end
    for j = 1:numel(lines)
        xy = lines{j};
        plot(ax, xy(:,1), xy(:,2), '--o', 'Color', referenceColor, ...
            'LineWidth', 1, 'MarkerSize', 7, 'MarkerFaceColor', 'none', ...
            'HitTest', 'off', 'PickableParts', 'none');
    end
    text(ax, 0.02, 0.02, label, 'Units', 'normalized', ...
        'Color', referenceColor, 'BackgroundColor', 'k', 'FontSize', 9, ...
        'VerticalAlignment', 'bottom', 'Interpreter', 'none', ...
        'HitTest', 'off', 'PickableParts', 'none');
end

function styleAxes(ax, xcm, ycm)
    ax.XTick = 0:1:ceil(max(xcm));
    ax.YTick = 0:1:ceil(max(ycm));
    ax.XColor = 'w';  ax.YColor = 'w';  ax.Color = 'k';
    grid(ax, 'on');
    ax.GridColor = 'y';  ax.GridAlpha = 0.25;  ax.Layer = 'top';
    xlabel(ax, 'cm', 'Color', 'w');  ylabel(ax, 'cm', 'Color', 'w');
end

% Click a line with a live length readout in cm.
% With an anchor given, only one click is needed (distance from the anchor).
function [x, y] = clickLine(fg, ax, ttl, col, anchor)
    x = [];  y = [];
    if nargin < 5, anchor = []; end

    state.p1 = anchor;  state.done = false;  state.xs = [];  state.ys = [];
    state.h = plot(ax, nan, nan, [col '-'], 'LineWidth', 1.2);
    state.ax = ax;  state.ttl = ttl;
    title(ax, ttl, 'Color', 'w', 'FontSize', 12);
    fg.UserData = state;

    fg.WindowButtonMotionFcn = @(~,~) moveFcn(fg);
    fg.WindowButtonDownFcn   = @(~,~) clickFcn(fg);
    uiwait(fg);

    if ~isvalid(fg), return; end
    state = fg.UserData;
    fg.WindowButtonMotionFcn = '';
    fg.WindowButtonDownFcn = '';
    delete(state.h);
    if state.done
        if isempty(anchor)
            x = state.xs;  y = state.ys;
        else
            x = [anchor(1) state.xs];  y = [anchor(2) state.ys];
        end
    end
end

function moveFcn(fg)
    if ~isvalid(fg), return; end
    s = fg.UserData;
    if isempty(s.p1), return; end
    cp = s.ax.CurrentPoint;
    s.h.XData = [s.p1(1) cp(1,1)];
    s.h.YData = [s.p1(2) cp(1,2)];
    L = norm([cp(1,1) - s.p1(1), cp(1,2) - s.p1(2)]);
    title(s.ax, sprintf('%s   |   length = %.2f cm', s.ttl, L), 'Color', 'w', 'FontSize', 12);
end

function clickFcn(fg)
    if ~isvalid(fg), return; end
    s = fg.UserData;
    cp = s.ax.CurrentPoint;
    px = cp(1,1);  py = cp(1,2);
    xl = s.ax.XLim;  yl = s.ax.YLim;
    if px < xl(1) || px > xl(2) || py < yl(1) || py > yl(2), return; end   % ignore clicks off the image

    if isempty(s.p1)
        s.p1 = [px py];
        s.xs = px;  s.ys = py;
        fg.UserData = s;
        plot(s.ax, px, py, 'w+', 'MarkerSize', 10);
    else
        if isempty(s.xs)
            s.xs = px;  s.ys = py;
        else                         
            s.xs = [s.xs px];  s.ys = [s.ys py];
        end
        s.done = true;
        fg.UserData = s;
        uiresume(fg);
    end
end
