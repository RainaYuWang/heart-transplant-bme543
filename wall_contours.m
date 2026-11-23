function result = wall_contours(ds)
% WALL_CONTOURS Manual inner/outer rings and per-frame regional mean thickness.
% result = wall_contours             Select and resample a DICOM
% result = wall_contours(heart1)     Use an already loaded dataset
% Select an inclusive frame range and a fixed plane showing a closed LV ring.
% Draw two polygons each frame, or explicitly copy and edit the last accepted
% contours. Faint previous contours are positional references, not tracking.
% Uniform physical arc-length samples on the inner contour are measured to
% the closest outer polygon segment. A fixed angular sector is optional.
% Requires MATLAB R2022a+ and Image Processing Toolbox. See CONTOUR_THICKNESS_GUIDE.md.
result=[];
if exist('drawpolygon','file')==0 || exist('imresize3','file')==0
    error('wall:Toolbox','Image Processing Toolbox is required.');
end
if nargin==0
    [file,folder]=uigetfile('*.dcm','Select a cardiac DICOM file');
    if isequal(file,0), return; end
    ds=resampleDicom(fullfile(folder,file));
end
required={'data','width','height','depth','NumVolumes','widthspan','heightspan','depthspan'};
assert(isstruct(ds) && isscalar(ds) && all(isfield(ds,required)), ...
    'wall:Data','Input must be a volume structure returned by resampleDicom.');
dims=[ds.width ds.height ds.depth ds.NumVolumes];
assert(numel(dims)==4 && all(isfinite(dims)) && all(dims==fix(dims)) && ...
    all(dims(1:3)>=3) && dims(4)>=1 && isnumeric(ds.data) && isreal(ds.data) && ...
    ndims(ds.data)<=4 && isequal(dims,[size(ds.data,1) size(ds.data,2) size(ds.data,3) size(ds.data,4)]), ...
    'wall:Dimensions','Invalid volume dimensions. Use the corrected resampleDicom.');
rawSpacing=[ds.widthspan ds.heightspan ds.depthspan]./dims(1:3);
assert(all(isfinite(rawSpacing) & rawSpacing>0),'wall:Spacing','Voxel spacing must be finite and positive.');
spacing=10*rawSpacing; % User-authorized cm assumption; convert locally to mm once.
uiwait(helpdlg({'Choose one frame range and a plane showing a closed LV myocardial ring.'; ...
    'Draw the inner (endocardial) and outer (epicardial) contours; double-click to finish each polygon.'; ...
    'Faint outlines show the last accepted frame. Draw anew or copy and adjust them.'; ...
    'Preview green local distances; accept both contours together once per frame.'; ...
    'Mean thickness uses equally spaced inner-arc samples and shortest distances to outer segments.'; ...
    'A full ring gives a whole-ring mean. A fixed angular sector gives a regional mean.'; ...
    'This is manual 2D measurement, not automatic segmentation or tissue tracking.'; ...
    'Source spacing assumes cm (not verified by DICOM units). Results show mm and cm.'}, ...
    'How to use: contour wall thickness'));
answers=inputdlg({'First frame (inclusive)','Last frame (inclusive)', ...
    'Frame interval in ms (known and constant only; otherwise blank)', ...
    'Uniform samples around the full inner contour (12-2000)', ...
    'Region name (descriptive label; not assigned automatically)', ...
    'Sector start angle in degrees (0 = right, 90 = up)', ...
    'Counterclockwise sector extent in degrees (360 = whole ring)'}, ...
    'Frame range and region (fixed for this run)',1,{'1',num2str(ds.NumVolumes),'','200','LV region','0','360'});
if isempty(answers), return; end
first=str2double(answers{1}); last=str2double(answers{2}); count=str2double(answers{4});
sector=[str2double(answers{6}) str2double(answers{7})];
assert(all(isfinite([first last])) && first==fix(first) && last==fix(last) && first>=1 && last<=dims(4) && first<=last, ...
    'wall:Range','Invalid inclusive frame range.');
validateattributes(count,{'numeric'},{'real','finite','scalar','integer','>=',12,'<=',2000});
assert(all(isfinite(sector)) && sector(2)>0 && sector(2)<=360,'wall:Sector','Invalid sector start or extent.');
sector(1)=mod(sector(1),360); region=strtrim(answers{5});
assert(~isempty(region),'wall:Region','Enter a region name.');
dt=nan;
if ~isempty(strtrim(answers{3}))
    dt=str2double(answers{3})/1000;
    assert(isfinite(dt) && dt>0,'wall:Time','Frame interval must be positive or blank.');
end
[dimension,slice]=wall.chooseContourPlane(ds,first,spacing);
if isempty(dimension), return; end
if sector(2)==360, scope='whole ring'; else, scope=sprintf('sector %.1f + %.1f deg',sector); end
settings=struct('dimension',dimension,'slice',slice,'sample_count',count, ...
    'sector_deg',sector,'region_name',region,'region_label',sprintf('%s (%s)',region,scope));
frames=(first:last)'; n=numel(frames); records=cell(n,1); status=repmat({'not_measured'},n,1);
means=nan(n,1); medians=nan(n,1); selectedCount=zeros(n,1); arcStep=nan(n,1);
[initialImage,planeSpacing]=wall.contourImage(ds,dimension,slice,first,spacing);
climits=[min(initialImage(:)) max(initialImage(:))];
if climits(1)==climits(2), climits=climits+[-.5 .5]; end
previous=[]; firstAcceptedImage=[]; firstAccepted=[];
for k=1:n
    img=wall.contourImage(ds,dimension,slice,frames(k),spacing);
    [m,state]=wall.reviewContours(img,planeSpacing,frames(k),previous,settings,climits);
    if strcmp(state,'not_measured'), break; end
    status{k}=state;
    if strcmp(state,'accepted')
        records{k}=m; means(k)=m.mean_mm; medians(k)=m.median_mm;
        selectedCount(k)=m.sample_count; arcStep(k)=m.arc_step_mm;
        previous=m;
        if isempty(firstAccepted), firstAccepted=m; firstAcceptedImage=img; end
    end
end
if all(strcmp(status,'not_measured')), return; end
t=table(frames,repmat({region},n,1),means,means/10,medians,selectedCount,arcStep,status, ...
    'VariableNames',{'Frame','Region','MeanThickness_mm','MeanThickness_cm','MedianThickness_mm', ...
    'SelectedSampleCount','InnerArcStep_mm','Status'});
t.PlaneDimension=repmat(dimension,n,1); t.Slice=repmat(slice,n,1);
t.SectorStart_deg=repmat(sector(1),n,1); t.SectorExtent_deg=repmat(sector(2),n,1);
t.TotalSampleCount=repmat(count,n,1);
t.SourceUnitAssumption=repmat({'cm (user assumption; not DICOM verified)'},n,1);
t.DistanceDefinition=repmat({'2D inner-to-outer shortest segment distance'},n,1);
if isfinite(dt), t.Time_s=(frames-first)*dt; end
result=struct('method','Manual 2D contours: uniform inner arc, shortest outer segment distance', ...
    'settings',settings,'frames',frames,'table',t,'measurements',{records}, ...
    'first_accepted',firstAccepted,'first_accepted_image',firstAcceptedImage, ...
    'raw_spacing',rawSpacing,'spacing_mm',spacing,'plane_spacing_mm',planeSpacing, ...
    'declared_source_unit','cm','calibration_status','cm_assumed_by_user_not_DICOM_verified', ...
    'source_dimensions',dims,'frame_interval_s',dt,'display_limits',climits);
wall.plotContourResults(result); disp(t);
[file,folder]=uiputfile('*.mat','Save MAT, frame CSV and local-distance CSV (Cancel keeps the result in MATLAB)', ...
    'contour_wall_results.mat');
if isequal(file,0), return; end
[~,stem]=fileparts(file);
paths={fullfile(folder,[stem '.mat']),fullfile(folder,[stem '.csv']),fullfile(folder,[stem '_samples.csv'])};
if any(cellfun(@isfile,paths))
    choice=questdlg('A result file already exists. Replace the MAT and both CSV files?', ...
        'Confirm overwrite','Replace','Cancel','Cancel');
    if ~strcmp(choice,'Replace'), return; end
end
samples=wall.contourSampleTable(result);
save(paths{1},'result','-v7.3'); writetable(t,paths{2}); writetable(samples,paths{3});
end
