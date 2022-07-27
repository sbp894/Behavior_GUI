function varargout = behavior_gui(varargin)

% Last Modified by GUIDE v2.5 17-Feb-2021 16:00:11

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @behavior_gui_OpeningFcn, ...
    'gui_OutputFcn',  @behavior_gui_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before behavior_gui is made visible.
function behavior_gui_OpeningFcn(hObject, eventdata, handles, varargin)

global gB
% video parameters
gB.vid=videoinput('winvideo',1,'YUY2_320x240');% take video input
triggerconfig(gB.vid,'manual');  % after triggering only we get video
set(gB.vid,'FramesPerTrigger',1); %only 1 frame per trigger
set(gB.vid,'TriggerRepeat', Inf); %repeating trigger infinite timf
set(gB.vid,'ReturnedColorSpace','grayscale');% colour space used is grayscale

%internal
gB.version = 3; % new variable from v2, stimulus list can be loaded from v3
gB.State = -1; % current state
gB.stopped = 0; gB.paused = 0;
gB.bkgImg = zeros(240,320,0);
gB.Threshold = 50; % threshold for change detection
gB.dio = daq.createSession('ni');
gB.dio_ch = addDigitalChannel(gB.dio,'Dev1','port1/line0:3','OutputOnly');
outputSingleScan(gB.dio,[0 0 0 0]);

% home and target areas
gB.home = [160 160 320 320;1 240 240 1];
gB.right = [30 30 140 140; 115 0 0 115];
gB.left = [30 30 140 140; 240 130 130 240];

% behavior parameters (defaults)
gB.TaskType = 1; % 1 = GO/NOGO, 2 = 2AFC
gB.TrialInitTimeMin = 3; % seconds
gB.TrialInitTimeMax = 5; % seconds
gB.thisTrialTime = gB.TrialInitTimeMin;
gB.TimeoutTime = 5; %seconds - This is time to leave the HB
gB.ResponseTime = 5; %seconds - This is additional time to enter target area
gB.RewardTime = 1; % seconds for triggering pellet
gB.AirpuffTime = 1; % seconds of airpuff
gB.AirpuffWaitTime = 0.5;
gB.TargProb = 0.5;
gB.TargSide = 1; % 1 is left, 2 is right
gB.TimeoutDuration = 5;
gB.TimeoutIfNotWaiting = 0;
gB.TimeoutForMiss = 0;
%gB.ReturnHomeTime = 30; %seconds

% sounds
gB.targfilelist = {}; % target/GO file list
gB.distrfilelist = {};% distractor/NO-GO file list
gB.catch1_filelist = {};
gB.catch2_filelist = {};
gB.hascatchtrials = 0;
gB.stimuli = {}; %{1} is target/GO, 2 is distractor/NO-GO
gB.stimlistspecified = 0;
gB.stimlist = []; gB.liststart = NaN; gB.listend = NaN;
% gB.ding = audioread('Ding.wav');
% gB.buzz = audioread('Buzz.wav');

gB.Fs = {};
gB.Fs{1} = NaN;gB.Fs{2} = NaN;

% animal parameters
gB.animal = 'test';
gB.op = 'test';
gB.tday = 1;
gB.session = 1;
gB.savedir = 'F:\DATA\BEHAVIOR\Default';
gB.savefile = 'default.mat';

% trial parameters
gB.trials = [];
gB.colnames = {'TrialType','StimNum','Outcome','TrialOnset_hour', ...
    'TrialOnset_min','TrialOnset_sec', ...
    'StimOnsetTime','LeftHomeBaseTime','OutcomeTime','TrialEndTime'};
gB.ntrials = 0;
gB.thistrialtype = 2; %1- target/GO, 2 - distractor/NO-GO
gB.thistrialstim = 1;
gB.hit = 0;
gB.fa = 0;
gB.cr = 0;
gB.miss = 0;
gB.catch_go = 0;
gB.catch_nogo = 0;
% outcome code
% 2 - correct rejection, 1 - hit, 0 - timeout, -1 - false alarm, -2  miss
% Catch trials: 3 - animal made 'GO' response but not rewarded,
% 4 - animal made 'GO' response and was rewarded
% -3 - animal made 'NO GO' response

handles.output = hObject;
guidata(hObject, handles);


function varargout = behavior_gui_OutputFcn(hObject, eventdata, handles)

varargout{1} = handles.output;


function preview_button_Callback(hObject, eventdata, handles)
global gB
if hObject.Value == 1
    set(hObject,'BackgroundColor',[0 1 0]);
    axes(handles.vid_axes);
    gB.hImage = image(zeros(240,320,3));
    setappdata(gB.hImage,'UpdatePreviewWindowFcn',@mypreview_fcn);
    set(handles.status_text,'String','Previewing...');
    preview(gB.vid,gB.hImage);
else
    set(hObject,'BackgroundColor',[0.94 0.94 0.94]);
    set(handles.status_text,'String','Closed Preview.');
    closepreview(gB.vid);
end


function baseline_button_Callback(hObject, eventdata, handles)
global gB
if get(handles.preview_button,'Value') == 1 % is currently previewing
    set(handles.preview_button,'BackgroundColor',[0.94 0.94 0.94]);
    set(handles.preview_button,'Value',0);
    gB.bkgImg = imcomplement(gB.bkgImg);
    imagesc(handles.vid_axes,gB.bkgImg); axis off
    closepreview(gB.vid);
    set(handles.status_text,'String','Got background image.');
    rectangle('Position',[gB.home(1,1) gB.home(2,1) ...
        gB.home(1,3)-gB.home(1,2) gB.home(2,2) - gB.home(2,1)], ...
        'EdgeColor','y');
    rectangle('Position',[gB.right(1,2) gB.right(2,2) ...
        gB.right(1,3)-gB.right(1,2) gB.right(2,1) - gB.right(2,2)], ...
        'EdgeColor','r');
    rectangle('Position',[gB.left(1,2) gB.left(2,2) ...
        gB.left(1,3)-gB.left(1,2) gB.left(2,1) - gB.left(2,2)], ...
        'EdgeColor','b');
else
    disp('Must be Previewing to capture background image')
end


function start_button_Callback(hObject, eventdata, handles)
global gB

% determine task type
if get(findobj('Tag','gonogo_button'),'Value')
    gB.TaskType = 1;
elseif get(findobj('Tag','afc_button'),'Value')
    cprintf([1 0 1],'*** 2AFC NOT YET IMPLEMENTED\n');
    set(findobj('Tag','gonogo_button'),'Value',1);
    gB.TaskType = 1;
else
    disp('Unknown Task Type')
    return
end

% start Finite State Machine
while 1
    fr_tic = tic;
    switch gB.State
        % %%%%%%%%%%%%%% STARTING NEW VIDEO
        case -1 
            if isempty(gB.targfilelist) || isempty(gB.distrfilelist)
                cprintf([1 0 1],'*** Select Target and Distractor Files to Start\n');
                return;
            else
                set(handles.status_text,'String','Resampling and normalizing stimuli...'); drawnow
                % get all RMS values  
                if ~gB.hascatchtrials
                    stimrms = zeros(numel(gB.stimuli{1})+numel(gB.stimuli{2}),1);
                else
                    stimrms = zeros(numel(gB.stimuli{1})+numel(gB.stimuli{2})+numel(gB.stimuli{3})+numel(gB.stimuli{4}),1);
                end
                count = 1;
                for i = 1:1:numel(gB.stimuli{1})         
                    [p,q] = rat(44100/gB.Fs{1}(i),0.0001); % resample to 44.1K
                    gB.stimuli{1}{i} = resample(gB.stimuli{1}{i},p,q);
                    gB.Fs{1}(i) = 44100;
                    stimrms(count) = rms(gB.stimuli{1}{i}(:));
                    count = count+1;
                end
                for i = 1:1:numel(gB.stimuli{2})
                    [p,q] = rat(44100/gB.Fs{2}(i),0.0001); % resample to 44.1K
                    gB.stimuli{2}{i} = resample(gB.stimuli{2}{i},p,q);
                    gB.Fs{2}(i) = 44100;
                    stimrms(count) = rms(gB.stimuli{2}{i}(:));
                    count = count+1;
                end
                if gB.hascatchtrials
                    for i = 1:1:numel(gB.stimuli{3})
                        [p,q] = rat(44100/gB.Fs{3}(i),0.0001); % resample to 44.1K
                        gB.stimuli{3}{i} = resample(gB.stimuli{3}{i},p,q);
                        gB.Fs{3}(i) = 44100;
                        stimrms(count) = rms(gB.stimuli{3}{i}(:));
                        count = count+1;
                    end
                    for i = 1:1:numel(gB.stimuli{4})
                        [p,q] = rat(44100/gB.Fs{4}(i),0.0001); % resample to 44.1K
                        gB.stimuli{4}{i} = resample(gB.stimuli{4}{i},p,q);
                        gB.Fs{4}(i) = 44100;
                        stimrms(count) = rms(gB.stimuli{4}{i}(:));
                        count = count+1;
                    end
                end
                disp(stimrms)
                figure; histogram(20*log10(stimrms/mean(stimrms)),-6:0.5:6); hold on
                
                % normalize and get max
                if ~gB.hascatchtrials
                    maxstim =  zeros(numel(gB.stimuli{1})+numel(gB.stimuli{2}),1);
                else
                    maxstim =  zeros(numel(gB.stimuli{1})+numel(gB.stimuli{2})+numel(gB.stimuli{3})+numel(gB.stimuli{4}),1);
                end
                count = 1;
                for i = 1:1:numel(gB.stimuli{1})
                    gB.stimuli{1}{i} = gB.stimuli{1}{i} * max(stimrms)/stimrms(count);
                    maxstim(count) = max(gB.stimuli{1}{i});
                    count = count+1;
                end
                for i = 1:1:numel(gB.stimuli{2})
                    gB.stimuli{2}{i} = gB.stimuli{2}{i} * max(stimrms)/stimrms(count);
                    maxstim(count) = max(gB.stimuli{2}{i});
                    count = count+1;
                end
                if gB.hascatchtrials
                    for i = 1:1:numel(gB.stimuli{3})
                        gB.stimuli{3}{i} = gB.stimuli{3}{i} * max(stimrms)/stimrms(count);
                        maxstim(count) = max(gB.stimuli{3}{i});
                        count = count+1;
                    end
                    for i = 1:1:numel(gB.stimuli{4})
                        gB.stimuli{4}{i} = gB.stimuli{4}{i} * max(stimrms)/stimrms(count);
                        maxstim(count) = max(gB.stimuli{4}{i});
                        count = count+1;
                    end
                end
                
                % finally normalize peaks and measure new rms
                if ~gB.hascatchtrials
                    stimrms2 = zeros(numel(gB.stimuli{1})+numel(gB.stimuli{2}),1);
                else
                    stimrms2 = zeros(numel(gB.stimuli{1})+numel(gB.stimuli{2})+numel(gB.stimuli{3})+numel(gB.stimuli{4}),1);
                end
                count = 1;
                for i = 1:1:numel(gB.stimuli{1})
                    gB.stimuli{1}{i} = gB.stimuli{1}{i}/max(maxstim);
                    stimrms2(count) = rms(gB.stimuli{1}{i}(:));
                    count = count+1;
                end
                for i = 1:1:numel(gB.stimuli{2})
                    gB.stimuli{2}{i} = gB.stimuli{2}{i}/max(maxstim);
                    stimrms2(count) = rms(gB.stimuli{2}{i}(:));
                    count = count+1;
                end
                if gB.hascatchtrials
                    for i = 1:1:numel(gB.stimuli{3})
                        gB.stimuli{3}{i} = gB.stimuli{3}{i}/max(maxstim);
                        stimrms2(count) = rms(gB.stimuli{3}{i}(:));
                        count = count+1;
                    end
                    for i = 1:1:numel(gB.stimuli{4})
                        gB.stimuli{4}{i} = gB.stimuli{4}{i}/max(maxstim);
                        stimrms2(count) = rms(gB.stimuli{4}{i}(:));
                        count = count+1;
                    end
                end
                disp(stimrms2)
                histogram(20*log10(stimrms2/mean(stimrms2)),-1:0.01:1); drawnow
            end
                        
            set(handles.status_text,'String','Initializing video...'); drawnow
            % check that preview is off, if not, switch off
            if get(handles.preview_button,'Value') == 1 % is currently previewing
                set(handles.preview_button,'BackgroundColor',[0.94 0.94 0.94]);
                set(handles.preview_button,'Value',0);
                closepreview(gB.vid);
            end
            start(gB.vid);% video is started
            
            % start displaying video and bounding boxes
            axes(handles.vid_axes)
            gB.hImage = imagesc(handles.vid_axes,gB.bkgImg); colormap('gray'); axis off
            rectangle('Position',[gB.home(1,1) gB.home(2,1) ...
                gB.home(1,3)-gB.home(1,2) gB.home(2,2) - gB.home(2,1)], ...
                'EdgeColor','y');
            rectangle('Position',[gB.right(1,2) gB.right(2,2) ...
                gB.right(1,3)-gB.right(1,2) gB.right(2,1) - gB.right(2,2)], ...
                'EdgeColor','r');
            rectangle('Position',[gB.left(1,2) gB.left(2,2) ...
                gB.left(1,3)-gB.left(1,2) gB.left(2,1) - gB.left(2,2)], ...
                'EdgeColor','b');
            gB.hAL=animatedline(handles.vid_axes,0,0,'Color','g', ...
                'Marker','.','MaximumNumPoints',100);
            outputSingleScan(gB.dio,[0 0 0 0]); % make sure air puff is off
            gB.trials = [];
            gB.State = 0;
            gB.stopped = 0; gB.paused=0;
            gB.ntrials = 0;
            gB.hit = 0;
            gB.fa = 0;
            gB.cr = 0;
            gB.miss = 0;
            gB.catch_go = 0;
            gB.catch_nogo = 0;
            if ~gB.hascatchtrials
            dispstr = sprintf('Session stats\n\n N trials: %d \n Hits: %d\n FAs: %d \n Miss: %d \n CRs: %d ', ...
                    gB.ntrials,gB.hit, gB.fa,gB.miss,gB.cr);
            elseif gB.hascatchtrials
                dispstr = sprintf('Session stats\n\n N trials: %d \n Hits: %d\n FAs: %d \n Miss: %d \n CRs: %d \n Catch_Go: %d \n Catch_Nogo: %d', ...
                    gB.ntrials,gB.hit, gB.fa,gB.miss,gB.cr,gB.catch_go,gB.catch_nogo);
            end
            set(findobj('Tag','stats_txt'),'String', dispstr);
            
        % %%%%%%%%%%%%%%%%% WAITING FOR ANIMAL TO ENTER HOME BASE
        case 0 
            gB.t1 = NaN; set(handles.outcome_txt,'Visible','Off');
             [x,y] = getCurrentLocation;
            addpoints(gB.hAL,x,y); drawnow update            
            set(handles.status_text,'String','Waiting for animal to enter home base...');
            
            % check if animal is in polygon
            if inpolygon(x,y,gB.home(1,:),gB.home(2,:))
                gB.t1 = datevec(now); % home base entry time                
                gB.t0 = tic; t1 = tic;
                gB.State = 1;
                % how long to wait before stimulus this trial
                gB.thisTrialTime = gB.TrialInitTimeMin + ...
                    (gB.TrialInitTimeMax-gB.TrialInitTimeMin)*rand; % seconds                
            end
            
        % %%%%%%%%%%%%%%%%%%%% WAITING FOR TRIAL INITIATION    
        case 1 
            % get current position
            [x,y] = getCurrentLocation;
            addpoints(gB.hAL,x,y); drawnow update
            
            % animal inside home base
            if inpolygon(x,y,gB.home(1,:),gB.home(2,:))
                if toc(t1) <=gB.thisTrialTime
                    gB.State = 1; % time not elapsed, stay here      
                    set(handles.status_text,'String','Waiting to present stimulus...');
                else
                    gB.State = 2; % animal stayed long enough, present stim
                end
            else % animal left home base
                set(handles.status_text,'String','Animal left home base.');
                if gB.TimeoutIfNotWaiting && gB.TimeoutDuration>0
                   outputSingleScan(gB.dio,[0 0 1]);
                   set(handles.status_text,'String','TIMEOUT - Not tracking.');
                   pause(gB.TimeoutDuration-0.5);
                   outputSingleScan(gB.dio,[0 0 0 0]);
                end
                pause(0.5); %allow camera to adjust
                gB.State = 0;                
                drawnow
            end
                      
        % %%%%%%%%%%%%%%%%%%%%%% PRESENTING STIMULUS
        case 2            
            % set up the current trial
            gB.ntrials = gB.ntrials+1;
            if ~gB.stimlistspecified
                if rand <= gB.TargProb
                    gB.thistrialtype = 1;
                    thistrialstim = randperm(numel(gB.targfilelist));
                    gB.thistrialstim = thistrialstim(1);
                    set(handles.status_text,'String','Presenting target stimulus...');
                    drawnow
                else
                    gB.thistrialtype = 2;
                    thistrialstim = randperm(numel(gB.distrfilelist));
                    gB.thistrialstim = thistrialstim(1);
                    set(handles.status_text,'String','Presenting distractor stimulus...');
                    drawnow
                end
            else
                gB.thistrialtype = gB.stimlist(gB.ntrials,1);
                gB.thistrialstim = gB.stimlist(gB.ntrials,2);
                if gB.thistrialtype==1
                    set(handles.status_text,'String','Presenting target stimulus...');
                elseif gB.thistrialtype==2
                    set(handles.status_text,'String','Presenting distractor stimulus...');
                else
                    set(handles.status_text,'String','Catch trial...');
                end
                drawnow
            end
            thistrialoutcome = 0;
            % PLAY STIMULUS
            gB.t2 = toc(gB.t0); % stim onset time
            t2 = tic;
            if gB.thistrialtype>0
            soundsc(gB.stimuli{gB.thistrialtype}{gB.thistrialstim}, ...
                gB.Fs{gB.thistrialtype}(gB.thistrialstim));
            elseif gB.thistrialtype == -1
                soundsc(gB.stimuli{3}{gB.thistrialstim}, ...
                gB.Fs{3}(gB.thistrialstim));
            elseif gB.thistrialtype == -2
                soundsc(gB.stimuli{4}{gB.thistrialstim}, ...
                gB.Fs{4}(gB.thistrialstim));
            end
            gB.State = 3;
            
        % %%%%%%%%%%%%%%%%%%%%% WAITING FOR ANIMAL TO RESPOND    
        case 3 
             % get current position
            [x,y] = getCurrentLocation;
            addpoints(gB.hAL,x,y); drawnow update
             
            % animal inside home base, response window open
            if inpolygon(x,y,gB.home(1,:),gB.home(2,:)) && ...
                toc(t2) <= gB.TimeoutTime
                    gB.State = 3; % animal staying in home base, time not elapsed     
                    set(handles.status_text,'String','Waiting for animal to respond...');
            
               
            % animal inside home base, response window closed        
            elseif inpolygon(x,y,gB.home(1,:),gB.home(2,:)) && ...
                toc(t2) > gB.TimeoutTime
                    gB.t3 = toc(gB.t0); t3 = tic;
                    if gB.TaskType == 1 && gB.thistrialtype == 2 % was NOGO stim
                        gB.State = 10; % correct rejection response                        
                    elseif gB.TaskType == 1 && gB.thistrialtype == 1 % was GO stim
                        gB.State = 11; % MISS - animal stayed for GO stims
                    elseif gB.TaskType == 1 && gB.thistrialtype <0 % was CATCH trial
                        gB.State = 14; % Catch animal nogo
                    elseif gB.TaskType == 2 % was 2AFC, timeout possible
                        gB.State = 25; % 2AFC timeout
                        set(handles.status_text,'String','Trial timed out.');
                    end
                    
            % animal left home base, response window open
            elseif  ~inpolygon(x,y,gB.home(1,:),gB.home(2,:)) && ...
                    toc(t2) <= gB.TimeoutTime% animal left home base
                gB.t3 = toc(gB.t0); t3 = tic;
                gB.State = 4; % animal responding
                set(handles.status_text,'String','Animal responding.');
                drawnow
            end
            
        % %%%%%%%%%%%%%%%%%%%%% EVALUATING RESPONSE
        case 4
            % get current position
            [x,y] = getCurrentLocation;
            addpoints(gB.hAL,x,y); drawnow update
            
            % GNG animal left home base, response time remaining
            if gB.TaskType == 1 % GO/NOGO TASK
                if gB.thistrialtype == 2 % was NOGO stim
                    gB.State = 12; % False Alarm even if you just left home
                elseif gB.thistrialtype == 1 && toc(t3) <= gB.ResponseTime
                    if gB.TargSide == 1 ...
                            && inpolygon(x,y,gB.left(1,:),gB.left(2,:))% was GO stim
                        gB.State = 13; % Hit response
                    elseif gB.TargSide == 2 ...
                            && inpolygon(x,y,gB.right(1,:),gB.right(2,:))% was GO stim
                        gB.State = 13; % Hit response
                    else % animal left home BUT went to wrong side - has until response time to correct
                        gB.State = 4;
                    end
                elseif  gB.thistrialtype == 1 && toc(t3) > gB.ResponseTime
                    gB.State = 11; % miss - animal did not make it to target area
                    
                elseif gB.thistrialtype<0 && toc(t3) <= gB.ResponseTime % CATCH TRIAL
                    if gB.TargSide == 1 ...
                            && inpolygon(x,y,gB.left(1,:),gB.left(2,:))
                        gB.State = 15; % Catch trial Go response
                    elseif gB.TargSide == 2 ...
                            && inpolygon(x,y,gB.right(1,:),gB.right(2,:))% was GO stim
                        gB.State = 15; % Catch trial Go response
                    else % animal left home BUT went to wrong side - has until response time to correct
                        gB.State = 4;
                    end
                elseif gB.thistrialtype <0 && toc(t3) > gB.ResponseTime
                    gB.State = 14; % Catch trial NoGo response
                end
                
                % 2AFC animal left home base, response time remaining
            elseif gB.TaskType == 2
                if toc(t3) <= gB.ResponseTime
                    if inpolygon(x,y,gB.left(1,:),gB.left(2,:)) && ...
                            gB.TargSide == 1 && gB.thistrialtype == 1
                        gB.State = 20; % correct response
                        set(handles.status_text,'String','Correct response.');
                        thistrialoutcome = 1;
                    elseif inpolygon(x,y,gB.right(1,:),gB.right(2,:)) && ...
                            gB.TargSide == 2 && gB.thistrialtype == 1
                        gB.State = 20; % correct response
                        set(handles.status_text,'String','Correct response.');
                        thistrialoutcome = 1;
                    elseif inpolygon(x,y,gB.left(1,:),gB.left(2,:)) && ...
                            gB.TargSide == 2 && gB.thistrialtype == 1
                        gB.State = 21; % wrong response
                        set(handles.status_text,'String','Incorrect response.');
                        thistrialoutcome = -1;
                    elseif inpolygon(x,y,gB.right(1,:),gB.right(2,:)) && ...
                            gB.TargSide == 1 && gB.thistrialtype == 1
                        gB.State = 21; % wrong response
                        set(handles.status_text,'String','Incorrect response.');
                        thistrialoutcome = -1;
                        
                    elseif inpolygon(x,y,gB.left(1,:),gB.left(2,:)) && ...
                            gB.TargSide == 1 && gB.thistrialtype == 2
                        gB.State = 21; % wrong response
                        set(handles.status_text,'String','Incorrect response.');
                        thistrialoutcome = -1;
                    elseif inpolygon(x,y,gB.right(1,:),gB.right(2,:)) && ...
                            gB.TargSide == 2 && gB.thistrialtype == 2
                        gB.State = 21; % wrong response
                        set(handles.status_text,'String','Incorrect response.');
                        thistrialoutcome = -1;
                    elseif inpolygon(x,y,gB.left(1,:),gB.left(2,:)) && ...
                            gB.TargSide == 2 && gB.thistrialtype == 2
                        gB.State = 20; % Correct response
                        set(handles.status_text,'String','Correct response.');
                        thistrialoutcome = 1;
                    elseif inpolygon(x,y,gB.right(1,:),gB.right(2,:)) && ...
                            gB.TargSide == 1 && gB.thistrialtype == 2
                        gB.State = 20; % correct response
                        set(handles.status_text,'String','Correct response.');
                        thistrialoutcome = 1;
                        
                    else
                        gB.State = 4; % no response yet
                    end
                elseif toc(t3)>gB.ResponseTime
                    gB.State = 25; % 2AFC timeout
                    thistrialoutcome = 0;
                end
            end
        
        % %%%%%%%%%%%%%%%%%%%%% GO/NO-GO OUTCOMES
        case 10 % correct rejection - nothing happens
            thistrialoutcome = 2; % correct rejection
            gB.cr = gB.cr+1;
            set(handles.status_text,'String','Animal NOGO: Correct rejection.');
            set(handles.outcome_txt,'String','Correct rejection','FontSize',14, ...
                'FontWeight','normal','ForegroundColor',[0.51 0.93 0.51],'Visible','On');
            gB.t4 = toc(gB.t0);
            %soundsc(gB.ding,44100);
            pause(0.5);
            gB.State = 50; 
            
        case 11 % miss - nothing happens or airpuff at home
            set(handles.status_text,'String','Animal NOGO: Miss.');
            set(handles.outcome_txt,'String','Miss','FontSize',14, ...
                'FontWeight','normal','ForegroundColor',[0.93 0.51 0.64],'Visible','On');
            thistrialoutcome = -2; % miss
            gB.miss = gB.miss+1;
            gB.t4 = toc(gB.t0);
            %soundsc(gB.buzz,44100);
            if gB.TimeoutForMiss && gB.TimeoutDuration>0 % lights out
                outputSingleScan(gB.dio,[0 0 1]);
                set(handles.status_text,'String','TIMEOUT - Not tracking.');
                pause(gB.TimeoutDuration-0.5);
                outputSingleScan(gB.dio,[0 0 0 0]);
            end
            pause(0.5); % allow camera to adjust
            gB.State = 50;
            % home air puff?
            
        case 12 % false alarm - airpuff
            set(handles.status_text,'String','Animal GO: False Alarm.');
            set(handles.outcome_txt,'String','FALSE ALARM - AIRPUFF','FontSize',14, ...
                'FontWeight','bold','ForegroundColor',[1 0 0],'Visible','On');
            % get current position
            [x,y] = getCurrentLocation;
            addpoints(gB.hAL,x,y); drawnow update
            
            if toc(t3) <= gB.AirpuffWaitTime
                    gB.State = 12; % animal left home, but not in reward area                
            else
                 gB.t4 = toc(gB.t0); 
                 %soundsc(gB.buzz,44100);
                 deliver_airpuff(0); % animal may have returnd, but airpuff anyway
                 thistrialoutcome = -1; % false alarm
                 gB.fa = gB.fa+1;
                 if gB.TimeoutDuration>0 % additional lights out
                     outputSingleScan(gB.dio,[0 0 1 0]);
                     set(handles.status_text,'String','TIMEOUT - Not tracking.');
                     pause(gB.TimeoutDuration-0.5);
                     outputSingleScan(gB.dio,[0 0 0 0]);
                 end
                 pause(0.5); %allow camera to adjust
                 gB.State = 50;
            end
            
        case 13 % hit - reward
            set(handles.status_text,'String','Animal GO: Hit.');
            set(handles.outcome_txt,'String','HIT - REWARD!','FontSize',14, ...
                'FontWeight','bold','ForegroundColor',[0.05 0.33 0.05],'Visible','On');
            thistrialoutcome = 1; % hit
            gB.hit = gB.hit+1;
            gB.t4 = toc(gB.t0); 
            %soundsc(gB.ding,44100);
            deliver_reward(gB.TargSide); % for now reward is manual  % 1 is left, 2 is right            
            gB.State = 50;
            
        case 14 % Catch trial NOGO
            set(handles.status_text,'String','Animal NOGO (Catch).');
            set(handles.outcome_txt,'String','CATCH - NOGO','FontSize',14, ...
                'FontWeight','bold','ForegroundColor',[1 0.5 0],'Visible','On');
            thistrialoutcome = -3; % Catch NoGo
            gB.catch_nogo = gB.catch_nogo+1;
            gB.t4 = toc(gB.t0);                         
            gB.State = 50;
            
        case 15 % Catch trial GO
            set(handles.status_text,'String','Animal GO (Catch).');
            if rand<=0.5
                set(handles.outcome_txt,'String','CATCH_GO - REWARD!','FontSize',14, ...
                    'FontWeight','bold','ForegroundColor',[0.05 0.33 0.05],'Visible','On');
                thistrialoutcome = 4; % catch_go, was rewarded
                gB.catch_go = gB.catch_go+1;
                gB.t4 = toc(gB.t0);
                %soundsc(gB.ding,44100);
                deliver_reward(gB.TargSide); % for now reward is manual  % 1 is left, 2 is right
                gB.State = 50;
            else
                set(handles.outcome_txt,'String','CATCH_GO - NO REWARD!','FontSize',14, ...
                    'FontWeight','bold','ForegroundColor',[1 0.5 0],'Visible','On');
                thistrialoutcome = 3; % catch_go, was NOT rewarded
                gB.catch_go = gB.catch_go+1;
                gB.t4 = toc(gB.t0);
                %soundsc(gB.ding,44100);
                
                gB.State = 50;
            end
        
        % %%%%%%%%%%%%%%%%%%%%% 2AFC OUTCOMES NOT YET IMPLEMENTED
        case 20 % correct - food on correct side
            
        case 21 % incorrect - airpuff
            
        case 25 % timeout - nothing or lights off or airpuff at home
            
        
        % %%%%%%%%%%%%%%%%%%%%% LOG TRIAL RESULT    
        case 50
            gB.t5 = toc(gB.t0);
            gB.trials(gB.ntrials,1) = gB.thistrialtype;
            gB.trials(gB.ntrials,2) = gB.thistrialstim;            
            gB.trials(gB.ntrials,3) = thistrialoutcome;
            gB.trials(gB.ntrials,4:6) = gB.t1(4:6);
            gB.trials(gB.ntrials,7) = gB.t2;
            gB.trials(gB.ntrials,8) = gB.t3;
            gB.trials(gB.ntrials,9) = gB.t4;
            gB.trials(gB.ntrials,10) = gB.t5;
            if mod(gB.ntrials,10) == 0
                set(handles.status_text,'String','File saved.');
                save(fullfile(gB.savedir,gB.savefile),'gB'); % save file every 10 trials
            end
            
            % update stats
            if gB.TaskType == 1
                if ~gB.hascatchtrials
                    dispstr = sprintf('Session stats\n\n N trials: %d \n Hits: %d\n FAs: %d \n Miss: %d \n CRs: %d ', ...
                        gB.ntrials,gB.hit, gB.fa,gB.miss,gB.cr);
                elseif gB.hascatchtrials
                    dispstr = sprintf('Session stats\n\n N trials: %d \n Hits: %d\n FAs: %d \n Miss: %d \n CRs: %d \n Catch_Go: %d \n Catch_Nogo: %d', ...
                        gB.ntrials,gB.hit, gB.fa,gB.miss,gB.cr,gB.catch_go,gB.catch_nogo);
                end
                set(findobj('Tag','stats_txt'),'String', dispstr);
            end
            
            gB.State = 0;
       
    end
    if gB.paused
        set(handles.status_text,'String','PAUSED');
         set(gB.hAL,'Color',[1 0.5 0]);
         outputSingleScan(gB.dio,[0 0 0 0]);
       while(gB.paused)
            [x,y] = getCurrentLocation;           
            addpoints(gB.hAL,x,y); drawnow update           
           if ~get(handles.pause_button,'Value')
            set(hObject,'BackgroundColor',[0.94 0.94 0.94]);
            set(handles.status_text,'String','UN-PAUSED');
            set(gB.hAL,'Color',[0 1 0]);
            gB.paused = 0; gB.State = 0; 
           end
       end
    end
    if gB.stopped
        stop(gB.vid);
        outputSingleScan(gB.dio,[0 0 0 0]);
        gB.State = -1;
        set(handles.status_text,'String','File saved.');
        save(fullfile(gB.savedir,gB.savefile),'gB'); pause(1)
        set(handles.status_text,'String','Stopped video.'); drawnow
        break;
    end
          
    set(handles.state_txt,'String',num2str(gB.State));
    set(handles.hz_text,'String',[num2str(round(1/toc(fr_tic))) ' Hz']);
end


function deliver_reward(side)
global gB
% % IF SYRINGE
% % set digital out
% outputSingleScan(gB.dio,[0 0 0 1]);
% pause(0.1);
% outputSingleScan(gB.dio,[0 0 0 0]);
% outputSingleScan(gB.dio,[0 0 0 1]);
% pause(gB.RewardTime);
% outputSingleScan(gB.dio,[0 0 0 0]);
% drawnow

% IF PELLETS
outputSingleScan(gB.dio,[0 0 0 1]);
pause(0.1);
outputSingleScan(gB.dio,[0 0 0 0]);
drawnow


function syr_button_Callback(hObject, eventdata, handles)
global gB
% IF SYRINGE
% disp('Dispensing from Syringe...')
% %set(hObject,'String','DISPENSING')
% outputSingleScan(gB.dio,[0 0 0 1]);
% pause(0.1);
% outputSingleScan(gB.dio,[0 0 0 0]);
% outputSingleScan(gB.dio,[0 0 0 1]);
% pause(gB.RewardTime);
% outputSingleScan(gB.dio,[0 0 0 0]);
% %set(hObject,'String','Run Syringe')
% drawnow

% IF PELLETS
disp('Dispensing pellet...')
outputSingleScan(gB.dio,[0 0 0 1]);
pause(0.1);
outputSingleScan(gB.dio,[0 0 0 0]);
drawnow


function deliver_airpuff(side)
global gB
if side == 2
    outputSingleScan(gB.dio,[1 0 0 0]);
    pause(gB.AirpuffTime);
    outputSingleScan(gB.dio,[0 0 0 0]);
elseif side == 1
    outputSingleScan(gB.dio,[0 1 0 0]);
    pause(gB.AirpuffTime);
    outputSingleScan(gB.dio,[0 0 0 0]);
elseif side == 0
    outputSingleScan(gB.dio,[1 1 0 0]);
    pause(gB.AirpuffTime);
    outputSingleScan(gB.dio,[0 0 0 0]);
end


function airpuff_button_Callback(hObject, eventdata, handles)
global gB
disp('Manual air puff...')
outputSingleScan(gB.dio,[1 1 0 0]);
pause(gB.AirpuffTime);
outputSingleScan(gB.dio,[0 0 0 0]);
drawnow


function stop_button_Callback(hObject, eventdata, handles)
global gB
if gB.stopped ==0
    gB.stopped = 1;
end


function mypreview_fcn(obj,event,himage)
% Example update preview window function.
global gB
gB.bkgImg = event.Data;

% Display image data.
gB.hImage.CData = event.Data;


function [x,y] = getCurrentLocation
global gB
trigger(gB.vid);
thisFrame = imcomplement(getdata(gB.vid,1));
diffFrame = thisFrame-gB.bkgImg;
gB.hImage.CData = diffFrame;
diffFrame(diffFrame<gB.Threshold) = 0;
diffFrame(diffFrame>=gB.Threshold) = 1; %binarize difference Frame

[r, c] = find(diffFrame == 1);
x = mean(c); y = mean(r);


function animal_op_Callback(hObject, eventdata, handles)
global gB
gB.op = get(hObject,'String');


function animal_name_Callback(hObject, eventdata, handles)
global gB
gB.animal = get(hObject,'String');


function training_day_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<0) || (dummy>500)
    cprintf([1 0 1],'Behavior: Expecting numeric value >0 to 500\n');
    set(hObject,'String',num2str(gB.tday));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.tday = dummy;
end


function session_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<0) || (dummy>10)
    cprintf([1 0 1],'Behavior: Expecting numeric value >0 to 10\n');
    set(hObject,'String',num2str(gB.session));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.session = dummy;
end


function trial_init_min_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<0) || (dummy>10)
    cprintf([1 0 1],'Behavior: Expecting numeric value >0 to 10\n');
    set(hObject,'String',num2str(gB.TrialInitTimeMin));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.TrialInitTimeMin = dummy;
end


function trial_init_max_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<0) || (dummy>10)
    cprintf([1 0 1],'Behavior: Expecting numeric value >0 to 10\n');
    set(hObject,'String',num2str(gB.TrialInitTimeMax));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.TrialInitTimeMax = dummy;
end


function response_win_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<0) || (dummy>10)
    cprintf([1 0 1],'Behavior: Expecting numeric value >0 to 10\n');
    set(hObject,'String',num2str(gB.ResponseTime));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.ResponseTime = dummy;
end


function timeout_time_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<0) || (dummy>10)
    cprintf([1 0 1],'Behavior: Expecting numeric value >0 to 10\n');
    set(hObject,'String',num2str(gB.TimeoutTime));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.TimeoutTime = dummy;
end


function reward_time_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<0) || (dummy>9)
    cprintf([1 0 1],'Behavior: Expecting numeric value >0 to 9\n');
    set(hObject,'String',num2str(gB.RewardTime));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.RewardTime = dummy;
end


function airpuff_time_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<0) || (dummy>1)
    cprintf([1 0 1],'Behavior: Expecting numeric value >0 to 1\n');
    set(hObject,'String',num2str(gB.AirpuffTime));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.AirpuffTime = dummy;
end


function targ_prob_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<0) || (dummy>1)
    cprintf([1 0 1],'Behavior: Expecting numeric value >0 to 1\n');
    set(hObject,'String',num2str(gB.TargProb));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.TargProb = dummy;
end


function wait_air_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<0) || (dummy>1)
    cprintf([1 0 1],'Behavior: Expecting numeric value >0 to 1\n');
    set(hObject,'String',num2str(gB.AirpuffWaitTime));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.AirpuffWaitTime = dummy;
end


function targside_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<1) || (dummy>2)
    cprintf([1 0 1],'Behavior: Expecting numeric value 1 or 2\n');
    set(hObject,'String',num2str(gB.TargSide));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.TargSide = dummy;
end


function timeout_wait_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) || numel(find([0 1] == dummy))==0
    cprintf([1 0 1],'Behavior: Expecting logical value 0 or 1\n');
    set(hObject,'String',num2str(gB.TimeoutIfNotWaiting));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.TimeoutIfNotWaiting = dummy;
end


function timeout_miss_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) || numel(find([0 1] == dummy))==0
    cprintf([1 0 1],'Behavior: Expecting logical value 0 or 1\n');
    set(hObject,'String',num2str(gB.TimeoutForMiss));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.TimeoutForMiss = dummy;
end


function timeout_dur_box_Callback(hObject, eventdata, handles)
global gB
dummy = str2double(get(hObject,'String'));
if isnan(dummy) ||(dummy<0) || (dummy>10)
    cprintf([1 0 1],'Behavior: Expecting numeric value 0 to 10\n');
    set(hObject,'String',num2str(gB.TimeoutDuration));
    set(hObject,'BackgroundColor',[0.99 0.92 0.92]);
else
    set(hObject,'BackgroundColor',[1 1 1]);
    gB.TimeoutDuration = dummy;
end


function target_dir_button_Callback(hObject, eventdata, handles)
global gB
[fnames,pname] = uigetfile('*.wav','Select Target/GO files','MultiSelect','on');
if isequal(pname,0)
    disp('User pressed cancel'); return
else
    if ~iscell(fnames)
        fnames = {fnames};
    end
    disp(['User selected ', pname]);
    set(findobj('Tag','target_dir_text'),'String',pname);
    gB.stimuli{1} = {}; gB.targfilelist = {};
    for i = 1:1:numel(fnames)
        gB.targfilelist{i} = fullfile(pname,fnames{i});
        [gB.stimuli{1}{i}, gB.Fs{1}(i)] = audioread(gB.targfilelist{i});
    end
    gB.stimlistspecified = 0;
    gB.stimlist = [];gB.liststart = NaN; gB.listend = NaN;
end


function distr_dir_button_Callback(hObject, eventdata, handles)
global gB
[fnames,pname] = uigetfile('*.wav','Select Distractor/NO-GO files','MultiSelect','on');
if isequal(pname,0)
    disp('User pressed cancel'); return
else
    if ~iscell(fnames)
        fnames = {fnames};
    end
    disp(['User selected ', pname]);
    set(findobj('Tag','distr_dir_text'),'String',pname);
    gB.stimuli{2} = {}; gB.distrfilelist = {};
    for i = 1:1:numel(fnames)
        gB.distrfilelist{i} = fullfile(pname,fnames{i});
        [gB.stimuli{2}{i}, gB.Fs{2}(i)] = audioread(gB.distrfilelist{i});
    end
    gB.stimlistspecified = 0;
    gB.stimlist = [];gB.liststart = NaN; gB.listend = NaN;
end


function stimlist_button_Callback(hObject, eventdata, handles)
global gB
[fname,pname] = uigetfile('*.mat','Select Stimulus List');
if isequal(pname,0)
    disp('User pressed cancel'); return
else
    gB.stimlistspecified = 1;
    load(fullfile(pname,fname));
    
    % load target files
    gB.targfilelist = {}; gB.stimuli{1} = {};
    for i = 1:1:numel(target_files)
        gB.targfilelist{i} = target_files{i};
        [gB.stimuli{1}{i}, gB.Fs{1}(i)] = audioread(gB.targfilelist{i});
    end
    
    % load distractor files
    gB.distrfilelist = {}; gB.stimuli{2} = {};
    for i = 1:1:numel(distr_files)
        gB.distrfilelist{i} = distr_files{i};
        [gB.stimuli{2}{i}, gB.Fs{2}(i)] = audioread(gB.distrfilelist{i});
    end
    
    if exist('catch1_files','var')
        gB.hascatchtrials = 1;
     % load catch1 trial files
     gB.catch1_filelist = {}; gB.stimuli{3} = {};
     for i = 1:1:numel(catch1_files)
         gB.catch1_filelist{i} = catch1_files{i};
         [gB.stimuli{3}{i}, gB.Fs{3}(i)] = audioread(gB.catch1_filelist{i});
     end
     
     % load catch2 trial files
     gB.catch2_filelist = {}; gB.stimuli{4} = {};
     for i = 1:1:numel(catch2_files)
         gB.catch2_filelist{i} = catch2_files{i};
         [gB.stimuli{4}{i}, gB.Fs{4}(i)] = audioread(gB.catch2_filelist{i});
     end
    else
        gB.hascatchtrials=0;
    end
    
    % now choose range
    %gB.stimlist = stimlist;
    gB.liststart = NaN; gB.listend = NaN;
    lo = 0;
    while lo<=0 || lo>size(stimlist,1)
        lo = input('Enter starting index: ');
    end
    hi = 0;
    while hi<=lo || hi>size(stimlist,1)
        hi = input('Enter ending index: ');
    end
    gB.liststart = lo; gB.listend = hi;
    gB.stimlist = stimlist(lo:hi,2:3);
end


function savefile_button_Callback(hObject, eventdata, handles)
global gB
gB.savedir = uigetdir('F:\DATA\BEHAVIOR\');
gB.savefile = [gB.animal '_' datestr(now,30) '_Day' sprintf('%0.2d',gB.tday) ...
    '_Sess' sprintf('%0.2d',gB.session) '.mat'];
set(handles.savefile_txt,'String',fullfile(gB.savedir,gB.savefile));


function pause_button_Callback(hObject, eventdata, handles)
global gB
if hObject.Value == 1
    set(hObject,'BackgroundColor',[1 0.5 0]);
    set(handles.status_text,'String','PAUSED');
    if gB.State >= 2 % if trial counter has incremented
        gB.ntrials = gB.ntrials - 1;
    end
    gB.paused=1;
else
    set(hObject,'BackgroundColor',[0.94 0.94 0.94]);
    set(handles.status_text,'String','UN-PAUSED');
    gB.paused = 0;
end


% %%%%%%%%%%%%%%%%%%%%
function animal_name_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function animal_op_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function trial_init_min_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function trial_init_max_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function response_win_box_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function timeout_time_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function reward_time_box_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function airpuff_time_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function targ_prob_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function training_day_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function targside_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function session_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function wait_air_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function timeout_dur_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function timeout_wait_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function timeout_miss_box_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
