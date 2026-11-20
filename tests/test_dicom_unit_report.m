function tests=test_dicom_unit_report
tests=functiontests(localfunctions);
end

function testRawUnitsAndIdentifierExclusion(testCase)
source=[tempname '.dcm']; output=[tempname '.txt'];
cleanup=onCleanup(@() removeFiles(source,output));
fid=fopen(source,'w','ieee-le');
fwrite(fid,zeros(1,128),'uint8'); fwrite(fid,'DICM','char');
writeTag(fid,hex2dec('0010'),hex2dec('0010'),'PN',6,'SECRET','char');
writeTag(fid,hex2dec('0018'),hex2dec('6024'),'US',2,3,'uint16');
writeTag(fid,hex2dec('0018'),hex2dec('6026'),'US',2,3,'uint16');
writeTag(fid,hex2dec('0018'),hex2dec('602c'),'FD',8,.088,'double');
writeTag(fid,hex2dec('0018'),hex2dec('602e'),'FD',8,.099,'double');
writeTag(fid,hex2dec('3001'),hex2dec('1003'),'FD',8,.063,'double');
fwrite(fid,[hex2dec('7fe0') hex2dec('0010')],'uint16'); fclose(fid);
report=diagnose_dicom_units(source,output);
verifyEqual(testCase,report.RawHeader.Status,'reached_pixel_data');
verifyEqual(testCase,report.RawHeader.Fields.PhysicalUnitsXDirection,3);
verifyEqual(testCase,report.RawHeader.Fields.PhysicalUnitsYDirection,3);
verifyEqual(testCase,report.RawHeader.Fields.PrivateDepthSpacing,.063,'AbsTol',1e-12);
verifyFalse(testCase,contains(fileread(output),'SECRET'));
verifyFalse(testCase,contains(fileread(output),source));
end

function writeTag(fid,group,element,vr,len,value,type)
fwrite(fid,[group element],'uint16'); fwrite(fid,vr,'char');
fwrite(fid,len,'uint16'); fwrite(fid,value,type);
end

function testSonosOBCompatibility(testCase)
source=[tempname '.dcm']; output=[tempname '.txt'];
cleanup=onCleanup(@() removeFiles(source,output));
fid=fopen(source,'w','ieee-le');
fwrite(fid,zeros(1,128),'uint8'); fwrite(fid,'DICM','char');
writeTag(fid,2,1,'OB',0,zeros(1,6),'uint8');
writeTag(fid,hex2dec('0018'),hex2dec('6024'),'US',2,3,'uint16');
writeTag(fid,hex2dec('0018'),hex2dec('6026'),'US',2,3,'uint16');
writeTag(fid,hex2dec('0018'),hex2dec('602c'),'FD',8,.088,'double');
writeTag(fid,hex2dec('3001'),hex2dec('1003'),'FD',8,.063,'double');
fwrite(fid,[hex2dec('7fe0') hex2dec('0010')],'uint16'); fclose(fid);
report=diagnose_dicom_units(source,output);
verifyEqual(testCase,report.LegacyHeader.Status,'reached_pixel_data');
verifyEqual(testCase,report.LegacyHeader.Fields.PhysicalUnitsXDirection,3);
verifyEqual(testCase,report.LegacyHeader.Fields.PhysicalUnitsYDirection,3);
verifyEqual(testCase,report.LegacyHeader.Fields.PrivateDepthSpacing,.063,'AbsTol',1e-12);
end

function removeFiles(varargin)
for k=1:nargin
    if isfile(varargin{k}), delete(varargin{k}); end
end
end
