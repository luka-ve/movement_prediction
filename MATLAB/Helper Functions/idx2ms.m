function [latency] = idx2ms(index, sampling_rate)
%IDX2MS Converts an array's index to milliseconds according to sampling
%rate.
%   Detailed explanation goes here
latency = index * (1000 / sampling_rate);
end

