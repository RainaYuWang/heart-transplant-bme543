function result = local(ds, spacing, frames)
% Six independent wall locations on one long-axis slice, reviewed per frame.
result = [];
opts = inputdlg({'Long-axis slice number (second dimension)','Minimum wall thickness to search for (mm)','Maximum wall thickness to search for (mm)', ...
    'Translation search radius between frames (pixels, 0-30)'}, 'Six-site local thickness settings', 1, ...
    {num2str(round(ds.height/2)),'1','25','6'});
if isempty(opts), return; end
v = cellfun(@str2double,opts);
assert(all(isfinite(v)) && v(1)==fix(v(1)) && v(1)>=1 && v(1)<=ds.height && ...
    v(2)>0 && v(3)>v(2) && v(4)>=0 && v(4)<=30 && v(4)==fix(v(4)), ...
    'wall:Settings','Invalid local measurement settings.');
slice=v(1); limits=v(2:3); radius=v(4);
names={'Left Upper','Left Middle','Left Lower','Right Upper','Right Middle','Right Lower'};
colors=lines(6);
initialImage=double(squeeze(ds.data(:,slice,:,frames(1))).');
assert(all(isfinite(initialImage(:))), 'wall:Data','The image contains NaN or Inf values.');
fig=figure('Name','First frame: draw six search lines','NumberTitle','off','WindowState','maximized');
cleanup=onCleanup(@() closeIfValid(fig));
ax=axes(fig); imagesc(ax,initialImage); axis(ax,'image'); colormap(ax,gray); hold(ax,'on');
initialLines=cell(1,6);
for site=1:6
    title(ax,sprintf('Line %d/6: %s (screen position, not an anatomical wall name)',site,names{site}));
    xy=selectLine(ax, sprintf('%s: draw from the cavity through the wall to the outside; double-click to finish',names{site}),colors(site,:));
    if isempty(xy), return; end
    if any(xy(:,1)<1 | xy(:,1)>size(initialImage,2) | xy(:,2)<1 | xy(:,2)>size(initialImage,1)) || ...
            norm(diff(xy))==0
        uiwait(errordlg('Search lines must be inside the image and have positive length. Please restart measurement.')); return;
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
lastVisited=0;
for idx=1:numel(frames)
    f=frames(idx); lastVisited=idx;
    img=double(squeeze(ds.data(:,slice,:,f)).');
    assert(all(isfinite(img(:))), 'wall:Data','The image contains NaN or Inf values.');
    [frameValues,frameStatuses,frameRecords,nextLines,accepted]=wall.reviewFrame( ...
        img,previous,previousLines,names,colors,f,slice,spacing,limits,radius);
    if ~accepted, break; end
    values(idx,:)=frameValues; statuses(idx,:)=frameStatuses;
    records(idx,:)=frameRecords; previousLines=nextLines;
    previous=img;
end
if ~any(~strcmp(statuses(:),'not_measured')), return; end
result=struct('method','Six-site local wall thickness','measurements',{records(1:lastVisited,:)});
result.table=wall.sixResults(frames(1:lastVisited),values(1:lastVisited,:),statuses(1:lastVisited,:),names);
result.site_names=names; result.site_colors=colors;
result.initial_image=initialImage; result.initial_lines=initialLines;
result.settings=struct('slice',slice,'limits_mm',limits,'search_radius_pixels',radius);
end

function xy=selectLine(ax,prompt,color)
if nargin<2, prompt='Draw from the cavity through the wall to the outside, approximately perpendicular to the wall; double-click to finish'; end
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
