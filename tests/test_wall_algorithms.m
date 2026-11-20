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

function testConcentricShell(testCase)
[x,y,z]=ndgrid(-25:25); r=sqrt(x.^2+y.^2+z.^2);
inner=r<=12; outer=r<=18;
[map,values,valid]=wall.surfaceDistance(inner,outer,.5,2);
verifyTrue(testCase,all(isnan(map(~valid))));
verifyEqual(testCase,median(values),3,'AbsTol',1);
verifyTrue(testCase,all(values>0));
end

function testCrossingMasksRejected(testCase)
inner=false(10,10,10); outer=inner;
inner(3:8,3:8,3:8)=true; outer(4:7,4:7,4:7)=true;
verifyError(testCase,@() wall.surfaceDistance(inner,outer,1,2),'wall:Nesting');
end

function testEndCapsExcluded(testCase)
inner=false(30,30,20); outer=inner;
inner(10:20,10:20,3:18)=true; outer(5:25,5:25,3:18)=true;
[~,values,valid]=wall.surfaceDistance(inner,outer,1,2);
verifyFalse(testCase,any(reshape(valid(:,:,1:4),[],1)));
verifyFalse(testCase,any(reshape(valid(:,:,17:20),[],1)));
verifyGreaterThan(testCase,min(values),0);
end
