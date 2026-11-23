function tests = test_contour_review_ui
% Desktop regression: explicit decisions, frame advancement and window disposal.
% Run in MATLAB with a display and Image Processing Toolbox.
tests=functiontests(localfunctions);
end

function testMultipleFramesIgnoreIncidentalResumeAndCloseOldWindows(testCase)
assumeTrue(testCase,usejava('desktop') && exist('drawpolygon','file')~=0, ...
    'This regression requires MATLAB desktop and Image Processing Toolbox.');
inner=[40 40;60 40;60 60;40 60]; outer=[30 30;70 30;70 70;30 70];
previous=wall.contourThickness(inner,outer,[1 1],40,[0 360]); previous.frame=0;
settings=struct('frame_range',[1 3],'sample_count',40,'sector_deg',[0 360], ...
    'region_label','Synthetic test region');
cleanup=onCleanup(@() delete(findall(groot,'Type','figure','Tag','wallContourReview')));
for frame=1:3
    stage=0; ticks=0; callbackError=[]; reviewedFigure=[]; buttonLabel='';
    t=timer('ExecutionMode','fixedSpacing','Period',.2,'StartDelay',.2,'TimerFcn',@driveReview);
    timerCleanup=onCleanup(@() disposeTimer(t));
    start(t);
    [m,status]=wall.reviewContours(zeros(100),[1 1],frame,previous,settings,[0 1]);
    clear timerCleanup;
    if ~isempty(callbackError), rethrow(callbackError); end
    verifyEqual(testCase,stage,2,'An incidental UI resume must not end review.');
    verifyEqual(testCase,status,'accepted');
    assertFalse(testCase,isempty(m));
    verifyEqual(testCase,m.frame,frame);
    verifyEqual(testCase,m.mean_mm,10,'AbsTol',1e-10);
    verifyFalse(testCase,isgraphics(reviewedFigure),'The previous review window must be deleted before returning.');
    verifyEmpty(testCase,findall(groot,'Type','figure','Tag','wallContourReview'));
    if frame<3
        verifyEqual(testCase,buttonLabel,sprintf('Accept / Next frame %d',frame+1));
    else
        verifyEqual(testCase,buttonLabel,'Accept last frame / Show results');
    end
    previous=m;
end

    function driveReview(varargin)
        ticks=ticks+1;
        f=findall(groot,'Type','figure','Tag','wallContourReview');
        if ticks>100
            callbackError=MException('wall:TestTimeout','Timed out waiting for contour review.');
            delete(f); stop(t); return;
        end
        if isempty(f) || ~strcmp(get(f(1),'WaitStatus'),'waiting'), return; end
        f=f(1); reviewedFigure=f;
        try
            if stage==0
                stage=1;
                % Reproduce an unrelated UI resume; this must keep reviewing.
                uiresume(f); return;
            end
            copy=findobj(f,'Tag','wallContourAction3');
            callback=copy.Callback; callback(copy,[]);
            accept=findobj(f,'Tag','wallContourAction5'); buttonLabel=accept.String;
            stage=2;
            callback=accept.Callback; callback(accept,[]);
        catch err
            callbackError=err; delete(f); stop(t);
        end
    end
end

function disposeTimer(t)
if isvalid(t), stop(t); delete(t); end
end
