% import and read files
% heart1 - p045_2a 11 months post op
% heart2 - p045_a  15 months post op
% heart3 - p045_3a 21 months post op

heart1 = readDicom3D('/Users/nika/Desktop/BME543/heart-transplant-bme543/p045_2a.dcm');
heart2 = readDicom3D('/Users/nika/Desktop/BME543/heart-transplant-bme543/p045a.dcm');
heart3 = readDicom3D('/Users/nika/Desktop/BME543/heart-transplant-bme543/p045_3a.dcm');

% check sizes and voxel dimensions of the 3D heart images
hearts = {heart1, heart2, heart3};
names  = {'11 mo post-op', '15 mo post-op', '21 mo post-op'};
for k = 1:3
    v = hearts{k};
    fprintf('%s: %d x %d x %d voxels, %d frames | voxel = %.3f x %.3f x %.3f | span = %.1f x %.1f x %.1f\n', ...
        names{k}, v.width, v.height, v.depth, v.NumVolumes, ...
        v.widthspan/v.width, v.heightspan/v.height, v.depthspan/v.depth, ...
        v.widthspan, v.heightspan, v.depthspan);
end

% interactive viewer
heartViewer(hearts, names);


%% ---------------- local functions ----------------

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

    % dataset dropdown
    S.popup = uicontrol(fig, 'Style', 'popupmenu', 'String', names, 'Units', 'normalized', ...
        'Position', [0.82 0.88 0.15 0.05], 'Callback', @(src, ~) switchHeart(fig, src.Value));

    % generate volumes button + results text
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Generate volumes (all frames)', 'Units', 'normalized', ...
        'Position', [0.82 0.80 0.15 0.07], 'Callback', @(~,~) generateVolumes(fig));
    S.resultText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.81 0.30 0.18 0.46], 'BackgroundColor', 'k', 'ForegroundColor', 'w', ...
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
    if isnan(S.EDV(k))
        L{end+1} = 'No volumes yet.';
        L{end+1} = 'Click "Generate volumes".';
    else
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

function generateVolumes(fig)
    S = guidata(fig);
    S.playBtn.Value = 0;  S.playBtn.String = 'Play';
    k  = S.k;
    ds = S.hearts{k};
    c  = round(S.colSlider.Value);          % long-axis slice used for every frame
    F  = ds.NumVolumes;

    % how many frames to measure
    ans_ = inputdlg(sprintf('Measure every Nth frame (1 = all %d frames):', F), 'Frame step', 1, {'1'});
    if isempty(ans_), return; end
    step = round(str2double(ans_{1}));
    if isnan(step) || step < 1, step = 1; end
    frames = 1:step:F;
    vols = nan(size(frames));
    ann  = nan(size(frames));

    % voxel size in cm (spans are in cm)
    dx = ds.widthspan  / ds.width;
    dy = ds.heightspan / ds.height;
    dz = ds.depthspan  / ds.depth;

    n = 1;
    while n <= numel(frames)
        [V, A, status] = measureFrame(ds, c, frames(n), dx, dy, dz, n, numel(frames));
        switch status
            case 'yes',    vols(n) = V;  ann(n) = A;  n = n + 1;
            case 'no'      % redo the same frame
            case 'cancel', break;
        end
    end

    valid = ~isnan(vols);
    if nnz(valid) < 2
        fprintf('Fewer than 2 frames measured, so no ED/ES was computed.\n');
        return;
    end
    fr = frames(valid);  v = vols(valid);

    % ED = max volume, ES = min volume
    [EDV, iED] = max(v);
    [ESV, iES] = min(v);
    S = guidata(fig);
    S.vols{k} = v;  S.vframes{k} = fr;
    S.EDV(k) = EDV;  S.EDframe(k) = fr(iED);
    S.ESV(k) = ESV;  S.ESframe(k) = fr(iES);
    guidata(fig, S);

    EF = (EDV - ESV) / EDV * 100;
    fprintf('\n%s (slice %d)\n  ED = frame %d, EDV = %.1f mL\n  ES = frame %d, ESV = %.1f mL\n  SV = %.1f mL, EF = %.1f %%\n', ...
        S.popup.String{k}, c, fr(iED), EDV, fr(iES), ESV, EDV - ESV, EF);
    if iED == 1 || iED == numel(fr) || iES == 1 || iES == numel(fr)
        fprintf('  Note: ED or ES is at the first/last measured frame. The scan may start or end mid-cycle.\n');
    end

    % volume curve
    figure('Name', 'LV volume curve', 'NumberTitle', 'off');
    plot(fr, v, '-o', 'LineWidth', 1.2); hold on;
    plot(fr(iED), EDV, 'r*', 'MarkerSize', 12);
    plot(fr(iES), ESV, 'b*', 'MarkerSize', 12);
    xlabel('Frame'); ylabel('LV volume (mL)'); grid on;
    title(sprintf('%s | EDV %.1f, ESV %.1f, EF %.1f%%', S.popup.String{k}, EDV, ESV, EF));
    legend('Volume', 'ED (max)', 'ES (min)', 'Location', 'best');

    % annulus diameter over time
    figure('Name', 'Mitral annulus', 'NumberTitle', 'off');
    plot(fr, ann(valid), '-o', 'LineWidth', 1.2); grid on;
    xlabel('Frame'); ylabel('Annulus diameter (cm)');
    title([S.popup.String{k} ' | mitral annulus diameter over the cycle']);

    % jump the viewer to the ED frame
    S.frameSlider.Value = fr(iED);
    guidata(fig, S);
    updateView(fig);
end

function [V, annDiam, status] = measureFrame(ds, c, f, dx, dy, dz, n, nTotal)
    V = nan;  annDiam = nan;  status = 'cancel';
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

    title(ax2, sprintf('Frame %d: long %.2f, short %.2f x %.2f, annulus %.2f cm, volume %.1f mL', ...
        f, Dmaj, s1, s2, annDiam, V), 'Color', 'w', 'FontSize', 12);
    resp = questdlg('Are you satisfied with these clicked points?', 'Confirm', 'Yes', 'No', 'Cancel', 'Yes');
    if isvalid(fg2), close(fg2); end

    switch resp
        case 'Yes',    status = 'yes';
        case 'No',     status = 'no';
        otherwise,     status = 'cancel';
    end
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