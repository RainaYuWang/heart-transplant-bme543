function fig = plotResults(result)
% Display initial locations and six separate curves; NaNs remain gaps.
fig=figure('Name','Six-site wall thickness results','NumberTitle','off','Position',[80 80 1200 600]);
layout=tiledlayout(fig,1,2,'TileSpacing','compact');
ax=nexttile(layout); imagesc(ax,result.initial_image); axis(ax,'image');
colormap(ax,gray); hold(ax,'on');
for k=1:6
    xy=result.initial_lines{k};
    plot(ax,xy(:,1),xy(:,2),'--o','Color',result.site_colors(k,:),'LineWidth',1.5);
    text(ax,xy(2,1),xy(2,2),sprintf(' %d %s',k,result.site_names{k}), ...
        'Color',result.site_colors(k,:),'BackgroundColor','k');
end
title(ax,'First frame: six sites (screen positions)');
xlabel(ax,'Image column (pixel)'); ylabel(ax,'Image row (pixel)');
curveAx=nexttile(layout); hold(curveAx,'on');
for k=1:6
    rows=result.table.SiteID==k;
    if ismember('Time_s',result.table.Properties.VariableNames)
        x=result.table.Time_s(rows); label='Time from selected first frame (s)';
    else
        x=result.table.Frame(rows); label='Frame';
    end
    plot(curveAx,x,result.table.Thickness_mm(rows),'-o','Color',result.site_colors(k,:), ...
        'DisplayName',result.site_names{k},'LineWidth',1.4,'MarkerSize',4);
end
grid(curveAx,'on'); xlabel(curveAx,label); ylabel(curveAx,'Thickness (mm)');
legend(curveAx,'Location','best'); title(curveAx,'Six-site thickness over time (gaps = missing data)');
if isfield(result,'is_demo') && result.is_demo
    title(layout,'SYNTHETIC DEMO - Not real measurements');
elseif isfield(result,'calibration_status')
    title(layout,'Source spacing: cm assumed by user | Thickness: mm | 10 mm = 1 cm');
end
end
