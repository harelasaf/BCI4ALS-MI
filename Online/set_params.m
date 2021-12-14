function [params] = set_params()

% This function sets up the different parameters for the MI Online Learning

params.feedbackFlag = 1;            % 1-with feedback, 0-no feedback
params.Fs = 125;                    % openBCI sample rate % Fs = 300;  % Wearable Sensing sample rate
params.bufferLength = 5;            % how much data (in seconds) to buffer for each classification
params.numVotes = 3;                % how many consecutive votes before classification?
params.numConditions = 3;           % possible conditions - left/right/idle 
params.leftImageName = 'arrow_left.jpeg';
params.rightImageName = 'arrow_right.jpeg';
params.squareImageName = 'square.jpeg';
params.numTrials = 5;               % number of trials overall
params.trialTime = 240;             % duration of each trial in seconds
params.bufferPause = 0.2;           % pause before first pull.chunk

end

