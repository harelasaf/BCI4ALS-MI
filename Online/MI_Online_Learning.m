%function MI_Online_Learning(recordingFolder)
%% MI Online Scaffolding
% This code creates an online EEG buffer which utilizes the model trained
% offline, and corresponding conditions, to classify between the possible labels.
% Furthermore, this code adds an "online learning" phase in which the
% subject is shown a specific label which she/he should imagine. After a
% defined amount of labeled trials, the classifier is updated.

% Assuming: 
% 1. EEG is recorded using openBCI and streamed through LSL.
% 2. A preliminary MI classifier has been trained.
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
% 4. Add a serial classifier which predicts attention levels and updates
% the classifier only if "focus" is above a certain threshold.

%% This code is part of the BCI-4-ALS Course written by Asaf Harel
% (harelasa@post.bgu.ac.il) in 2021. You are free to use, change, adapt and
% so on - but please cite properly if published.

clearvars % change to clear all?
close all
clc

%% Addpath for relevant folders - original recording folder and LSL folders
addpath('YOUR RECORDING FOLDER PATH HERE');
addpath('YOUR LSL FOLDER PATH HERE');
    
%% Set params - %add to different function/file returns param.struct
params = set_params();
load('releventFeatures.mat');                       % load best features from extraction & selection stage
load('trainedModel.mat');                           % load model weights from offline section
% Load cue images
images{1} = imread(params.leftImageName, 'jpeg');
images{2} = imread(params.squareImageName, 'jpeg');
images{3} = imread(params.rightImageName, 'jpeg');
cueVec = prepareTraining(numTrials,numConditions);  % prepare the cue vector

%% Lab Streaming Layer Init
[command_Outlet, EEG_Inlet] = LSL_Init;

%% Initialize some more variables:
myPrediction = [];                                  % predictions vector
myBuffer = [];                                      % buffer matrix
iteration = 0;                                      % iteration counter
motorData = [];                                     % post-laPlacian matrix
decCount = 0;                                       % decision counter

%% 
pause(params.bufferPause);                          % give the system some time to buffer data
myChunk = EEG_Inlet.pull_chunk();                   % get a chunk from the EEG LSL stream to get the buffer going

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

%% This is the main online script

for trial = 1:numTrials
    command_Outlet.push_sample(params.startTrialMarker)
    currentClass = cueVec(trial);
    % ready cue
    text(0.5,0.5 , 'Ready',...
        'HorizontalAlignment', 'Center', 'Color', 'white', 'FontSize', 40);        
    pause(params.readyLength)
    % display target cue
    image(flip(images{currentClass}, 1)  'XData', [0.25, 0.75],...
        'YData', [0.25, 0.75 * ...
        size(images{currentClass},1) ./ size(images{currentClass},2)])
    pause(params.cueLength);                           % Pause for cue length
    cla                                         % Clear axis
    % ready cue
    text(0.5,0.5 , 'Ready',...
        'HorizontalAlignment', 'Center', 'Color', 'white', 'FontSize', 40);        
    pause(params.readyLength)
    
    trialStart = tic;
    while toc(trialStart) < trialTime
        iteration = iteration + 1;                  % count iterations
        
        myChunk = EEG_Inlet.pull_chunk();           % get data from the inlet

        pause(0.1)
        % check if myChunk is empty and print status, also
        % apply LaPlacian filter on current chunk of data and apped to
        % local buffer:
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
            
            % Update classifier - this should be done very gently! 
            if final_vote ~= (cueVec(trial)-numConditions-1)
                wrongClass(decCount,:,:) = EEG_Features;
                wrongClassLabel(decCount) = cueVec(trial);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% Write a function that updates the trained model %%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                trainedModel = OnlineLearn(trainedModel,EEG_Features,currentClass);
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
disp('Finished')
command_Outlet.pushSample(params.endTrial);
