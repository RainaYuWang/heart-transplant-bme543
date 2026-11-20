function report = diagnose_dicom_units(filename, outputFile)
% DIAGNOSE_DICOM_UNITS Export geometry/unit fields without patient identifiers.
% Run diagnose_dicom_units, select the original DICOM, and save the small TXT.
% No image pixels, patient details, dates or source paths are exported.
% diagnose_dicom_units(filename, outputFile) saves without file dialogs.
if nargin==0
    [file,folder]=uigetfile('*.dcm','Select the original DICOM for unit inspection');
    if isequal(file,0), report=[]; return; end
    filename=fullfile(folder,file);
end
metadataError='';
try
    info=dicominfo(filename);
catch err
    info=struct(); metadataError=err.identifier;
end
safeFields={'Rows','Columns','NumberOfFrames','PixelSpacing','ImagerPixelSpacing', ...
    'SpacingBetweenSlices','SliceThickness','PhysicalUnitsXDirection','PhysicalUnitsYDirection', ...
    'PhysicalDeltaX','PhysicalDeltaY','RegionSpatialFormat','RegionDataType', ...
    'RegionLocationMinX0','RegionLocationMinY0','RegionLocationMaxX1','RegionLocationMaxY1', ...
    'Private_3001_1001','Private_3001_1003'};
report=struct('Format','Geometry-only DICOM unit report','Fields',struct());
report.ReportVersion=2;
report.MetadataReadErrorIdentifier=metadataError;
report.MetadataClass=class(info);
report.MetadataSize=size(info);
if isstruct(info), report.MetadataFieldNames=fieldnames(info); end
report.Fields=collect(info);
% Independently inspect the flat explicit-little-endian header used by the
% supplied Philips reader. Unknown layouts are reported, never guessed.
report.RawHeader=scanLegacyHeader(filename);
report.Notes={ ...
    'PhysicalUnitsXDirection/YDirection code 3 denotes cm for that region axis.', ...
    'PixelSpacing uses mm. Do not substitute it for vendor-specific volume geometry without verification.', ...
    'The legacy reader uses PhysicalDeltaX, PhysicalDeltaY and private (3001,1003) for depth.', ...
    'A standard X/Y unit tag does not by itself establish the unit of the private depth field.'};
% Read one frame only to report exactly what the legacy volume reader uses.
try
    volume=readDicom3D(filename,1);
    report.LegacyReader=struct('Dimensions',[volume.width volume.height volume.depth], ...
        'RawVoxelSpacing',[volume.widthspan/volume.width volume.heightspan/volume.height volume.depthspan/volume.depth]);
    spans=[volume.widthspan volume.heightspan volume.depthspan];
    report.LegacyReader.FieldOfViewCm_IfRawUnitIsCm=spans;
    report.LegacyReader.FieldOfViewCm_IfRawUnitIsMm=spans/10;
catch err
    % Store only an error identifier, never messages that may contain paths.
    report.LegacyReader=struct('ReadFailed',true,'ErrorIdentifier',err.identifier);
end
text=jsonencode(report,'PrettyPrint',true);
disp(text);
if nargin<2
    [file,folder]=uiputfile('*.txt','Save geometry-only report','dicom_units_report_v2.txt');
    if isequal(file,0), return; end
    outputFile=fullfile(folder,file);
end
if ~isempty(outputFile)
    fid=fopen(outputFile,'w');
    assert(fid>=0,'wall:ReportWrite','Could not open the report file.');
    cleanup=onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',text);
end

    function out=collect(s)
        out=struct();
        if iscell(s) || (isstruct(s) && ~isscalar(s))
            for j=1:numel(s)
                if iscell(s), item=s{j}; else, item=s(j); end
                child=collect(item);
                if ~isempty(fieldnames(child)), out.(sprintf('Item_%d',j))=child; end
            end
            return;
        end
        if ~isstruct(s), return; end
        fields=fieldnames(s);
        for k=1:numel(fields)
            field=fields{k}; value=s.(field);
            if ismember(field,safeFields) && (isnumeric(value) || ischar(value) || isstring(value))
                out.(field)=value;
            elseif isstruct(value) || iscell(value)
                child=collect(value);
                if ~isempty(fieldnames(child)), out.(field)=child; end
            end
        end
    end
end

function result=scanLegacyHeader(filename)
result=struct('Status','not_read','Fields',struct(),'TagLayout',{{}});
fid=fopen(filename,'r','ieee-le');
if fid<0, result.Status='cannot_open'; return; end
cleanup=onCleanup(@() fclose(fid));
fseek(fid,0,'eof'); fileSize=ftell(fid); fseek(fid,128,'bof');
if ~strcmp(char(fread(fid,4,'*char').'),'DICM')
    result.Status='no_DICM_preamble'; return;
end
longVR={'OB','OD','OF','OL','OV','OW','SQ','UC','UR','UT','UN'};
% Only known geometry values are retained, never arbitrary header values.
for k=1:5000
    group=fread(fid,1,'uint16'); element=fread(fid,1,'uint16');
    if isempty(group) || isempty(element), result.Status='truncated_header'; return; end
    if group==hex2dec('7fe0') && element==hex2dec('0010')
        result.Status='reached_pixel_data'; return;
    end
    vr=char(fread(fid,2,'*char').');
    if numel(vr)~=2 || ~all(vr>='A' & vr<='Z')
        result.Status='unsupported_VR_or_byte_order'; return;
    end
    if ismember(vr,longVR)
        reserved=fread(fid,1,'uint16'); len=fread(fid,1,'uint32');
        if isempty(reserved) || reserved~=0, result.Status='invalid_reserved_bytes'; return; end
    else
        len=fread(fid,1,'uint16');
    end
    if isempty(len) || len==double(intmax('uint32'))
        result.Status='undefined_length_requires_standard_parser'; return;
    end
    if ftell(fid)+len>fileSize, result.Status='invalid_value_length'; return; end
    tag=sprintf('%04X_%04X',group,element);
    result.TagLayout{end+1}=sprintf('%s %s %d',tag,vr,len);
    field=''; value=[];
    switch tag
        case {'0018_6024','0018_6026'}
            if strcmp(vr,'US') && len==2
                if element==hex2dec('6024'), field='PhysicalUnitsXDirection';
                else, field='PhysicalUnitsYDirection'; end
                value=fread(fid,1,'uint16');
            end
        case {'0018_602C','0018_602E','3001_1003'}
            if strcmp(vr,'FD') && len==8
                if element==hex2dec('602c'), field='PhysicalDeltaX';
                elseif element==hex2dec('602e'), field='PhysicalDeltaY';
                else, field='PrivateDepthSpacing'; end
                value=fread(fid,1,'double');
            end
    end
    if isempty(field)
        fseek(fid,len,'cof');
    else
        % Keep all occurrences to expose inconsistent calibration entries.
        if isfield(result.Fields,field)
            result.Fields.(field)(end+1)=value;
        else
            result.Fields.(field)=value;
        end
    end
    if strcmp(vr,'SQ')
        % Sequence values have been skipped. The standard metadata traversal
        % handles nested regions; a flat scan must not claim their absence.
        result.SequenceValuesSkipped=true;
    end
end
result.Status='tag_limit_reached';
end
