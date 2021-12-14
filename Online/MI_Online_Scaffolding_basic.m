%function MI_OnlineClassification_Scaffolding2(recordingFolder)
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
% 2. Add an online learn-with-feedback mechanism where there is a cue to
% one side (or idle) with a confidence bar showing the classification being
% made.

clearvars
close all
clc

%% Addpath for relevant folders - original recording folder and LSL folders
addpath('YOUR RECORDING FOLDER PATH HERE');
addpath('YOUR LSL FOLDER PATH HERE');
    
%% Set params
feedbackFlag = 1;                                   % 1-with feedback, 0-no feedback
% Fs = 300;                                         % Wearable Sensing sample rate
Fs = 125;                                           % openBCI sample rate
bufferLength = 5;                                   % how much data (in seconds) to buffer for each classification
% numVotes = 3;                                     % how many consecutive votes before classification?
load(strcat(recordingFolder,'releventFreqs.mat'));  % load best features from extraction & selection stage
load(strcat(recordingFolder,'trainedModel.mat'));   % load model weights from offline section
numConditions = 3;                                  % possible conditions - left/right/idle 


%% Lab Streaming Layer Init
disp('Loading the Lab Streaming Layer library...');
lib = lsl_loadlib();
% Initialize the command outlet marker stream
disp('Opening Output Stream...');
info = lsl_streaminfo(lib,'MarkerStream','Markers',1,0,'cf_string','asafMIuniqueID123123');
command_Outlet = lsl_outlet(info);

% Initialize the EEG inlet stream (from DSI2LSL/openBCI on different system)
disp('Resolving an EEG Stream...');
result = {};
while isempty(result)
    result = lsl_resolve_byprop(lib,'type','EEG'); 
end
disp('Success resolving!');
EEG_Inlet = lsl_inlet(result{1});

%% Initialize some more variables:
myPrediction = [];                                  % predictions vector
myBuffer = [];                                      % buffer matrix
iteration = 0;                                      % iteration counter
motorData = [];                                     % post-laPlacian matrix
decInd = 0;                                         % decision counter

pause(0.2);                                         % give the system some time to buffer data
myChunk = EEG_Inlet.pull_chunk();                   % get a chunk from the EEG LSL stream to get the buffer going

%% This is the main online script

while true                                          % run continuously
    iteration = iteration + 1;                      % count iterations
    myChunk = EEG_Inlet.pull_chunk();               % get data from the inlet
    
    % next 2 lines are relevant for Wearable Sensing only:
%     myChunk = myChunk - myChunk(21,:);              % re-reference to ear channel (21)
%     myChunk = myChunk([1:15,18,19,22:23],:);        % removes X1,X2,X3,TRG,A2    
    
    pause(0.1)
    if ~isempty(myChunk)
        % Apply LaPlacian Filter (based on default electrode placement)
        motorData(1,:) = myChunk(2,:) - ((myChunk(8,:) + myChunk(3,:) + myChunk(1,:) + myChunk(13,:))./4);    % LaPlacian (Cz, F3, P3, T3)
        motorData(2,:) = myChunk(6,:) - ((myChunk(8,:) + myChunk(5,:) + myChunk(7,:) + myChunk(19,:))./4);    % LaPlacian (Cz, F4, P4, T4)
        
        myBuffer = [myBuffer motorData];              % append new data to the current buffer
        motorData = [];
    else
        disp(strcat('Houston, we have a problem. Iteration:',num2str(iteration),' did not have any data.'));
    end
    
    % Check if buffer size exceeds the buffer length 
    if (size(myBuffer,2)>(bufferLength*Fs))
        decInd = decInd + 1;
        block = [myBuffer];
        
        % Pre-process the data
        block = lowpass(block',40,Fs)';
        block = highpass(block',0.3,Fs)';
        
        % Extract features from the buffered block:
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% Add your feature extraction function from offline stage %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        EEG_Features = ExtractPowerBands(block,releventFeatures,Fs);

        % Predict using previously learned model:
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% Use whatever classfication method used in offline MI %%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        myPrediction(decInd) = trainedModel.predictFcn(EEG_Features);
        
        if feedbackFlag
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % write a function that plots estimate on some type of graph: %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            plotEstimate(myPrediction); hold on
        end
        disp(strcat('Iteration:', num2str(iteration)));
        disp(strcat('The estimated target is:', num2str(myPrediction(decInd))));        
       
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % write a function that sends the estimate to the voting machine %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        [final_vote] = sendVote(myEstimate);
        
        % Send command through LSL:
        command_Outlet.push_sample(final_vote);
        
        % clear buffer
        myBuffer = [];
    end
end

