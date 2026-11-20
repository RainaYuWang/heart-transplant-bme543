function wall_thickness(ds)
% WALL_THICKNESS 六位置局部壁厚研究工具（无需容积测量）。
% wall_thickness                 选择 DICOM 并重采样
% wall_thickness(heart1)         使用已读取的体数据，避免再次重采样
% MATLAB R2022a+; Image Processing Toolbox required.
% Run help wall_thickness, or use the Chinese instructions shown on startup.

instructions = {
    '六位置局部壁厚：左上、左中、左下、右上、右中、右下。';
    '名称指画面位置，不自动对应解剖壁名或标准心肌节段。';
    '在同一长轴切片第一帧依次画六条线，从心腔穿过心肌到外部。';
    '程序按亮度梯度寻找两侧边界，并分别追踪六条线；逐帧逐位置审查。';
    '测量线应接近当地心肌壁法线；固定切片不能保证同一三维组织。';
    '可单独修正或跳过一个位置；跳过不影响其他五个位置。';
    '选择帧范围和核对长度单位；无帧时间时横轴使用帧号。';
    '不需要测容积。当前不使用 ED/ES、EF 或容积结果。';
    '停止保留已确认结果；输出六条曲线，CSV 和 MAT。';
    '运行 demo_wall_thickness 可查看模拟数据结果布局。'};
uiwait(helpdlg(instructions, '如何使用：六位置局部壁厚'));
if exist('imresize3', 'file') == 0
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
