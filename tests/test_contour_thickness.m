function tests = test_contour_thickness
% Run: assertSuccess(runtests('tests/test_contour_thickness.m'))
tests=functiontests(localfunctions);
end

function testConcentricCircles(testCase)
t=(0:127)'*2*pi/128; unit=[cos(t) sin(t)];
m=wall.contourThickness(20*unit,28*unit,[1 1],200,[0 360]);
verifyEqual(testCase,m.mean_mm,8,'AbsTol',.01);
verifyEqual(testCase,m.sample_count,200);
verifyLessThan(testCase,max(abs(m.thickness_mm-8)),.01);
steps=sqrt(sum(diff([m.sample_pixel;m.sample_pixel(1,:)]).^2,2));
verifyLessThan(testCase,max(steps)-min(steps),.002);
end

function testAnisotropicSpacingAndEquivalentVertexOrder(testCase)
inner=[-2 -2;2 -2;2 2;-2 2]; outer=inner*2;
a=wall.contourThickness(inner,outer,[1 1],80,[0 360]);
b=wall.contourThickness(inner./[.5 2],outer./[.5 2],[.5 2],80,[0 360]);
c=wall.contourThickness(flipud(circshift(inner,2)),flipud(circshift(outer,1)),[1 1],80,[0 360]);
verifyEqual(testCase,a.mean_mm,2,'AbsTol',1e-12);
verifyEqual(testCase,b.thickness_mm,a.thickness_mm,'AbsTol',1e-12);
verifyEqual(testCase,c.sample_pixel,a.sample_pixel,'AbsTol',1e-12);
verifyEqual(testCase,c.thickness_mm,a.thickness_mm,'AbsTol',1e-12);
end

function testUnevenVerticesDoNotWeightTheMean(testCase)
inner=[-2 -2;2 -2;2 2;-2 2]; outer=inner*2;
a=wall.contourThickness(inner,outer,[1 1],80,[0 360]);
inner=[-2 -2;-1.9 -2;-1.8 -2;-1 -2;0 -2;2 -2;2 2;-2 2];
b=wall.contourThickness(inner,outer,[1 1],80,[0 360]);
verifyEqual(testCase,b.sample_pixel,a.sample_pixel,'AbsTol',1e-12);
verifyEqual(testCase,b.mean_mm,a.mean_mm,'AbsTol',1e-12);
end

function testSegmentProjectionNotNearestVertex(testCase)
m=wall.contourThickness([-1 -1;1 -1;1 1;-1 1],[-4 -4;4 -4;4 4;-4 4],[1 1],80,[0 360]);
verifyEqual(testCase,m.thickness_mm,3*ones(80,1),'AbsTol',1e-12);
end

function testSectorWrapAndTranslation(testCase)
t=(0:95)'*2*pi/96; u=[cos(t) sin(t)];
a=wall.contourThickness(20*u,28*u,[1 1],200,[315 90]);
b=wall.contourThickness(20*u+[47 26],28*u+[47 26],[1 1],200,[315 90]);
verifyTrue(testCase,all(a.angle_deg(a.selected)>=315 | a.angle_deg(a.selected)<45));
verifyEqual(testCase,a.sample_count,50);
verifyEqual(testCase,b.selected,a.selected);
verifyEqual(testCase,b.thickness_mm,a.thickness_mm,'AbsTol',1e-10);
end

function testRejectCrossingTouchingAndDegenerateContours(testCase)
outer=[0 0;10 0;10 10;0 10];
verifyError(testCase,@() wall.contourThickness([2 2;8 8;2 8;8 2],outer,[1 1],80,[0 360]),'wall:Contours');
verifyError(testCase,@() wall.contourThickness([0 2;4 2;4 4;0 4],outer,[1 1],80,[0 360]),'wall:Contours');
verifyError(testCase,@() wall.contourThickness([2 2;12 2;12 4;2 4],outer,[1 1],80,[0 360]),'wall:Contours');
verifyError(testCase,@() wall.contourThickness([2 2;3 3;4 4],outer,[1 1],80,[0 360]),'wall:Contours');
end

function testConcaveOuterCrossingIsRejected(testCase)
% Inner vertices are inside, but an inner edge crosses an outer notch.
outer=[0 0;10 0;10 10;6 10;6 4;4 4;4 10;0 10];
inner=[2 2;8 2;8 8;2 8];
verifyError(testCase,@() wall.contourThickness(inner,outer,[1 1],80,[0 360]),'wall:Contours');
end

function testShortestPathsMayNotCrossTheCavity(testCase)
inner=[8 4;9 4;9 6;8 6]; outer=[0 0;10 0;10 10;0 10];
verifyError(testCase,@() wall.contourThickness(inner,outer,[1 1],120,[0 360]),'wall:AmbiguousPath');
% The right-facing region has valid outward paths even in this offset model.
m=wall.contourThickness(inner,outer,[1 1],120,[315 90]);
verifyEqual(testCase,m.mean_mm,1,'AbsTol',1e-12);
end

function testPlaneCoordinatesAndSpacing(testCase)
ds.data=reshape(1:120,[4 5 3 2]);
for axisIndex=1:3
    [img,sp]=wall.contourImage(ds,axisIndex,2,2,[.5 1 2]);
    switch axisIndex
        case 1, expected=squeeze(ds.data(2,:,:,2)).'; spacing=[1 2];
        case 2, expected=squeeze(ds.data(:,2,:,2)).'; spacing=[.5 2];
        case 3, expected=ds.data(:,:,2,2).'; spacing=[.5 1];
    end
    verifyEqual(testCase,img,double(expected)); verifyEqual(testCase,sp,spacing);
end
end

function testExportRetainsLocalSelectionAndMissingFrames(testCase)
m=wall.contourThickness([-2 -2;2 -2;2 2;-2 2],[-4 -4;4 -4;4 4;-4 4],[1 1],80,[0 90]);
m.frame=9;
result.measurements={[];m;[]}; result.settings.region_name='Example region';
t=wall.contourSampleTable(result);
verifyEqual(testCase,height(t),80);
verifyEqual(testCase,t.Frame,9*ones(80,1));
verifyEqual(testCase,t.IncludedInMean,m.selected);
verifyEqual(testCase,mean(t.Thickness_mm(t.IncludedInMean)),m.mean_mm);
verifyEqual(testCase,t.Thickness_cm,t.Thickness_mm/10);
result.measurements={[];[]};
t=wall.contourSampleTable(result); verifyEqual(testCase,height(t),0);
end
