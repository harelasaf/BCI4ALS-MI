%% MI Offline Main Script
% This script runs all the steps in order. Training -- Pre-processing --
% Data segmentation -- Feature extraction -- Model training.
% Two important points:
% 1. Remember the ID number (without zero in the beginning) for each different person
% 2. Remember the Lab Recorder filename and folder.

% Prequisites: Refer to the installation manual for required softare tools.

% This code is part of the BCI-4-ALS Course written by Asaf Harel
% (harelasa@post.bgu.ac.il) in 2021. You are free to use, change, adapt and
% so on - but please cite properly if published.


clc; clear; close all;

%% Run stimulation and record EEG data
[recordingFolder] = MI1_offline_training();
disp('Finished stimulation and EEG recording. Stop the LabRecorder and press any key to continue...');
pause;

%% Run pre-processing pipeline on recorded data
MI2_preprocess(recordingFolder);
disp('Finished pre-processing pipeline. Press any key to continue...');
pause;
%% Segment data by trials
MI3_segmentation(recordingFolder);
disp('Finished segmenting the data. Press any key to continue...');
pause;

%% Extract features and labels
MI4_featureExtraction(recordingFolder);
disp('Finished extracting features and labels. Press any key to continue...');
pause;

%% Train a model using features and labels
testresult = MI5_modelTraining(recordingFolder);
disp('Finished training the model. The offline process is done!');

