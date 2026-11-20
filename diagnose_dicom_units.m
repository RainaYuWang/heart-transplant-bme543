function report = diagnose_dicom_units(filename)
% DIAGNOSE_DICOM_UNITS Export geometry/unit fields without patient identifiers.
% Run diagnose_dicom_units, select the original DICOM, and save the small TXT.
% No image pixels, patient details, dates or source paths are exported.
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
report.MetadataReadErrorIdentifier=metadataError;
report.Fields=collect(info);
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
catch err
    % Store only an error identifier, never messages that may contain paths.
    report.LegacyReader=struct('ReadFailed',true,'ErrorIdentifier',err.identifier);
end
text=jsonencode(report,'PrettyPrint',true);
disp(text);
[file,folder]=uiputfile('*.txt','Save geometry-only report','dicom_units_report.txt');
if ~isequal(file,0)
    fid=fopen(fullfile(folder,file),'w');
    assert(fid>=0,'wall:ReportWrite','Could not open the report file.');
    cleanup=onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',text);
end

    function out=collect(s)
        out=struct();
        if ~isstruct(s) || ~isscalar(s), return; end
        fields=fieldnames(s);
        for k=1:numel(fields)
            field=fields{k}; value=s.(field);
            if ismember(field,safeFields) && (isnumeric(value) || ischar(value) || isstring(value))
                out.(field)=value;
            elseif isstruct(value) && isscalar(value)
                child=collect(value);
                if ~isempty(fieldnames(child)), out.(field)=child; end
            end
        end
    end
end
