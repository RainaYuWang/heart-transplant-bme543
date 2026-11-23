function [measurement,status] = reviewContours(img,spacing,frame,previous,settings,climits)
% Maximized per-frame manual contours, with immutable previous-frame guides.
measurement=[]; status='not_measured'; rois=cell(1,2); listeners=cell(1,2);
names={'Inner contour','Outer contour'}; colors={[0 .9 1],[1 .55 .1]};
busy=false; finished=false; overlays=gobjects(0);
range=settings.frame_range;
progress=sprintf('Frame %d | %d of %d | Range %d-%d', ...
    frame,frame-range(1)+1,range(2)-range(1)+1,range(1),range(2));
if frame==range(2)
    acceptLabel='Accept last frame / Show results';
    skipLabel='Skip last frame / Show results';
else
    acceptLabel=sprintf('Accept / Next frame %d',frame+1);
    skipLabel=sprintf('Skip / Next frame %d',frame+1);
end
fig=figure('Name',['Contour wall thickness | ' progress],'NumberTitle','off', ...
    'WindowState','maximized','Color',[.12 .12 .12],'Tag','wallContourReview', ...
    'CloseRequestFcn',@closeReview);
cleanup=onCleanup(@() closeIfValid(fig));
ax=axes(fig,'Position',[.035 .08 .69 .85]);
imagesc(ax,img,climits); axis(ax,'image'); colormap(ax,gray); hold(ax,'on');
daspect(ax,[1/spacing(1) 1/spacing(2) 1]); ax.XColor='w'; ax.YColor='w';
if ~isempty(previous)
    p=[previous.inner_pixel;previous.inner_pixel(1,:)];
    plot(ax,p(:,1),p(:,2),':','Color',[.6 .65 .65],'LineWidth',1.2,'HitTest','off');
    p=[previous.outer_pixel;previous.outer_pixel(1,:)];
    plot(ax,p(:,1),p(:,2),'--','Color',[.65 .6 .55],'LineWidth',1.2,'HitTest','off');
    reference=sprintf('Faint guides: last accepted frame %d (not tracked)',previous.frame);
else
    reference='No previous accepted contours';
end
title(ax,{progress,settings.region_label,reference},'Color','w','Interpreter','none');
info=uicontrol(fig,'Style','text','Units','normalized','Position',[.75 .72 .23 .23], ...
    'HorizontalAlignment','left','BackgroundColor',[.12 .12 .12],'ForegroundColor','w','FontSize',11, ...
    'String',{'Draw the endocardial (inner) and epicardial (outer) contours.'; ...
    'Click vertices; double-click to finish. Drag vertices to correct.'; ...
    'Exclude papillary muscles from the myocardial wall contour.'; ...
    'Cyan: current inner. Orange: current outer. Gray: previous accepted frame.'; ...
    'One acceptance per frame. No automatic boundary detection.'});
summary=uicontrol(fig,'Style','text','Units','normalized','Position',[.75 .52 .23 .19], ...
    'HorizontalAlignment','left','BackgroundColor',[.12 .12 .12],'ForegroundColor',[1 .85 .25],'FontSize',12);
labels={'Draw / replace inner contour','Draw / replace outer contour','Use previous contours as editable copies', ...
    'Preview thickness',acceptLabel,skipLabel,'Stop (keep earlier frames)'};
callbacks={@(~,~) drawContour(1),@(~,~) drawContour(2),@copyPrevious,@preview,@accept,@skip,@stop};
buttons=gobjects(7,1);
for j=1:7
    buttons(j)=uicontrol(fig,'Style','pushbutton','String',labels{j},'Units','normalized', ...
        'Position',[.75 .465-(j-1)*.055 .23 .045],'Callback',callbacks{j}, ...
        'Tag',sprintf('wallContourAction%d',j),'BusyAction','cancel');
    if j>=4, buttons(j).Interruptible='off'; end
end
if isempty(previous), buttons(3).Enable='off'; end
uicontrol(fig,'Style','text','Units','normalized','Position',[.75 .015 .23 .09], ...
    'HorizontalAlignment','left','BackgroundColor',[.12 .12 .12],'ForegroundColor','w', ...
    'String',sprintf(['Inner arc: %d equally spaced samples.\nShortest distance to outer contour segments.\n' ...
    'Source spacing assumes cm; 10 mm = 1 cm.'],settings.sample_count));
summary.String='Draw both contours, then preview or accept. The region settings stay fixed across frames.';
% A UI resume is not itself a stop decision. ROI/UI activity may resume a wait;
% stay on this frame until one of our explicit terminal callbacks completes.
while isgraphics(fig) && ~finished
    uiwait(fig);
end
% Nested callbacks retain the shared workspace. Explicitly destroy this
% window before the caller opens the next frame, rather than relying on scope exit.
closeIfValid(fig);

    function invalidate(varargin)
        if finished || ~isgraphics(fig), return; end
        measurement=[];
        delete(overlays(isgraphics(overlays))); overlays=gobjects(0);
        summary.String='Contours changed. Preview or accept to recompute thickness.';
    end
    function setBusy(tf)
        busy=tf;
        if tf, set(buttons,'Enable','off'); else, set(buttons,'Enable','on'); end
        if isempty(previous), buttons(3).Enable='off'; end
    end
    function install(k,p)
        if ~isempty(listeners{k}), delete(listeners{k}); end
        if ~isempty(rois{k}) && isvalid(rois{k}), delete(rois{k}); end
        rois{k}=drawpolygon(ax,'Position',p,'Color',colors{k},'FaceAlpha',0, ...
            'Label',names{k},'Deletable',false,'DrawingArea',[1 1 size(img,2)-1 size(img,1)-1]);
        listeners{k}=addlistener(rois{k},'ROIMoved',@invalidate);
    end
    function drawContour(k)
        if busy || finished, return; end
        setBusy(true); draft=[];
        summary.String=['Draw ' lower(names{k}) ': click vertices; double-click to finish. Esc cancels.'];
        try
            draft=drawpolygon(ax,'Color',colors{k},'FaceAlpha',0, ...
                'DrawingArea',[1 1 size(img,2)-1 size(img,1)-1]);
            % drawpolygon itself waits for the initial drawing to finish.
            if isgraphics(fig) && isvalid(draft) && size(draft.Position,1)>=3
                p=draft.Position; delete(draft); install(k,p); invalidate();
            end
        catch err
            if isgraphics(fig), summary.String=err.message; end
        end
        if ~isempty(draft) && isvalid(draft), delete(draft); end
        if isgraphics(fig), setBusy(false); end
    end
    function copyPrevious(varargin)
        if busy || finished || isempty(previous), return; end
        install(1,previous.inner_pixel); install(2,previous.outer_pixel); invalidate();
        summary.String='Copied contours are not tracked. Adjust them to the current image before accepting.';
    end
    function ok=compute()
        ok=false; invalidate();
        for k=1:2
            if isempty(rois{k}) || ~isvalid(rois{k})
                summary.String='Draw both the inner and outer contours first.'; return;
            end
            p=rois{k}.Position;
            if any(p(:,1)<1 | p(:,1)>size(img,2) | p(:,2)<1 | p(:,2)>size(img,1))
                summary.String='All contour vertices must be inside the image.'; return;
            end
        end
        try
            measurement=wall.contourThickness(rois{1}.Position,rois{2}.Position,spacing, ...
                settings.sample_count,settings.sector_deg);
        catch err
            summary.String=err.message; return;
        end
        measurement.frame=frame;
        p=measurement.sample_pixel(measurement.selected,:);
        q=measurement.nearest_outer_pixel(measurement.selected,:);
        overlays=plot(ax,[p(:,1) q(:,1)]',[p(:,2) q(:,2)]', ...
            'Color',[.45 .9 .35],'LineWidth',.6,'HitTest','off');
        if settings.sector_deg(2)<360
            angles=settings.sector_deg(1)+[0 settings.sector_deg(2)];
            center=measurement.center_pixel;
            radius=norm([size(img,2) size(img,1)].*spacing);
            ends=center+radius*[cosd(angles(:)) -sind(angles(:))]./spacing;
            rays=plot(ax,[repmat(center(1),2,1) ends(:,1)]', ...
                [repmat(center(2),2,1) ends(:,2)]','y--','HitTest','off');
            overlays=[overlays;rays];
            xlim(ax,[.5 size(img,2)+.5]); ylim(ax,[.5 size(img,1)+.5]);
        end
        summary.String={sprintf('Regional mean: %.2f mm = %.3f cm',measurement.mean_mm,measurement.mean_mm/10); ...
            sprintf('%d selected samples of %d',measurement.sample_count,settings.sample_count); ...
            sprintf('Inner arc spacing: %.3f mm',measurement.arc_step_mm); ...
            'Green lines: selected local distances.'; 'Review the contours and region, then accept.'};
        ok=true;
    end
    function preview(varargin)
        if ~busy && ~finished, compute(); end
    end
    function accept(varargin)
        if ~busy && ~finished && compute(), finish('accepted'); end
    end
    function skip(varargin)
        if ~busy && ~finished, measurement=[]; finish('skipped'); end
    end
    function stop(varargin)
        if ~busy && ~finished, measurement=[]; finish('not_measured'); end
    end
    function finish(decision)
        status=decision; finished=true;
        set(buttons,'Enable','off');
        uiresume(fig);
    end
    function closeReview(varargin)
        % Closing during drawing also cancels the draft ROI interaction.
        if ~finished, measurement=[]; status='not_measured'; finished=true; end
        delete(fig);
    end
end

function closeIfValid(fig)
if isgraphics(fig), delete(fig); end
end
