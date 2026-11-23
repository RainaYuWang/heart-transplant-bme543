function samples = contourSampleTable(result)
% Export every local distance, including its regional selection flag.
rows=cell(numel(result.measurements),1);
for k=1:numel(rows)
    m=result.measurements{k};
    if isempty(m), continue; end
    n=numel(m.thickness_mm);
    rows{k}=table(repmat(m.frame,n,1),(1:n)',m.sample_pixel(:,1),m.sample_pixel(:,2), ...
        m.nearest_outer_pixel(:,1),m.nearest_outer_pixel(:,2),m.angle_deg,m.selected, ...
        m.thickness_mm,m.thickness_mm/10, ...
        'VariableNames',{'Frame','SampleIndex','InnerColumn_pixel','InnerRow_pixel', ...
        'OuterColumn_pixel','OuterRow_pixel','Angle_deg','IncludedInMean','Thickness_mm','Thickness_cm'});
end
rows=rows(~cellfun(@isempty,rows));
if isempty(rows)
    samples=table('Size',[0 10],'VariableTypes', ...
        {'double','double','double','double','double','double','double','logical','double','double'}, ...
        'VariableNames',{'Frame','SampleIndex','InnerColumn_pixel','InnerRow_pixel', ...
        'OuterColumn_pixel','OuterRow_pixel','Angle_deg','IncludedInMean','Thickness_mm','Thickness_cm'});
else
    samples=vertcat(rows{:});
end
samples.SourceUnitAssumption=repmat({'cm (user assumption; not DICOM verified)'},height(samples),1);
samples.Region=repmat({result.settings.region_name},height(samples),1);
end
