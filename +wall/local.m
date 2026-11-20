function result = local(ds, spacing, frames)
% Six independent wall locations on one long-axis slice, reviewed per frame.
result = [];
opts = inputdlg({'长轴切片编号（第二维）','允许的最小壁厚 mm','允许的最大壁厚 mm', ...
    '相邻帧平移搜索半径（像素，0-30）'}, '六位置局部壁厚设置', 1, ...
    {num2str(round(ds.height/2)),'1','25','6'});
if isempty(opts), return; end
v = cellfun(@str2double,opts);
assert(all(isfinite(v)) && v(1)==fix(v(1)) && v(1)>=1 && v(1)<=ds.height && ...
    v(2)>0 && v(3)>v(2) && v(4)>=0 && v(4)<=30 && v(4)==fix(v(4)), ...
    'wall:Settings','局部测量参数无效。');
slice=v(1); limits=v(2:3); radius=v(4);
names={'左上','左中','左下','右上','右中','右下'};
colors=lines(6);
initialImage=double(squeeze(ds.data(:,slice,:,frames(1))).');
assert(all(isfinite(initialImage(:))), 'wall:Data','影像含有 NaN 或 Inf。');
fig=figure('Name','第一帧：依次画六条搜索线','NumberTitle','off');
cleanup=onCleanup(@() closeIfValid(fig));
ax=axes(fig); imagesc(ax,initialImage); axis(ax,'image'); colormap(ax,gray); hold(ax,'on');
initialLines=cell(1,6);
for site=1:6
    title(ax,sprintf('第 %d/6 条：%s（画面位置，不是解剖壁名）',site,names{site}));
    xy=selectLine(ax, sprintf('%s：从心腔穿过心肌到外部，双击完成',names{site}),colors(site,:));
    if isempty(xy), return; end
    if any(xy(:,1)<1 | xy(:,1)>size(initialImage,2) | xy(:,2)<1 | xy(:,2)>size(initialImage,1)) || ...
            norm(diff(xy))==0
        uiwait(errordlg('搜索线必须在图像内且长度大于零，请重新启动测量。')); return;
    end
    initialLines{site}=xy;
    plot(ax,xy(:,1),xy(:,2),'--o','Color',colors(site,:));
    text(ax,xy(2,1),xy(2,2),names{site},'Color',colors(site,:),'BackgroundColor','k');
end
clear cleanup;
previous=[]; previousLines=initialLines;
values=nan(numel(frames),6);
statuses=repmat({'not_measured'},numel(frames),6);
records=cell(numel(frames),6);
lastVisited=0; stop=false;
for idx=1:numel(frames)
    f=frames(idx); lastVisited=idx;
    img=double(squeeze(ds.data(:,slice,:,f)).');
    assert(all(isfinite(img(:))), 'wall:Data','影像含有 NaN 或 Inf。');
    for site=1:6
        [value,outcome,record,nextLine]=measureSite(img,previous,previousLines{site}, ...
            previousLines,site,names{site},colors(site,:),f,slice,spacing,limits,radius);
        if strcmp(outcome,'stop'), stop=true; break; end
        values(idx,site)=value; statuses{idx,site}=outcome; records{idx,site}=record;
        previousLines{site}=nextLine;
    end
    if stop, break; end
    previous=img;
end
if ~any(~strcmp(statuses(:),'not_measured')), return; end
result=struct('method','Six-site local wall thickness','measurements',{records(1:lastVisited,:)});
result.table=wall.sixResults(frames(1:lastVisited),values(1:lastVisited,:),statuses(1:lastVisited,:),names);
result.site_names=names; result.site_colors=colors;
result.initial_image=initialImage; result.initial_lines=initialLines;
result.settings=struct('slice',slice,'limits_mm',limits,'search_radius_pixels',radius);
end

function [thickness,outcome,record,nextLine]=measureSite(img,previous,previousLine,references,site,name,color,f,slice,spacing,limits,radius)
thickness=nan; outcome='stop'; record=[]; nextLine=[];
fig=figure('Name',sprintf('六位置壁厚 | %s | 帧 %d',name,f),'NumberTitle','off');
cleanup=onCleanup(@() closeIfValid(fig));
ax=subplot(1,2,1,'Parent',fig); imagesc(ax,img); axis(ax,'image'); colormap(ax,gray); hold(ax,'on');
profileAx=subplot(1,2,2,'Parent',fig);
    corrected=false; trackingScore=nan;
    if isempty(previousLine)
        lineXY=selectLine(ax);
    elseif isempty(previous)
        lineXY=previousLine;
    else
        [lineXY,trackingScore]=wall.trackLine(previous,img,previousLine,radius);
    end
    if isempty(lineXY), return; end
    stop=false;
    while isgraphics(fig)
        cla(ax); imagesc(ax,img); axis(ax,'image'); hold(ax,'on');
        drawReferences(ax, references, site);
        plot(ax,lineXY(:,1),lineXY(:,2),'--','Color',color);
        [points,strength,p]=wall.profileEdges(img,lineXY,spacing([1 3]),limits);
        cla(profileAx); plot(profileAx,p.distance,p.intensity); grid(profileAx,'on');
        xlabel(profileAx,'Distance along line (mm)'); ylabel(profileAx,'Brightness');
        if all(isfinite(points(:)))
            plot(ax,points(:,1),points(:,2),'-o','Color',color,'LineWidth',2);
            thickness=norm(diff(points,1,1).*spacing([1 3]));
            edgeDist=sqrt(sum(((points-lineXY(1,:)).*spacing([1 3])).^2,2));
            xline(profileAx,edgeDist(1),'c--'); xline(profileAx,edgeDist(2),'c--');
        else
            thickness=nan;
        end
        title(ax,sprintf('%s | 帧 %d | %.2f mm | 匹配 %.2f\n实线：边界；虚线：搜索线',name,f,thickness,trackingScore));
        action=questdlg('检查两侧边界。无有效边界时请选择修正或跳过。', ...
            '逐帧审查','接受','修正/重画','跳过/停止','修正/重画');
        if isempty(action), stop=true; break; end
        if strcmp(action,'修正/重画')
            method=questdlg('重新定位搜索线，或手动指定内外边界？', ...
                '修正方式','重画搜索线','手动边界','取消','重画搜索线');
            if strcmp(method,'重画搜索线')
                lineXY=selectLine(ax); corrected=true;
                if isempty(lineXY), stop=true; break; end
                continue;
            elseif strcmp(method,'手动边界')
                title(ax,'画线：起点为内壁，终点为外壁；双击完成');
                roi=drawline(ax,'Color','m');
                try
                    wait(roi);
                catch err
                    if ~isgraphics(fig), stop=true; break; end
                    rethrow(err);
                end
                if ~isvalid(roi) || ~isgraphics(fig), stop=true; break; end
                points=roi.Position;
                if any(points(:,1)<1 | points(:,1)>size(img,2) | points(:,2)<1 | points(:,2)>size(img,1))
                    uiwait(errordlg('端点必须在影像内。')); continue;
                end
                thickness=norm(diff(points,1,1).*spacing([1 3]));
                if ~isfinite(thickness) || thickness<=0, continue; end
                confirm=questdlg(sprintf('接受手动壁厚 %.2f mm？',thickness),'手动结果','接受','重试','重试');
                if ~strcmp(confirm,'接受'), continue; end
                corrected=true;
                % Extend manually corrected segment for the next edge search.
                delta=diff(points,1,1);
                lineXY=[points(1,:)-0.5*delta; points(2,:)+0.5*delta];
                lineXY(:,1)=max(1,min(size(img,2),lineXY(:,1)));
                lineXY(:,2)=max(1,min(size(img,1),lineXY(:,2)));
            else
                continue;
            end
        elseif strcmp(action,'跳过/停止')
            choice=questdlg('仅跳过当前帧的这个位置；其他位置继续，下一帧重新定位。', ...
                '跳过或停止','跳过','停止','停止');
            if ~strcmp(choice,'跳过'), stop=true; break; end
            thickness=nan; points=nan(2,2); previousLine=[];
        elseif ~isfinite(thickness)
            uiwait(errordlg('没有检测到有效的亮壁带，请修正或跳过。')); continue;
        end
        if isfinite(thickness)
            previous=img; previousLine=lineXY;
            if corrected, status='reviewed_corrected'; else, status='reviewed_auto'; end
        else
            status='skipped';
        end
        record=struct('frame',f,'site',site,'slice',slice,'points_pixel',points, ...
            'search_line_pixel',lineXY,'tracking_correlation',trackingScore,'edge_strength',strength);
        outcome=status;
        nextLine=previousLine;
        return;
    end
end

function drawReferences(ax,references,site)
names={'左上','左中','左下','右上','右中','右下'};
for k=1:6
    if k==site || isempty(references{k}), continue; end
    xy=references{k};
    plot(ax,xy(:,1),xy(:,2),':','Color',[.55 .55 .55],'HitTest','off');
    text(ax,xy(2,1),xy(2,2),names{k},'Color',[.7 .7 .7], ...
        'BackgroundColor','k','HitTest','off');
end
end

function xy=selectLine(ax,prompt,color)
if nargin<2, prompt='从心腔穿过心肌画到外部（尽量垂直心肌壁），双击完成'; end
if nargin<3, color='y'; end
title(ax,prompt);
xy=[];
fig=ancestor(ax,'figure');
roi=drawline(ax,'Color',color);
try
    wait(roi);
catch err
    if ~isgraphics(fig), return; end
    rethrow(err);
end
if isvalid(roi), xy=roi.Position; delete(roi); end
end

function closeIfValid(fig)
if isgraphics(fig), close(fig); end
end
