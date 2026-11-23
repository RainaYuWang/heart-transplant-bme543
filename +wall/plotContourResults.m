function fig = plotContourResults(result)
% First accepted contours and a regional mean curve; missing frames stay NaN.
fig=figure('Name','Contour wall thickness results','NumberTitle','off','WindowState','maximized');
layout=tiledlayout(fig,1,2,'TileSpacing','compact');
ax=nexttile(layout); m=result.first_accepted;
if ~isempty(m)
    imagesc(ax,result.first_accepted_image,result.display_limits); colormap(ax,gray);
    axis(ax,'image'); hold(ax,'on');
    daspect(ax,[1/result.plane_spacing_mm(1) 1/result.plane_spacing_mm(2) 1]);
    p=[m.inner_pixel;m.inner_pixel(1,:)]; q=[m.outer_pixel;m.outer_pixel(1,:)];
    plot(ax,p(:,1),p(:,2),'-','Color',[0 .9 1],'LineWidth',1.5);
    plot(ax,q(:,1),q(:,2),'-','Color',[1 .55 .1],'LineWidth',1.5);
    p=m.sample_pixel(m.selected,:); q=m.nearest_outer_pixel(m.selected,:);
    plot(ax,[p(:,1) q(:,1)]',[p(:,2) q(:,2)]','Color',[.45 .9 .35],'LineWidth',.6);
    title(ax,sprintf('Frame %d: contours and selected local distances',m.frame));
else
    axis(ax,'off'); text(ax,.1,.5,'No accepted contours (all visited frames were skipped).');
end
ax=nexttile(layout);
if ismember('Time_s',result.table.Properties.VariableNames)
    x=result.table.Time_s; xLabel='Time from selected first frame (s)';
else
    x=result.table.Frame; xLabel='Frame';
end
plot(ax,x,result.table.MeanThickness_mm,'-o','LineWidth',1.5);
grid(ax,'on'); xlabel(ax,xLabel); ylabel(ax,'Regional mean thickness (mm)');
title(ax,{result.settings.region_label,'Gaps = skipped or unmeasured frames'},'Interpreter','none');
if isfield(result,'is_demo') && result.is_demo
    title(layout,'SYNTHETIC DEMO - not patient measurements');
else
    title(layout,'Manual 2D contours | Source spacing assumes cm (unverified) | 10 mm = 1 cm');
end
end
