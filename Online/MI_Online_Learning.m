%function MI_Online_Learning(recordingFolder)
%% MI Online Scaffolding
% This code creates an online EEG buffer which utilizes the model trained
% offline, and corresponding conditions, to classify between the possible labels.
% Assuming: 
% 1. EEG is recorded using Wearable Sensing / openBCI and streamed through LSL.
% 2. MI classifier has been trained
% 3. A different machine/client is reading this LSL oulet stream for the commands sent through this code
% 4. Target labels are [-1 0 1] (left idle right)

% Remaining to be done:
% 1. Add a "voting machine" which takes the classification and counts how
% many consecutive answers in the same direction / target to get a high(er)
% accuracy rate, even though it slows down the process by a large factor.
% 2. Add an online learn-with-feedback mechanism where there is a visual feedback to
% one side (or idle) with a confidence bar showing the classification being made.
% 3. Advanced = add an online reinforcement code that updates the
% classifier with the wrong & right class classifications.


clearvars % change to clear all?
close all
clc

%% Addpath for relevant folders - original recording folder and LSL folders
addpath('YOUR RECORDING FOLDER PATH HERE');
addpath('YOUR LSL FOLDER PATH HERE');
    
%% Set params - %add to different function/file returns param.struct
params = set_params();
load('releventFreqs.mat');                          % load best features from extraction & selection stage
load('trainedModel.mat');                           % load model weights from offline section
% Load cue images
images(1,:,:,:) = imread(params.leftImageName, 'jpeg');
images(2,:,:,:) = imread(params.squareImageName, 'jpeg');
images(3,:,:,:) = imread(params.rightImageName, 'jpeg');
cueVec = prepareTraining(numTrials,numConditions);  % prepare the cue vector

%% Lab Streaming Layer Init - FIXME turn into a seperate function
fprintf('Loading the Lab Streaming Layer library...');
lib = lsl_loadlib();
% Initialize the command outlet marker stream
fprintf('Opening Output Stream...');
info = lsl_streaminfo(lib,'MarkerStream','Markers',1,0,'cf_string','asafMIuniqueID123123');
command_Outlet = lsl_outlet(info);
% Initialize the EEG inlet stream (from DSI2LSL/openBCI on different system)
fprintf('Resolving an EEG Stream...');
result = {};
lslTimer = tic;
while isempty(result) && toc(lslTimer) < params.resolveTime % FIXME add some stopping condition
    result = lsl_resolve_byprop(lib,'type','EEG'); 
end
fprintf('Success resolving!');
EEG_Inlet = lsl_inlet(result{1});

%% Initialize some more variables:
myPrediction = [];                                  % predictions vector
myBuffer = [];                                      % buffer matrix
iteration = 0;                                      % iteration counter
motorData = [];                                     % post-laPlacian matrix
decCount = 0;                                       % decision counter

%% 
pause(params.bufferPause);                                         % give the system some time to buffer data
myChunk = EEG_Inlet.pull_chunk();                   % get a chunk from the EEG LSL stream to get the buffer going

%% Psychtoolbox, Stim, Screen Params Init:
fprintf('Setting up Psychtoolbox parameters...');
fprintf('This will open a black screen - good luck!');
% This function will make the Psychtoolbox window semi-transparent:
PsychDebugWindowConfiguration(0,0.5);               % Use this to debug the psychtoolbox screen

[window,white,~,~,screenYpixels,~,~,ifi] = PsychInit();
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);                         % set highest priority for screen processes
vbl = Screen('Flip', window);                       % get the vertical beam line
% FIXME move to params:
waitFrames = 1;                                     % how many frames to wait for between screen refresh.

%% Define the keyboard keys that are listened for:
KbName('UnifyKeyNames');
escapeKey = KbName('Escape');                   % let psychtoolbox know what the escape key is
HideCursor;                                     % hides cursor on screen

%% This is the main online script

for trial = 1:numTrials
    
    Screen('TextSize', window, 70);             % Draw text in the bottom portion of the screen in white
    DrawFormattedText(window, 'Ready', 'center',screenYpixels * 0.75, white);
    Screen('Flip', window);
    pause(1.5);                                 % "Ready" stays on screen
    Screen('PutImage', window, squeeze(images(cueVec(trial),:,:,:))); % put image on screen
    Screen('Flip',window);                      % now visible on screen
    
    trialStart = tic;
    while toc(trialStart) < trialTime
        iteration = iteration + 1;                  % count iterations
        
        myChunk = EEG_Inlet.pull_chunk();           % get data from the inlet
        
        % FIXME - add through "switch" "case". 
        % next 2 lines are relevant for Wearable Sensing only:
        %     myChunk = myChunk - myChunk(21,:);              % re-reference to ear channel (21)
        %     myChunk = myChunk([1:15,18,19,22:23],:);        % removes X1,X2,X3,TRG,A2
        pause(0.1)
        % add comment explaining WTF below
        if ~isempty(myChunk)
            % Apply LaPlacian Filter (based on default electrode placement for Wearable Sensing - change it to your electrode locations)
            motorData(1,:) = myChunk(2,:) - ((myChunk(8,:) + myChunk(3,:) + myChunk(1,:) + myChunk(13,:))./4);    % LaPlacian (Cz, F3, P3, T3)
            motorData(2,:) = myChunk(6,:) - ((myChunk(8,:) + myChunk(5,:) + myChunk(7,:) + myChunk(16,:))./4);    % LaPlacian (Cz, F4, P4, T4)
            myBuffer = [myBuffer motorData];        % append new data to the current buffer
            motorData = [];
        else
            fprintf(strcat('Houston, we have a problem. Iteration:',num2str(iteration),' did not have any data.'));
        end
        
        % Check if buffer size exceeds the buffer length
        if (size(myBuffer,2)>(bufferLength*Fs))
            decCount = decCount + 1;            % decision counter
            block = [myBuffer];                 % move data to a "block" variable
            
            % Pre-process the data
            block = lowpass(block',40,Fs)';     % the lowpass frequency needs to match the training phase
            block = highpass(block',0.3,Fs)';   % the highpass frequency also needs to match the training phase
            
            % Extract features from the buffered block:
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%% Add your feature extraction function from offline stage %%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            EEG_Features = ExtractPowerBands(block,releventFeatures,Fs);
            
            % Predict using previously learned model:
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% Use whatever classfication method used in offline MI %%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            myPrediction(decCount) = trainedModel.predictFcn(EEG_Features);
            
            if feedbackFlag
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % write a function that plots estimate on some type of graph: %
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                plotEstimate(myPrediction); hold on
            end
            fprintf(strcat('Iteration:', num2str(iteration)));
            fprintf(strcat('The estimated target is:', num2str(myPrediction(decCount))));
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % write a function that sends the estimate to the voting machine %%
            %     the output should be between [-1 0 1] to match classes     %%
            %       this could look like a threshold crossing feedback       %%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            [final_vote] = sendVote(myPrediction);
            
            % Update classifier - this should be done very gently! (and
            % mostly relevent to neural nets.
            if final_vote ~= (cueVec(trial)-numConditions-1)
                wrongClass(decCount,:,:) = EEG_Features;
                wrongClassLabel(decCount) = cueVec(trial);
            else
                correctClass(decCount,:,:) = EEG_Features;
                correctLabel(decCount) = cueVec(trial);
                % Send command through LSL:
                command_Outlet.push_sample(final_vote);
            end
            
            % clear buffer
            myBuffer = [];
        end
    end
end
%% Update Classifier using wrongClass & correctClass labels
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% This is not trivial & depends on your classification  %%
%%           algorithm, "co-learning"                    %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rmpath - remove the added path from the beginning