function [HHParams] = HH_Params()

HHParams.trials = 50;
HHParams.trialLength = 10;
HHParams.Fs = 300;
HHParams.frequencies = [7.5, 8.57, 12];
HHParams.recordingRootFolder = 'C:\Dropbox (BGU)\Asaf Harel\Recordings\HarmonicHunter\Actual\';
HHParams.recExtension = '\sub-P001\ses-S001\eeg\sub-P001_ses-S001_task-T1_run-001_eeg.xdf';
HHParams.cleanedFolder = 'C:\Dropbox (BGU)\Asaf Harel\Code\HarmonicHunter\Analysis\data';
HHParams.directory = dir(recordingRootFolder);
HHParams.subjects = size(directory,1)-2;
HHParams.trialStartEvent = '1.000000000000000';

end