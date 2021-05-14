function [idx] = ms2idx(latency, sampling_rate)
%MS2IDX Summary of this function goes here
%   Detailed explanation goes here
idx = round(latency / (1000 / sampling_rate));
end

