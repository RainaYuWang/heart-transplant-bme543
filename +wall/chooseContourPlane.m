function [dimension,slice] = chooseContourPlane(ds,frame,spacing)
% Preview a fixed data-axis plane before drawing a closed myocardial ring.
dimension=[]; slice=[]; chosen=false;
fig=figure('Name','Choose a closed LV cross-section','NumberTitle','off','WindowState','maximized');
cleanup=onCleanup(@() closeIfValid(fig));
ax=axes(fig,'Position',[.05 .19 .9 .75]);
plane=uicontrol(fig,'Style','popupmenu','String',{'Fix dimension 1','Fix dimension 2','Fix dimension 3'}, ...
    'Value',3,'Units','normalized','Position',[.05 .1 .2 .05],'Callback',@changePlane);
slider=uicontrol(fig,'Style','slider','Units','normalized','Position',[.28 .1 .42 .04],'Callback',@refresh);
label=uicontrol(fig,'Style','text','Units','normalized','Position',[.28 .04 .42 .04]);
uicontrol(fig,'Style','pushbutton','String','Use this plane for all frames','Units','normalized', ...
    'Position',[.73 .08 .23 .07],'Callback',@accept);
changePlane(); uiwait(fig);
if chosen, dimension=plane.Value; slice=round(slider.Value); end
% Release the preview and its nested callbacks before opening frame review.
closeIfValid(fig);

    function changePlane(varargin)
        n=size(ds.data,plane.Value);
        slider.Min=1; slider.Max=n; slider.Value=round(n/2);
        slider.SliderStep=[1/(n-1) min(1,10/(n-1))];
        refresh();
    end
    function refresh(varargin)
        s=round(slider.Value); slider.Value=s;
        [img,sp]=wall.contourImage(ds,plane.Value,s,frame,spacing);
        imagesc(ax,img); colormap(ax,gray); axis(ax,'image');
        daspect(ax,[1/sp(1) 1/sp(2) 1]);
        title(ax,{'Choose a plane showing a CLOSED LV myocardial ring.', ...
            'A data-axis slice is not automatically an anatomical short-axis view. Close this window to cancel.'});
        label.String=sprintf('Frame %d | Dimension %d | Slice %d of %d',frame,plane.Value,s,slider.Max);
    end
    function accept(varargin)
        chosen=true; uiresume(fig);
    end
end

function closeIfValid(fig)
if isgraphics(fig), close(fig); end
end
