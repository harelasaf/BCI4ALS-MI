%function MI_OnlineClassification_Scaffolding2(recordingFolder)
%% MI Online Scaffolding
% This code creates an online EEG buffer which utilizes the model trained
% offline, and corresponding conditions, to classify between the possible labels.
% Assuming:
% 1. EEG is recorded using openBCI and streamed through LSL.
% 2. MI classifier has been previously trained.
% 3. A different machine/client is reading the LSL oulet stream in this
% code for the these commands.
% 4. Target labels are [-1 0 1] (left idle right)

% Remains to be done:
% 1. Add a "voting machine" which takes the classification and counts how
% many consecutive answers in the same direction / target to get a high(er)
% accuracy rate, even though it slows down the process by a large factor.
% 2. Add an online learn-with-feedback mechanism where there is a cue to
% one side (or idle) with a confidence bar showing the classification being
% made.

%% This code is part of the BCI-4-ALS Course written by Asaf Harel
% (harelasa@post.bgu.ac.il) in 2021. You are free to use, change, adapt and
% so on - but please cite properly if published.

clearvars
close all
clc

%% Addpath for relevant folders - original recording folder and LSL folders
addpath('YOUR RECORDING FOLDER PATH HERE');
addpath('YOUR LSL FOLDER PATH HERE');
    
%% Set params
feedbackFlag = 1;                                   % 1-with feedback, 0-no feedback
Fs = 125;                                           % openBCI sample rate
bufferLength = 5;                                   % how much data (in seconds) to buffer for each classification
% numVotes = 3;                                     % how many consecutive votes before classification?
load('releventFeatures.mat');                       % load best features from extraction & selection stage
load('trainedModel.mat');                           % load model weights from offline stage
numConditions = 3;                                  % possible conditions - left/right/idle 


%% Lab Streaming Layer Init
disp('Loading the Lab Streaming Layer library...');
lib = lsl_loadlib();
% Initialize the command outlet marker stream
disp('Opening Output Stream...');
info = lsl_streaminfo(lib,'MarkerStream','Markers',1,0,'cf_string','asafMIuniqueID123123');
command_Outlet = lsl_outlet(info);

% Initialize the EEG inlet stream (from openBCI)
disp('Resolving an EEG Stream...');
result = {};
while isempty(result)
    result = lsl_resolve_byprop(lib,'type','EEG'); 
end
disp('Success resolving EEG stream!');
EEG_Inlet = lsl_inlet(result{1});

%% Initialize some more variables:
myPrediction = [];                                  % predictions vector
myBuffer = [];                                      % buffer matrix
iteration = 0;                                      % iteration counter
motorData = [];                                     % post-laPlacian matrix
decIdx = 0;                                         % decision index

pause(0.2);                                         % give the system some time to buffer data
myChunk = EEG_Inlet.pull_chunk();                   % get a chunk from the EEG LSL stream to get the buffer going
% the "EEG_Inlet.pull_chunk" command is useful for taking data that has been buffering in the LSL stream.
% If using .pull_sample command, a single sample (the last one in the pile)
% will be pulled into the "myChunk" variable.

%% This is the main online script

while true                                          % run continuously
    iteration = iteration + 1;                      % count iterations
    myChunk = EEG_Inlet.pull_chunk();               % get data from the inlet
    
    pause(0.1)
    if ~isempty(myChunk)                            % check if myChunk has any data
        % Apply LaPlacian Filter (based on default electrode placement)
        %%%%%% UPDATE THESE INDECES TO YOUR EEG SETUP %%%%%%%%
        motorData(1,:) = myChunk(2,:) - ((myChunk(8,:) + myChunk(3,:) + myChunk(1,:) + myChunk(13,:))./4);    % LaPlacian (Cz, F3, P3, T3)
        motorData(2,:) = myChunk(6,:) - ((myChunk(8,:) + myChunk(5,:) + myChunk(7,:) + myChunk(19,:))./4);    % LaPlacian (Cz, F4, P4, T4)
        % motorData now has only 2 channels after the LaPlacian filtering.
        myBuffer = [myBuffer motorData];            % append new data to the current buffer
        motorData = [];                             % clear motorData variable
    else
        % this means that the pull_chunk command didn't get any data:
        disp(strcat('Houston, we have a problem. Iteration:',num2str(iteration),' did not have any data.'));
    end
    
    % Check if buffer size exceeds the defined buffer length 
    if (size(myBuffer,2)>(bufferLength*Fs))
        decIdx = decIdx + 1;                        % increase decision counter.
        block = [myBuffer];                         % move data into "block" variable
        
        %%%%%% UPDATE FILTERS TO YOUR OWN %%%%%%%
        % Pre-process the data
        block = lowpass(block',40,Fs)';             % this filters the data from 0.3 to 40 Hz            
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
        myPrediction(decIdx) = trainedModel.predictFcn(EEG_Features);
        
        if feedbackFlag
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % write a function that plots estimate on some type of graph: %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            plotEstimate(myPrediction); hold on
        end
        disp(strcat('Iteration:', num2str(iteration)));
        disp(strcat('The estimated target is:', num2str(myPrediction(decIdx))));        
       

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % write a function that sends the estimate to the voting machine %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        [final_vote] = sendVote(decIdx,numVotes,myPrediction);
        
        % Send command through LSL:
        command_Outlet.push_sample(final_vote);
        
        % clear buffer
        myBuffer = [];
    end
end

