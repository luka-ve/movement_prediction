function [epochedvals] = getepocheddata(Data, triggersample, SampleRange)
% Usage: [epochedvals] = getepocheddata(Data, triggersample, Sample Range)
%
% Input(s)
%   - Data --> Samples as in timeseries 
%   - triggersample ---> The samples containing trigger as in cell number of T.
%   - Sample range ----> [-100 100], takes 100 samples before and 100 after.
% Output(s)
%   - epocedvals ----> The values before and after the trigger 
%
% Arko Ghosh, Leiden University, 28/05/2019 


% create the data matrix full of NaNs
dim1 = length(triggersample); 
dim2 = abs(SampleRange(1))+SampleRange(2)+1; 
Data_epoched(1:dim1,1:dim2) = deal(NaN);

% go through the triggers and epoch the data 
for t = 1:length(triggersample)

try
    Data_epoched(t,:) = Data([triggersample(t)+SampleRange(1)]:[triggersample(t)+SampleRange(2)]);    
end  
    
end

epochedvals = Data_epoched; 
end