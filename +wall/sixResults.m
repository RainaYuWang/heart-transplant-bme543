function data = sixResults(frames, values, statuses, names)
% One row per frame AND site, retaining skipped/unmeasured entries as NaN.
assert(isequal(size(values),[numel(frames) 6]) && isequal(size(statuses),size(values)), ...
    'wall:ResultSize','Expected one row per frame and six site columns.');
assert(numel(names)==6,'wall:Sites','Expected six site names.');
frameColumn=repelem(frames(:),6);
siteColumn=repmat((1:6)',numel(frames),1);
labels=reshape(names(siteColumn),[],1);
thickness=reshape(values.',[],1);
state=reshape(statuses.',[],1);
data=table(frameColumn,siteColumn,labels,thickness,state, ...
    'VariableNames',{'Frame','SiteID','Site','Thickness_mm','Status'});
end
