function [recordingFolder,subID] = MI1_offline_training()
%% MOTOR IMAGERY Training Scaffolding 
% This code creates a training paradigm with (#) classes on screen for
% (#) numTrials. Before each trial, one of the targets is cued (and remains
% cued for the entire trial).This code assumes EEG is recorded and streamed
% through LSL for later offline preprocessing and model learning.

%% This code is part of the BCI-4-ALS Course written by Asaf Harel
% (harelasa@post.bgu.ac.il) in 2021. You are free to use, change, adapt and
% so on - but please cite properly if published.

%% Make sure you have Lab Streaming Layer installed.
% Set parameters (these will need to change according to your system):
addpath('C:\Toolboxes\labstreaminglayer-master\LSL\liblsl-Matlab');     % lab streaming layer library
addpath('C:\Toolboxes\labstreaminglayer-master\LSL\liblsl-Matlab\bin'); % lab streaming layer bin

% Subject and recording parameters:
subID = input('Please enter subject ID/Name: ');    % prompt to enter subject ID or name
rootFolder = 'C:\Recordings\';                      % define recording folder location

% Define recording folder location and create the folder:
recordingFolder = strcat(rootFolder,'\Sub',num2str(subID),'\');
mkdir(recordingFolder);

% Define times
InitWait = 5;                           % before trials prep time
trialLength = 5;                        % each trial length in seconds 
cueLength = 1;                          % time for each cue
readyLength = 1;                        % time "ready" on screen
nextLength = 1;                         % time "next" on screen

% Define length and classes
numTrials = 10;                         % set number of training trials per class (the more classes, the more trials per class)
numClasses = 3;                         % set number of possible classes

% Set markers / triggers names
startRecordings = 000;          
startTrial = 1111;
Baseline = 1001;
Idle = 3;
Left = 1;
Right = 2;
endTrial = 9;
endRecrding = 99;

%% Lab Streaming Layer Init
disp('Loading the Lab Streaming Layer library...');
% Init LSL parameters
lib = lsl_loadlib();                    % load the LSL library
disp('Opening Marker Stream...');
% Define stream parameters
info = lsl_streaminfo(lib,'MarkerStream','Markers',1,0,'cf_string','myuniquesourceid23443');
outletStream = lsl_outlet(info);        % create an outlet stream using the parameters above
disp('Open Lab Recorder & check for MarkerStream and EEG stream, start recording, return here and hit any key to continue.');
pause;                                  % wait for experimenter to press a key

%% Screen Setup 
monitorPos = get(0,'MonitorPositions'); % monitor position and number of monitors
monitorN = size(monitorPos, 1);
choosenMonitor = 1;                     % which monitor to use TODO: make a parameter                                 
if choosenMonitor < monitorN            % if no 2nd monitor found, use the main monitor
    choosenMonitor = 1;
    disp('Another monitored is not detected, using main monitor.')
end
figurePos = monitorPos(choosenMonitor, :);  % get choosen monitor position
figure('outerPosition',figurePos);          % open full screen monitor
MainFig = gcf;                              % get the figure and axes handles
hAx  = gca;
set(hAx,'Unit','normalized','Position',[0 0 1 1]); % set the axes to full screen
set(MainFig,'menubar','none');              % hide the toolbar   
set(MainFig,'NumberTitle','off');           % hide the title
set(hAx,'color', 'black');                  % set background color
hAx.XLim = [0, 1];                          % lock axes limits
hAx.YLim = [0, 1];
hold on

%% Prepare Visual Cues - read the right/left/idle images
trainingImage{1} = imread('square.jpeg','jpeg');
trainingImage{2} = imread('arrow_left.jpeg','jpeg');
trainingImage{3} = imread('arrow_right.jpeg','jpeg');
    
%% Prepare Training Vector
trainingVec = prepareTraining(numTrials,numClasses);    % vector with the conditions for each trial
save(strcat(recordingFolder,'trainingVec.mat'),'trainingVec');

%% Record Training Stage
outletStream.push_sample(startRecordings);      % start of recordings. Later, reject all EEG data prior to this marker
totalTrials = length(trainingVec);
text(0.5,0.5 ,...                               % important for people to prepare
    ['System is calibrating.' newline 'The training session will begin shortly.'], ...
    'HorizontalAlignment', 'Center', 'Color', 'white', 'FontSize', 40);
pause(InitWait)
cla
for trial = 1:totalTrials
    outletStream.push_sample(startTrial);       % trial trigger & counter
    startTrial = startTrial + trial;    
    currentClass = trainingVec(trial);          % What class is it?
    
    % Cue before ready
    image(flip(trainingImage{currentClass}, 1), 'XData', [0.25, 0.75],...
        'YData', [0.25, 0.75 * ...
        size(trainingImage{currentClass},1)./ size(trainingImage{currentClass},2)])
    pause(cueLength);                           % Pause for cue length
    cla                                         % Clear axis
    
    % Ready
    text(0.5,0.5 , 'Ready',...
        'HorizontalAlignment', 'Center', 'Color', 'white', 'FontSize', 40);
    outletStream.push_sample(Baseline);         % Baseline trigger
    pause(readyLength);                         % Pause for ready length
    cla                                         % Clear axis
    
    % Show image of the corresponding label of the trial
    image(flip(trainingImage{currentClass}, 1), 'XData', [0.25, 0.75],...
        'YData', [0.25, 0.75 * ...
        size(trainingImage{currentClass},1)./ size(trainingImage{currentClass},2)])    
    outletStream.push_sample(currentClass);     % class label
    pause(trialLength)                          % Pause for trial length
    cla                                         % Clear axis

    % Display "Next" trial text
    text(0.5,0.5 , 'Next',...
        'HorizontalAlignment', 'Center', 'Color', 'white', 'FontSize', 40);
    % Display trial count
    text(0.5,0.2 , strcat('Trial #',num2str(trial + 1),' Out Of : '...
        ,num2str(totalTrials)),...
        'HorizontalAlignment', 'Center', 'Color', 'white', 'FontSize', 40);
    pause(nextLength);                          % Wait for next trial
    cla                                         % Clear axis
    
    outletStream.push_sample(endTrial);         % end of trial trigger
end

%% End of experiment
outletStream.push_sample(endRecrding);          % end of experiment trigger
disp('!!!!!!! Stop the LabRecorder recording!');

