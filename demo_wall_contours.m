function result = demo_wall_contours
% DEMO_WALL_CONTOURS Preview actual plotting and calculations without a DICOM.
% This synthetic circular model does not validate ultrasound boundary accuracy.
frames=(1:12)'; records=cell(numel(frames),1); values=nan(size(frames));
theta=(0:95)'*2*pi/96; direction=[cos(theta) sin(theta)];
for k=1:numel(frames)
    if k==7, continue; end % Demonstrate a missing frame without interpolation.
    radius=28-3*sin(pi*(k-1)/11)^2;
    thickness=8+3*sin(pi*(k-1)/11)^2;
    inner=100+(radius/.5)*direction;
    outer=100+((radius+thickness)/.5)*direction;
    records{k}=wall.contourThickness(inner,outer,[.5 .5],200,[0 90]);
    records{k}.frame=k; values(k)=records{k}.mean_mm;
end
[x,y]=meshgrid(1:200); r=hypot(x-100,y-100)*.5;
img=double(r>=28 & r<=36);
result=struct('is_demo',true,'first_accepted',records{1},'first_accepted_image',img, ...
    'plane_spacing_mm',[.5 .5],'display_limits',[0 1],'measurements',{records});
result.settings=struct('region_name','Synthetic upper-right region', ...
    'region_label','Synthetic upper-right region (0-90 degrees)');
result.table=table(frames,values,values/10,'VariableNames',{'Frame','MeanThickness_mm','MeanThickness_cm'});
wall.plotContourResults(result);
end
