function [values,statuses,records,nextLines,accepted] = reviewFrame(img,previous,searchLines,names,colors,frame,slice,spacing,limits,radius)
% Nonmodal, maximized review of all six sites. One acceptance per frame.
values=nan(1,6); statuses=repmat({'not_measured'},1,6); records=cell(1,6);
nextLines=searchLines; accepted=false; selected=1; busy=false;
points=cell(1,6); scores=nan(1,6); strengths=nan(1,6);
states=repmat({'needs_review'},1,6); rois=cell(1,6); listeners=cell(1,6);
fig=figure('Name',sprintf('Six-site wall review | Frame %d',frame), ...
    'NumberTitle','off','WindowState','maximized','Color',[.12 .12 .12]);
cleanup=onCleanup(@() closeIfValid(fig));
ax=axes(fig,'Position',[.035 .07 .69 .87]);
imagesc(ax,img); axis(ax,'image'); colormap(ax,gray); hold(ax,'on');
title(ax,sprintf('Frame %d | Drag boundary endpoints; accept all six sites together',frame),'Color','w');
ax.XColor='w'; ax.YColor='w';
profileAx=axes(fig,'Position',[.77 .72 .21 .20]);
selector=uicontrol(fig,'Style','popupmenu','String',names,'Units','normalized', ...
    'Position',[.76 .64 .22 .05],'Callback',@selectSite);
summary=uicontrol(fig,'Style','text','Units','normalized','Position',[.75 .37 .24 .26], ...
    'HorizontalAlignment','left','FontSize',11,'BackgroundColor',[.12 .12 .12],'ForegroundColor','w');
message=uicontrol(fig,'Style','text','Units','normalized','Position',[.75 .02 .24 .12], ...
    'HorizontalAlignment','left','ForegroundColor',[1 .8 .2],'BackgroundColor',[.12 .12 .12]);
buttons=gobjects(5,1);
labels={'Redraw search line','Draw manual boundaries','Skip selected site','Accept frame / Next','Stop (keep earlier frames)'};
callbacks={@redrawSearch,@manualBoundary,@skipSite,@acceptFrame,@stopReview};
for k=1:5
    buttons(k)=uicontrol(fig,'Style','pushbutton','String',labels{k},'Units','normalized', ...
        'Position',[.76 .37-.045*k .22 .04],'Callback',callbacks{k});
end
for k=1:6
    if isempty(searchLines{k}), continue; end
    if ~isempty(previous)
        [searchLines{k},scores(k)]=wall.trackLine(previous,img,searchLines{k},radius);
    end
    [points{k},strengths(k)]=wall.profileEdges(img,searchLines{k},spacing([1 3]),limits);
    if validPoints(points{k})
        states{k}='reviewed_auto'; installROI(k);
    end
end
refresh(); uiwait(fig);
if accepted
    for k=1:6
        statuses{k}=states{k};
        if strcmp(states{k},'skipped')
            points{k}=nan(2,2); nextLines{k}=[];
        else
            points{k}=rois{k}.Position;
            values(k)=norm(diff(points{k},1,1).*spacing([1 3]));
            if strcmp(states{k},'reviewed_corrected')
                d=diff(points{k},1,1);
                searchLines{k}=[points{k}(1,:)-.5*d;points{k}(2,:)+.5*d];
                searchLines{k}(:,1)=max(1,min(size(img,2),searchLines{k}(:,1)));
                searchLines{k}(:,2)=max(1,min(size(img,1),searchLines{k}(:,2)));
            end
            nextLines{k}=searchLines{k};
        end
        records{k}=struct('frame',frame,'site',k,'slice',slice,'points_pixel',points{k}, ...
            'search_line_pixel',searchLines{k},'tracking_correlation',scores(k),'edge_strength',strengths(k));
    end
end

    function tf=validPoints(p)
        tf=isequal(size(p),[2 2]) && all(isfinite(p(:))) && norm(diff(p))>0 && ...
            all(p(:,1)>=1 & p(:,1)<=size(img,2) & p(:,2)>=1 & p(:,2)<=size(img,1));
    end
    function removeROI(k)
        if ~isempty(listeners{k}), delete(listeners{k}); listeners{k}=[]; end
        if ~isempty(rois{k}) && isvalid(rois{k}), delete(rois{k}); end
        rois{k}=[];
    end
    function installROI(k)
        removeROI(k);
        rois{k}=drawline(ax,'Position',points{k},'Color',colors(k,:), ...
            'Label',names{k},'Deletable',false,'DrawingArea',[1 1 size(img,2)-1 size(img,1)-1]);
        listeners{k}=addlistener(rois{k},'ROIMoved',@(~,~) moved(k));
    end
    function moved(k)
        states{k}='reviewed_corrected'; points{k}=rois{k}.Position;
        selected=k; selector.Value=k; refresh();
    end
    function selectSite(~,~)
        selected=selector.Value; refresh();
    end
    function refresh()
        if ~isgraphics(fig), return; end
        textLines=cell(6,1);
        for j=1:6
            if ~isempty(rois{j}) && isvalid(rois{j}) && validPoints(rois{j}.Position)
                mm=norm(diff(rois{j}.Position).*spacing([1 3]));
                textLines{j}=sprintf('%s: %.2f mm = %.3f cm',names{j},mm,mm/10);
            else
                textLines{j}=sprintf('%s: %s',names{j},states{j});
            end
        end
        summary.String=textLines;
        cla(profileAx);
        if ~isempty(searchLines{selected})
            [~,~,p]=wall.profileEdges(img,searchLines{selected},spacing([1 3]),limits);
            plot(profileAx,p.distance,p.intensity,'Color',colors(selected,:));
        end
        title(profileAx,names{selected}); xlabel(profileAx,'Distance (mm)'); ylabel(profileAx,'Brightness');
        message.String='Review every site. Draw or skip missing boundaries. Source spacing assumes cm; results show mm and cm (10 mm = 1 cm).';
    end
    function setBusy(tf)
        busy=tf;
        if tf, enabled='off'; else, enabled='on'; end
        set(buttons,'Enable',enabled); selector.Enable=enabled;
    end
    function xy=getLine(prompt)
        xy=[]; setBusy(true);
        title(ax,prompt,'Color','w');
        try
            roi=drawline(ax,'Color',colors(selected,:),'DrawingArea',[1 1 size(img,2)-1 size(img,1)-1]);
            wait(roi);
            if isvalid(roi), xy=roi.Position; delete(roi); end
        catch err
            if isgraphics(fig), setBusy(false); message.String=err.message; end
            return;
        end
        if isgraphics(fig), setBusy(false); end
    end
    function redrawSearch(~,~)
        xy=getLine('Draw cavity-to-outside search line; double-click to finish');
        if ~isgraphics(fig) || ~validPoints(xy), return; end
        searchLines{selected}=xy;
        [points{selected},strengths(selected)]=wall.profileEdges(img,xy,spacing([1 3]),limits);
        removeROI(selected); states{selected}='needs_review';
        if validPoints(points{selected})
            installROI(selected); states{selected}='reviewed_corrected';
        end
        refresh();
    end
    function manualBoundary(~,~)
        xy=getLine('Draw inner-to-outer boundary segment; double-click to finish');
        if ~isgraphics(fig) || ~validPoints(xy), return; end
        points{selected}=xy; states{selected}='reviewed_corrected';
        installROI(selected); refresh();
    end
    function skipSite(~,~)
        removeROI(selected); states{selected}='skipped'; refresh();
    end
    function acceptFrame(~,~)
        if busy, return; end
        for j=1:6
            if strcmp(states{j},'skipped'), continue; end
            if isempty(rois{j}) || ~isvalid(rois{j}) || ~validPoints(rois{j}.Position)
                message.String=['Draw boundaries or skip: ' names{j}]; return;
            end
        end
        accepted=true; uiresume(fig);
    end
    function stopReview(~,~)
        if ~busy, uiresume(fig); end
    end
end

function closeIfValid(fig)
if isgraphics(fig), close(fig); end
end
