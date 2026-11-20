function result = global3d(ds, spacing, frames)
% 3D Chan-Vese refinement of nested LV masks, followed by surface distance.
% This is a reviewed segmentation prototype, not validated whole-LV anatomy.
result=[];
assert(max(spacing)-min(spacing)<1e-4*max(spacing), ...
    'wall:Isotropic','三维距离要求等间距体素，请先用 resampleDicom 重采样。');
opts=inputdlg({'空间降采样倍数（整数 1-8；2 更省内存）', ...
    '勾画切片间隔（在降采样后的体数据上，整数）', ...
    '每帧三维 activecontour 迭代次数（1-500）', ...
    '两端排除切片数（至少 2，避免截断面伪壁厚）'}, 'B 三维估计设置',1,{'2','5','30','2'});
if isempty(opts), return; end
v=cellfun(@str2double,opts);
assert(all(isfinite(v)) && all(v==fix(v)) && v(1)>=1 && v(1)<=8 && ...
    v(2)>=1 && v(3)>=1 && v(3)<=500 && v(4)>=2,'wall:Settings','三维参数无效。');
factor=v(1); step=v(2); iterations=v(3); cap=v(4); h=spacing(1)*factor;
seedInner=[]; seedOuter=[]; used=[]; medians=[]; lows=[]; highs=[]; counts=[]; statuses={}; records={};
for f=frames
    raw=single(ds.data(:,:,:,f));
    assert(all(isfinite(raw(:))),'wall:Data','影像包含 NaN 或 Inf。');
    if factor>1, raw=imresize3(raw,1/factor); end
    assert(all(size(raw)>2*cap+2),'wall:Size','降采样后的数据过小，请减小倍数。');
    image=mat2gray(imgaussfilt3(raw,0.7));
    accepted=false; stop=false;
    while ~accepted
        if isempty(seedInner)
            [seedInner,seedOuter]=wall.seedMasks(raw,step);
            if isempty(seedInner), stop=true; break; end
        end
        z=find(squeeze(any(any(seedOuter,1),2)));
        fprintf('三维帧 %d：运行 %d 次迭代，体素 %.3f mm。\n',f,iterations,h); drawnow;
        inner=activecontour(image,seedInner,iterations,'Chan-Vese');
        outer=activecontour(image,seedOuter,iterations,'Chan-Vese');
        % Preserve user-selected axial coverage; its artificial end caps are excluded.
        inner(:,:,[1:z(1)-1 z(end)+1:size(raw,3)])=false;
        outer(:,:,[1:z(1)-1 z(end)+1:size(raw,3)])=false;
        [valid,reason]=checkMasks(inner,outer);
        distanceMap=nan(size(raw),'single'); values=[];
        if valid
            try
                [distanceMap,values]=wall.surfaceDistance(inner,outer,h,cap);
                if isempty(values) || any(values<=0)
                    valid=false; reason='内外表面接触或没有有效距离';
                end
            catch err
                valid=false; reason=err.message;
            end
        end
        if valid
            summary=sprintf('中位数 %.2f mm；范围 %.2f–%.2f mm',median(values),min(values),max(values));
        else
            summary=['无效分割：' reason];
        end
        action=wall.review3d(raw,inner,outer,distanceMap,f,summary);
        if strcmp(action,'重新勾画')
            [seedInner,seedOuter]=wall.seedMasks(raw,step);
            if isempty(seedInner), stop=true; break; end
            choice=questdlg('直接审查勾画插值得到的掩膜，还是再次自动调整？', ...
                '人工修正后','审查人工掩膜','自动调整','审查人工掩膜');
            if ~strcmp(choice,'审查人工掩膜'), continue; end
            inner=seedInner; outer=seedOuter;
            [valid,reason]=checkMasks(inner,outer);
            if valid
                try
                    [distanceMap,values]=wall.surfaceDistance(inner,outer,h,cap);
                    valid=~isempty(values) && all(values>0);
                catch err
                    valid=false; reason=err.message;
                end
            end
            if ~valid
                uiwait(errordlg(['人工掩膜仍无效：' reason])); continue;
            end
            action=wall.review3d(raw,inner,outer,distanceMap,f, ...
                sprintf('人工掩膜中位数 %.2f mm',median(values)));
            status='reviewed_manual_masks';
        else
            status='reviewed_auto_masks';
        end
        if strcmp(action,'接受')
            if ~valid, uiwait(errordlg(['分割无效，请重画或跳过：' reason])); continue; end
            seedInner=inner; seedOuter=outer;
            used(end+1,1)=f; medians(end+1,1)=median(values);
            sorted=sort(values); n=numel(values);
            lows(end+1,1)=sorted(max(1,ceil(.1*n))); highs(end+1,1)=sorted(max(1,ceil(.9*n)));
            counts(end+1,1)=n; statuses{end+1,1}=status;
            records{end+1,1}=struct('frame',f,'inner_mask',inner,'outer_mask',outer, ...
                'surface_distance_mm',distanceMap,'voxel_mm',h);
            accepted=true;
        elseif strcmp(action,'重新勾画')
            seedInner=[]; seedOuter=[];
        elseif strcmp(action,'跳过/停止')
            choice=questdlg('跳过会保留缺失值；下一帧重新初始化。','跳过或停止', ...
                '跳过','停止','停止');
            if ~strcmp(choice,'跳过'), stop=true; break; end
            used(end+1,1)=f; medians(end+1,1)=nan; lows(end+1,1)=nan; highs(end+1,1)=nan;
            counts(end+1,1)=0; statuses{end+1,1}='skipped'; records{end+1,1}=[];
            seedInner=[]; seedOuter=[]; accepted=true;
        else
            stop=true; break;
        end
    end
    if stop, break; end
end
if isempty(used), return; end
result=struct('method','B: median 3D inner-to-outer surface distance','measurements',{records});
result.table=table(used,medians,lows,highs,counts,statuses,'VariableNames', ...
    {'Frame','Thickness_mm','P10_mm','P90_mm','SurfaceVoxelCount','Status'});
result.settings=struct('downsample_factor',factor,'voxel_mm',h,'contour_step',step, ...
    'iterations',iterations,'excluded_cap_slices',cap);
end

function [valid,reason]=checkMasks(inner,outer)
valid=false; reason='';
if ~any(inner(:)) || ~any(outer(:)), reason='空掩膜'; return; end
if any(inner(:) & ~outer(:)), reason='内外轮廓交叉'; return; end
a=bwconncomp(inner,6); b=bwconncomp(outer,6);
if a.NumObjects~=1 || b.NumObjects~=1, reason='掩膜不是一个连通区域'; return; end
edges=outer([1 end],:,:); sides=outer(:,[1 end],:);
if any(edges(:)) || any(sides(:)), reason='外壁触及体数据侧边，可能被截断或发生泄漏'; return; end
valid=true;
end
