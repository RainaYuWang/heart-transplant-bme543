function tests = test_wall_algorithms
% MATLAB: results = runtests('tests/test_wall_algorithms.m'); assertSuccess(results)
tests = functiontests(localfunctions);
end

function testBrightSlab(testCase)
img=zeros(40,100); img(:,31:50)=1;
[points,~,~]=wall.profileEdges(img,[10 20;80 20],[.5 .5],[5 15]);
verifyTrue(testCase,all(isfinite(points(:))));
thickness=norm(diff(points).*[.5 .5]);
verifyEqual(testCase,thickness,10,'AbsTol',1);
verifyEqual(testCase,mean(points(:,1)),40.5,'AbsTol',1);
end

function testUniformAndReversed(testCase)
[p,~,~]=wall.profileEdges(ones(40,100),[10 20;80 20],[1 1],[2 30]);
verifyTrue(testCase,all(isnan(p(:))));
img=zeros(40,100); img(:,31:50)=1;
[p,~,~]=wall.profileEdges(img,[80 20;10 20],[1 1],[5 30]);
verifyEqual(testCase,norm(diff(p)),20,'AbsTol',2);
end

function testKnownTranslation(testCase)
rng(42); previous=rand(50,60); current=zeros(size(previous));
current(3:end,4:end)=previous(1:end-2,1:end-3);
line=[20 20;30 25];
[moved,score]=wall.trackLine(previous,current,line,5);
verifyEqual(testCase,moved,line+[3 2]);
verifyGreaterThan(testCase,score,.99);
end

function testSixSiteRowsKeepMissingValues(testCase)
values=reshape(1:18,3,6); values(2,4)=nan;
statuses=repmat({'reviewed_auto'},3,6); statuses{2,4}='skipped';
names={'LU','LM','LL','RU','RM','RL'};
t=wall.sixResults([7 8 9],values,statuses,names);
verifyEqual(testCase,height(t),18);
verifyEqual(testCase,t.Frame,repelem([7;8;9],6));
verifyEqual(testCase,t.SiteID,repmat((1:6)',3,1));
for k=1:6
    verifyEqual(testCase,t.Thickness_mm(t.SiteID==k),values(:,k));
end
verifyEqual(testCase,t.Status{10},'skipped');
verifyEqual(testCase,t.Site{10},'RU');
end

function testPartialFrameKeepsUnmeasuredSites(testCase)
t=wall.sixResults(5,[8 nan nan nan nan nan], ...
    {'reviewed_auto','not_measured','not_measured','not_measured','not_measured','not_measured'}, ...
    {'LU','LM','LL','RU','RM','RL'});
verifyEqual(testCase,height(t),6);
verifyTrue(testCase,all(isnan(t.Thickness_mm(2:end))));
end
