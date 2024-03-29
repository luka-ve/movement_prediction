function [indices] = get_FS_taps(FS_data, sampling_rate, min_tap_distance)
%GET_FS_TAPS Extracts tap events from force sensor data
%   Extracts tap events from continuous force sensor data.
% Input:
%   FS_data: A vector of continuous force sensor data.
%   sampling_rate: Sampling rate of the force sensor data.
%   min_tap_distance: Minimum time after a tap before a new tap can be
%       positively detected.
%
% Output:
%   tap_indices: A vector of indices of extracted tap events.
%
% Credits: Original code by Ruchella Kock, adapted by Luka Velinov


assert(min_tap_distance > 0);

base = -1; % Base value when force sensor has null force.

% add some padding
FS_data = [NaN; FS_data; NaN];

%% remove noise values
% In the raw dataset base is between -1 and -0.8
% set all the values between this range to -1.
%
% Luka: Some participants have sequences of NaN, these are also set to -1


for i=1:size(FS_data,1)
    if (FS_data(i,1) < -0.8 && FS_data(i+1,1) < -0.8 && FS_data(i-1,1)< -0.8) || isnan(FS_data(i, 1))
        FS_data(i,1) = base;
    end 
end

% remove the padding
FS_data = FS_data(2:(end-1));

% Make signal square
FS_data(FS_data > -0.5) = 1;

% Remove peaks that are shorter than 5ms. Those are likely noise.
min_tap_length = 30;

[pulse_width, initcross, finalcross] = pulsewidth(FS_data, sampling_rate);


indices_end = round(finalcross(pulse_width > (min_tap_length / sampling_rate)) * sampling_rate);
indices = round(initcross(pulse_width > (min_tap_length / sampling_rate)) * sampling_rate);

% Remove FS taps with too short interval between end of the touch and
% beginning of next touch.
good_taps = true(length(indices), 1);
for ii = 2:length(indices)
    good_taps(ii) = abs(indices(ii) - indices_end(ii - 1)) > min_tap_distance;
end

indices = indices(good_taps);

end

