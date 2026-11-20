function action = review3d(volume, inner, outer, distanceMap, frame, summary)
% Scroll through ALL depth slices and inspect the 3D surfaces before accepting.
fig=figure('Name',sprintf('B 三维审查 | 帧 %d',frame),'NumberTitle','off');
cleaner=onCleanup(@() closeIfValid(fig));
ax=subplot(1,2,1,'Parent',fig); surfAx=subplot(1,2,2,'Parent',fig);
z=round(size(volume,3)/2); showSlice(ax,volume,inner,outer,z);
uicontrol(fig,'Style','slider','Units','normalized','Position',[.08 .03 .38 .04], ...
    'Min',1,'Max',size(volume,3),'Value',z,'SliderStep',[1 1]/max(1,size(volume,3)-1), ...
    'Callback',@(s,~) showSlice(ax,volume,inner,outer,round(s.Value)));
% Vertices are displayed in voxel coordinates; distance colors are in mm.
mesh=isosurface(single(inner),0.5);
if ~isempty(mesh.vertices)
    % Isosurface vertices lie between voxels. Extend boundary colors outward
    % so nearest sampling does not turn alternate faces into NaN patches.
    [~,nearestInner]=bwdist(inner);
    displayMap=distanceMap(nearestInner);
    colors=interp3(displayMap,mesh.vertices(:,1),mesh.vertices(:,2),mesh.vertices(:,3),'nearest');
    patch(surfAx,mesh,'FaceVertexCData',colors,'FaceColor','interp','EdgeColor','none');
    hold(surfAx,'on');
end
meshOuter=isosurface(single(outer),0.5);
if ~isempty(meshOuter.vertices)
    patch(surfAx,meshOuter,'FaceColor',[.8 .3 .7],'FaceAlpha',.15,'EdgeColor','none');
end
axis(surfAx,'equal'); view(surfAx,3); grid(surfAx,'on'); colorbar(surfAx);
title(surfAx,{'内表面距离颜色（mm），外表面透明',summary},'Interpreter','none');
sgtitle(fig,{'请滚动全部切片并检查内外边界，再接受或重画。', ...
    '青色=内壁，洋红=外壁；检查右心室误选、瓣口及周围组织泄漏。'});
% Use nonmodal in-figure controls so the slider and axes remain interactive.
fig.UserData='';
labels={'接受','重新勾画','跳过/停止'};
for k=1:3
    label=labels{k};
    uicontrol(fig,'Style','pushbutton','String',label,'Units','normalized', ...
        'Position',[.50+.16*(k-1) .02 .15 .05], ...
        'Callback',@(~,~) finish(fig,label));
end
uiwait(fig);
action='';
if isgraphics(fig), action=fig.UserData; end
end

function finish(fig,label)
fig.UserData=label; uiresume(fig);
end

function showSlice(ax,volume,inner,outer,z)
imagesc(ax,volume(:,:,z).'); axis(ax,'image'); colormap(ax,gray); hold(ax,'on');
contour(ax,double(inner(:,:,z).'),[.5 .5],'c','LineWidth',1.2);
contour(ax,double(outer(:,:,z).'),[.5 .5],'m','LineWidth',1.2);
hold(ax,'off'); title(ax,sprintf('深度 %d（检查所有切片）',z));
end

function closeIfValid(fig)
if isgraphics(fig), close(fig); end
end
