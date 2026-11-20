function [inner,outer] = seedMasks(volume, step)
% Contours at several depths, interpolated using signed distance in pixels.
inner=[]; outer=[];
fig=figure('Name','B 三维初始化：预览深度','NumberTitle','off');
cleaner=onCleanup(@() closeIfValid(fig));
ax=axes(fig); z=round(size(volume,3)/2);
imagesc(ax,volume(:,:,z).'); axis(ax,'image'); colormap(ax,gray);
slider=uicontrol(fig,'Style','slider','Units','normalized','Position',[.15 .01 .6 .04], ...
    'Min',1,'Max',size(volume,3),'Value',z,'SliderStep',[1 1]/max(1,size(volume,3)-1), ...
    'Callback',@(s,~) showSlice(ax,volume,round(s.Value)));
title(ax,sprintf('深度 %d：滑块查看心室覆盖范围',z));
next=uicontrol(fig,'Style','pushbutton','String','范围已查看，下一步', ...
    'Units','normalized','Position',[.76 .01 .23 .05], ...
    'Callback',@(~,~) uiresume(fig));
uiwait(fig);
if ~isgraphics(fig), return; end
delete(next);
opts=inputdlg({'第一张勾画深度（建议从心尖附近开始）','最后一张勾画深度（瓣口以下）'}, ...
    '三维分析范围：两端将被排除',1,{'1',num2str(size(volume,3))});
if isempty(opts), return; end
range=cellfun(@str2double,opts);
assert(all(isfinite(range)) && all(range==fix(range)) && range(1)>=1 && ...
    range(2)<=size(volume,3) && diff(range)>=4,'wall:Range','至少需要 5 个深度切片。');
depths=unique([range(1):step:range(2),range(2)]);
im=false(size(volume)); om=im;
delete(slider);
for k=1:numel(depths)
    z=depths(k);
    while true
        showSlice(ax,volume,z);
        title(ax,sprintf('深度 %d：沿心腔内壁勾画闭合多边形，双击完成',z));
        a=drawpolygon(ax,'Color','c');
        try
            wait(a);
        catch err
            if ~isgraphics(fig), return; end
            rethrow(err);
        end
        if ~isvalid(a), return; end
        inside=createMask(a).';
        title(ax,sprintf('深度 %d：沿心肌外壁勾画，包含整个内轮廓',z));
        b=drawpolygon(ax,'Color','m');
        try
            wait(b);
        catch err
            if ~isgraphics(fig), return; end
            rethrow(err);
        end
        if ~isvalid(b), return; end
        outside=createMask(b).';
        if any(inside(:)) && any(outside(:)) && ~any(inside(:) & ~outside(:)) && ...
                any(outside(:) & ~inside(:))
            im(:,:,z)=inside; om(:,:,z)=outside; break;
        end
        uiwait(errordlg('内外轮廓必须非空，且外轮廓应包含内轮廓并留有心肌区域。请重画。'));
    end
end
inner=interpolateMasks(im,depths); outer=interpolateMasks(om,depths);
if any(inner(:) & ~outer(:))
    inner=[]; outer=[];
    error('wall:Interpolation','轮廓插值发生交叉，请减小勾画切片间隔。');
end
end

function masks=interpolateMasks(masks,depths)
for k=1:numel(depths)-1
    a=depths(k); b=depths(k+1);
    da=bwdist(~masks(:,:,a))-bwdist(masks(:,:,a));
    db=bwdist(~masks(:,:,b))-bwdist(masks(:,:,b));
    for z=a+1:b-1
        t=(z-a)/(b-a); masks(:,:,z)=((1-t)*da+t*db)>0;
    end
end
end

function showSlice(ax,vol,z)
imagesc(ax,vol(:,:,z).'); axis(ax,'image'); colormap(ax,gray);
title(ax,sprintf('深度 %d',z));
end

function closeIfValid(fig)
if isgraphics(fig), close(fig); end
end
