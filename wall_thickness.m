function wall_thickness(ds)
% WALL_THICKNESS 心肌壁厚研究工具：局部线测量 / 三维内外表面距离。
% wall_thickness                 选择 DICOM 并重采样
% wall_thickness(heart1)         使用已读取的体数据，避免再次重采样
% MATLAB R2022a+; Image Processing Toolbox required.
% Run help wall_thickness, or use the Chinese instructions shown on startup.

instructions = {
    '心肌壁厚研究工具（真实影像精度尚未验证）';
    '版本 A：局部壁厚。选择长轴切片，画从心腔穿过心肌到外部的线。';
    '程序按亮度梯度寻找两侧边界，并作二维平移匹配辅助定位；每帧需审查。';
    '测量线应接近心肌壁法线。固定切片无法保证追踪同一三维组织。';
    '版本 B：三维壁厚估计。在多个深度切片勾画内外轮廓，自动调整三维分割。';
    '结果为内表面到外表面的最短距离；不等同于法线壁厚或标准心肌节段测量。';
    '须检查整个分割；瓣口附近和截断面的距离不可靠，程序排除两端切片。';
    '两个版本均需选择帧范围和核对长度单位；无帧时间时横轴仅显示帧号。';
    '关闭选择窗口或点取消会停止；已经确认的数据会保留，可另存 CSV 和 MAT。';
    '版本 A 保存边界坐标；版本 B 保存三维掩膜和距离图，便于复核。'};
uiwait(helpdlg(instructions, '如何使用：两个版本说明'));
if exist('imresize3', 'file') == 0 || exist('activecontour', 'file') == 0
    error('wall:Toolbox', '需要 Image Processing Toolbox。');
end
if nargin == 0
    [file, folder] = uigetfile('*.dcm', '选择一份心脏 DICOM');
    if isequal(file, 0), return; end
    ds = resampleDicom(fullfile(folder, file));
end
required = {'data','width','height','depth','NumVolumes','widthspan','heightspan','depthspan'};
assert(isstruct(ds) && isscalar(ds) && all(isfield(ds, required)), ...
    'wall:Data', '输入必须是 resampleDicom 返回的体数据结构。');
dims = [ds.width ds.height ds.depth ds.NumVolumes];
assert(numel(dims) == 4 && all(isfinite(dims)) && all(dims == fix(dims)) && ...
    all(dims(1:3) >= 3) && dims(4) >= 1 && isnumeric(ds.data) && isreal(ds.data) && ...
    ndims(ds.data) <= 4 && isequal(dims, ...
    [size(ds.data,1) size(ds.data,2) size(ds.data,3) size(ds.data,4)]), ...
    'wall:Dimensions', '体数据尺寸不正确；请检查是否使用了修复后的 resampleDicom。');
spacing = [ds.widthspan ds.heightspan ds.depthspan] ./ dims(1:3);
assert(all(isfinite(spacing) & spacing > 0), 'wall:Spacing', '体素尺寸必须为有限正数。');
unit = questdlg('请核对 DICOM 原始长度单位（程序不能自动确认）：', ...
    '单位确认', 'cm', 'mm', '取消', '取消');
if strcmp(unit, 'cm'), spacing = spacing * 10;
elseif ~strcmp(unit, 'mm'), return;
end
settings = inputdlg({'起始帧（包含）','结束帧（包含）', ...
    '帧间隔 ms（只在已知且恒定时填写；未知留空）'}, '帧范围', 1, ...
    {'1',num2str(ds.NumVolumes),''});
if isempty(settings), return; end
first = str2double(settings{1}); last = str2double(settings{2});
assert(all(isfinite([first last])) && first == fix(first) && last == fix(last) && ...
    first >= 1 && last <= ds.NumVolumes && first <= last, 'wall:Range', '帧范围无效。');
dt = nan;
if ~isempty(strtrim(settings{3}))
    dt = str2double(settings{3}) / 1000;
    assert(isfinite(dt) && dt > 0, 'wall:Time', '帧间隔必须为正数或留空。');
end
mode = questdlg('请选择本次测量方式：', '壁厚测量版本', ...
    'A 局部壁厚', 'B 三维壁厚', '取消', 'A 局部壁厚');
if strcmp(mode, 'A 局部壁厚')
    result = wall.local(ds, spacing, first:last);
elseif strcmp(mode, 'B 三维壁厚')
    result = wall.global3d(ds, spacing, first:last);
else
    return;
end
if isempty(result), return; end
result.spacing_mm = spacing;
result.frame_interval_s = dt;
result.source_dimensions = dims;
if isfinite(dt)
    result.table.Time_s = (result.table.Frame - first) * dt;
    x = result.table.Time_s; xlabelText = 'Time from selected first frame (s)';
else
    x = result.table.Frame; xlabelText = 'Frame';
end
figure('Name', ['Wall thickness: ' result.method], 'NumberTitle', 'off');
plot(x, result.table.Thickness_mm, '-o'); grid on;
xlabel(xlabelText); ylabel('Thickness estimate (mm)'); title(result.method, 'Interpreter','none');
disp(result.table);
choice = questdlg('保存结果 CSV 和可复核的 MAT 数据？', '保存结果', '保存', '取消', '保存');
if strcmp(choice, '保存')
    [file, folder] = uiputfile('*.mat', '保存壁厚结果（同时生成同名 CSV）', 'wall_results.mat');
    if ~isequal(file, 0)
        [~, stem] = fileparts(file);
        csvPath = fullfile(folder, [stem '.csv']);
        matPath = fullfile(folder, [stem '.mat']);
        if isfile(csvPath) || isfile(matPath)
            answer = questdlg('同名 MAT 或 CSV 已存在。替换这两个文件？', ...
                '确认覆盖', '替换', '取消', '取消');
            if ~strcmp(answer, '替换'), return; end
        end
        save(matPath, 'result', '-v7.3');
        writetable(result.table, csvPath);
    end
end
end
