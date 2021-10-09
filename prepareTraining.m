function [trainingVec] = prepareTraining(numTrials,numConditions)
%% return a random vector of 1's, 2's and 3's in the length of numTrials
trainingVec = (1:numConditions);
trainingVec = repmat(trainingVec,1,numTrials);
trainingVec = trainingVec(randperm(length(trainingVec)));

end