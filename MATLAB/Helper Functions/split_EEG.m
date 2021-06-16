function EEG_data_split = split_EEG(data, event_indices, max_dist, padding_size, srate)
    % SPLIT_EEG Split file into instances of activity based on supplied event
    % indices
    %
    % Arguments:
    % EEG: An EEGLAB struct
    % event_indices: A vector of event indices in the EEG data
    % max_dist: Number of samples between events when events should be
    %   considered as separate subsequences
    % srate: Sampling rate of the signal
    %
    % Returns:
    %   A struct containing the original EEG data alongside time-adjusted
    %   event_indices.

    % Luka Velinov
    
    if padding_size > (max_dist / 2)
        warning("Padding size is larger than max_dist / 2. This can lead to overlapping regions.");
    end
    
    [regions_data, regions_idx] = find_activity_windows(data, event_indices, max_dist, padding_size, srate);

    % Put split EEG data into multidimensional struct. Each cell of the struct
    % contains one window

    EEG_data_split = struct();

    for window = 1:size(regions_data, 2)
        EEG_data_split(window).data = regions_data{window};
        EEG_data_split(window).timestamps = regions_idx(window, :);


        % Add tap timestamps, adjusted to the new timings/indices of the
        % activity windows
        EEG_data_split(window).tap_timestamps = int32(...
            event_indices(and(event_indices >= regions_idx(window, 1), event_indices <= regions_idx(window, 2))));
    end
end

function [regions_data, regions_idx] = find_activity_windows(data, event_indices, max_dist, padding_size, srate)
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
    
%     taps = zeros(size(data, 2), 1);
%     taps(taps_all(:)) = 1;
%     
%     moving_average_taps = movmean(taps, max_dist * 2);
%     
%     [~, risetimes, ~] = risetime(moving_average_taps, srate, 'StateLevels', [1e-14, 1e-10]);
%     [~, falltimes, ~] = falltime(moving_average_taps, srate, 'StateLevels', [1e-14, 1e-10]);
%     
%     if length(falltimes) < length(risetimes)
%         falltimes(end+1) = size(data, 2);
%     end
%     
%     activity_windows = {};
%     activity_windows_taps = {};
%     
%     for i = 1:size(risetimes', 2)
%         activity_windows{end+1} = ceil(risetimes(i) * srate):ceil(falltimes(i) * srate);
%         activity_windows_taps{end+1} = find(taps_all(:) > activity_windows{i}(1) & taps_all(:) < activity_windows{i}(end));
%     end
   
    
    event_distances = diff(event_indices);

    regions_end_idx = [event_indices(find(event_distances > max_dist)); event_indices(end)];
    
    regions_start_idx = [event_indices(1); event_indices(find([0; event_distances > max_dist]))]; % Add zero to beginning to get _next_ index after diff
    
    regions_idx = [(regions_start_idx - padding_size), (regions_end_idx + padding_size)];
    
    % Make sure padding does nto go over data bounds
    regions_idx(:, 1) = max(regions_idx(:, 1), 1);
    regions_idx(:, 2) = min(regions_idx(:, 2), size(data, 2));
    
    regions_data = {};
    for idx = 1:size(regions_idx, 1)
        regions_data{idx} = data(:, regions_idx(idx, 1):regions_idx(idx, 2));
    end
end
