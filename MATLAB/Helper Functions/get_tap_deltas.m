function [tap_deltas, inter_tap_intervals] = get_tap_deltas(tap_times, K, srate)
%GET_TAP_DELTAS Extract the distances between taps.
%   This function extracts delta times between taps.
% INPUT:
% tap_times: Tap event latencies
% K: A vector of which surrounding taps to extract deltas to.
% srate: Sample rate of tap_times
%
% IMPORTANT: The script will skip the first n taps, where n is the
% abs(min(K)). On other words: When calculating the delta times to the 3rd
% previous tap, script will start on the 4th tap. Previous tap deltas will
% be NaN. Same goes for the final taps.
%
% OUTPUT:
% tap_deltas: struct with 2 fields:
%   tap_idx: Indices of the taps taken into account.
%   deltas: A matrix with dimensions number of taps * number of features
%       numel(tap_times) * numel(K)
%
% EXAMPLES USE
%
% tap_latencies = [600, 782, 4525, 4576, 8974, 16000 20000, 25004];
% taps_to_observe = [-1, 1, 2];
%
% tap_deltas = get_tap_deltas(tap_latencies, taps_to_observe, 1000);
%

assert(all(sort(tap_times) == tap_times), 'UnsortedArray', 'tap_times must be an array of ascending tap latencies.');

min_delta = abs(min(K));
max_delta = abs(max(K)) - 1;

tap_delta_size = zeros(length(tap_times), length(K));

tap_deltas_with_idx(size(tap_delta_size, 1)) = struct();

for tap = 1:size(tap_delta_size, 1)    
    current_taps = zeros(length(K), 1);
    
    for k = 1:length(current_taps)
        if tap > min_delta && tap < (size(tap_delta_size, 1) - max_delta)
            current_taps(k) = tap_times(tap + K(k)) - tap_times(tap);
        else
            current_taps(k) = NaN;
        end
    end
    
    tap_deltas_with_idx(tap).tap_idx = tap;
    tap_deltas_with_idx(tap).deltas = current_taps';
    
    % Convert latency in samples to latency in ms
    tap_deltas_with_idx(tap).deltas = tap_deltas_with_idx(tap).deltas * (1000 / srate);
end

tap_deltas = tap_deltas_with_idx;

inter_tap_intervals = diff(tap_times);

end

