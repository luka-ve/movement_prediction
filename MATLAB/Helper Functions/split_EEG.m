function EEG_data_split = split_EEG(EEG, taps_all, opts)
    % Split file into instances of activity

    % Find Taps that are further than max_dist milliseconds apart
    max_dist_between_sections_in_ms = opts.max_dist_between_sections;
    window_padding_size_ms = opts.activity_windows_padding;
    
    [activity_windows, activity_windows_taps] = find_activity_windows(EEG, taps_all, max_dist_between_sections_in_ms);

    % Put split EEG data into multidimensional struct. Each cell of the struct
    % contains one window

    EEG_data_split = struct();

    for window = 1:size(activity_windows, 2)
        EEG_data_split(window).data = EEG.data(:, activity_windows{window});
        EEG_data_split(window).timestamps = [activity_windows{window}(1), activity_windows{window}(end)];


        % Add tap timestamps, adjusted to the new timings/indices of the
        % activity windows
        EEG_data_split(window).tap_timestamps = int32(...
            taps_all(activity_windows_taps{window}, 2) - activity_windows{window}(1));
    end
end

function [activity_windows, activity_windows_taps] = find_activity_windows(EEG, taps_all, max_dist)
    % FIND_ACTIVITY_WINDOWS Finds windows of tap activity.
    %    Examples:    
    %
    %    activity_windows = find_activity_windows(EEG, max_dist, padding_size)
    %
    %    Arguments:
    %        EEG: An EEG file
    %        max_dist: Maximum distance between taps in number of samples
    %        padding_size: Number of samples to extend beyong activity
    %        windows.
    %
    %   Returns:
    %       An n-by-2 matrix containing start and end of activity
    %       windows. Column 1 are start indices, column 2 are end indices.
    
    
    % TODO: Check srate to see if sampling rate was 500 Hz
    
    taps = zeros(size(EEG.data, 2), 1);
    taps(taps_all(:, 2)) = 1;
    
    moving_average_taps = movmean(taps, max_dist * 2);
    
    [~, risetimes, ~] = risetime(moving_average_taps, EEG.srate, 'StateLevels', [1e-14, 1e-10]);
    [~, falltimes, ~] = falltime(moving_average_taps, EEG.srate, 'StateLevels', [1e-14, 1e-10]);
    
    activity_windows = {};
    activity_windows_taps = {};
    
    for i = 1:size(risetimes', 2)
        activity_windows{i} = ceil(risetimes(i) * EEG.srate):ceil(falltimes(i) * EEG.srate);
        activity_windows_taps{i} = find(taps_all(:, 2) > activity_windows{i}(1) & taps_all(:, 2) < activity_windows{i}(end));
    end
   
    
%     tap_distances = diff(EEG.Aligned.Phone.Corrected{1, 1}(:, 2));
% 
%     larger_than_max_dists_idx = find(tap_distances > max_dist);
%     larger_than_max_dists_timestamps = EEG.Aligned.Phone.Corrected{1, 1}(larger_than_max_dists_idx, 2);
% 
% 
%     
%     
%     % Get indices of activity windows
%     activity_windows = zeros(size(larger_than_max_dists_timestamps, 1) + 1, 2);
%     activity_windows_taps = zeros(size(larger_than_max_dists_timestamps, 1) + 1, 2);
% 
%     % Set start of first activity window
%     activity_windows(1, 1) = EEG.Aligned.Phone.Corrected{1, 1}(1, 2) - padding_size;
%     activity_windows_taps(1, 1) = 1;
% 
%     % Set end of last activity window
%     activity_windows(end, 2) = EEG.Aligned.Phone.Corrected{1, 1}(end, 2) + padding_size;
%     activity_windows_taps(end, 2) = size(EEG.Aligned.Phone.Corrected{1, 1}, 1);
% 
%     for window_start = 2:size(activity_windows, 1)
%         activity_windows_taps(window_start, 1) = larger_than_max_dists_idx(window_start - 1) + 1;
%         activity_windows(window_start, 1) = EEG.Aligned.Phone.Corrected{1, 1}(larger_than_max_dists_idx(window_start - 1) + 1, 2) - padding_size;
%     end
% 
%     for window_end = 1:(size(larger_than_max_dists_timestamps, 1))
%         activity_windows_taps(window_end, 2) = larger_than_max_dists_idx(window_end);
%         activity_windows(window_end, 2) = larger_than_max_dists_timestamps(window_end) + padding_size;
%     end
end
