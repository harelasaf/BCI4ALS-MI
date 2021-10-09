function [dataVar] = sortElectrodes(dataVar, EEG_data, EEG_event, Fs, trialLength, markIndex, numChans, trial)
%% sortElectrodes sorts the EEG_data into the dataVar by electrode name 
% Segments the data into trialLength + buffer.

% dataVar = over-arching main data storage structure
% EEG_data = as outputed by the preprocessing stage
% EEG_events = event markers used to segment the data
% Fs = sample rate (used to transform time to sample points)
% trialLength = used to measure end of segment
% markIndex = EEG_data segment location
% EEG_chans = channel information (name & location)

% For each channel, take data from the marker (+FS*0.1) to trialLength-FS*0.1
% (buffer). Feel free to add a buffer as needed...
for channel=1:numChans
    dataVar(trial,channel,:) = EEG_data(channel,(EEG_event(markIndex).latency*Fs/1000) : (EEG_event(markIndex).latency*Fs/1000 + Fs*(trialLength)));    
end


