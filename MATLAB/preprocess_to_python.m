% Requires:
% github.com/codelableidenvelux/neubee/master
% EEGLAB

DATA_ROOT_PATH = "D:/Coding/Thesis/Data/EEG";
PPT_FILES = ["DS99/08_05_25_04_19.set" "DS99/10_19_25_04_19.set"];

opts = struct();

opts.lowpass_freq = [];
opts.highpass_freq = 45;
opts.max_dist_between_sections = 30000;
opts.activity_windows_padding = 30000;

opts.stft_window = hann(64, "periodic");
opts.stft_overlap = floor(length(opts.stft_window) / 2); % 50% stride
opts.stft_FFTLength = 64;

opts.h5_save_path = fullfile("D:/Coding/Thesis/Data/STFT Output");


for ppt_file = PPT_FILES
    EEG = pop_loadset('filename', convertStringsToChars(fullfile(DATA_ROOT_PATH, ppt_file)));
    
    EEG_clean = clean_EEG(EEG, opts);
    EEG_data_split = split_EEG(EEG_clean, opts);
    EEG_data_split = perform_STFT(EEG_data_split, EEG.srate, opts);
    
    export_as_h5(EEG_data_split, ppt_file, opts);
end


% Helper Functions

function EEG_cleaned = clean_EEG(EEG, opts)
    EEG_cleaned = gettechnicallycleanEEG(EEG, opts.lowpass_freq, opts.highpass_freq);
end


function EEG_data_split = split_EEG(EEG, opts)
    % Split file into instances of activity

    % Find Taps that are further than max_dist milliseconds apart
    max_dist_between_sections_in_ms = opts.max_dist_between_sections;
    window_padding_size_ms = opts.activity_windows_padding;
    
    [activity_windows, activity_windows_taps] = find_activity_windows(EEG, max_dist_between_sections_in_ms, window_padding_size_ms);

    % Put split EEG data into multidimensional struct. Each cell of the struct
    % contains one window

    EEG_data_split = struct();

    for window = 1:size(activity_windows, 1)
        EEG_data_split(window).data = EEG.data(:, activity_windows(window, 1):activity_windows(window, 2));
        EEG_data_split(window).timestamps = activity_windows(window, :);


        % Add tap timestamps, adjusted to the new timings/indices of the
        % activity windows
        EEG_data_split(window).tap_timestamps = int32(...
            EEG.Aligned.Phone.Corrected{1, 1}(activity_windows_taps(window, 1):activity_windows_taps(window, 2), 2) - activity_windows(window, 1));
    end
end


function [activity_windows, activity_windows_taps] = find_activity_windows(EEG, max_dist, padding_size)
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
    tap_distances = diff(EEG.Aligned.Phone.Corrected{1, 1}(:, 2));

    larger_than_max_dists_idx = find(tap_distances > max_dist);
    larger_than_max_dists_timestamps = EEG.Aligned.Phone.Corrected{1, 1}(larger_than_max_dists_idx, 2);


    % Get indices of activity windows
    activity_windows = zeros(size(larger_than_max_dists_timestamps, 1) + 1, 2);
    activity_windows_taps = zeros(size(larger_than_max_dists_timestamps, 1) + 1, 2);

    % Set start of first activity window
    activity_windows(1, 1) = EEG.Aligned.Phone.Corrected{1, 1}(1, 2) - padding_size;
    activity_windows_taps(1, 1) = 1;

    % Set end of last activity window
    activity_windows(end, 2) = EEG.Aligned.Phone.Corrected{1, 1}(end, 2) + padding_size;
    activity_windows_taps(end, 2) = size(EEG.Aligned.Phone.Corrected{1, 1}, 1);

    for window_start = 2:size(activity_windows, 1)

        activity_windows_taps(window_start, 1) = larger_than_max_dists_idx(window_start - 1) + 1;
        activity_windows(window_start, 1) = EEG.Aligned.Phone.Corrected{1, 1}(larger_than_max_dists_idx(window_start - 1) + 1, 2) - padding_size;
    end

    for window_end = 1:(size(larger_than_max_dists_timestamps, 1))
        activity_windows_taps(window_end, 2) = larger_than_max_dists_idx(window_end);
        activity_windows(window_end, 2) = larger_than_max_dists_timestamps(window_end) + padding_size;
    end
end


function EEG_data_split = perform_STFT(EEG_data_split, sampling_rate, opts)
    % Performs STFT 
    
    for idx = 1:size(EEG_data_split, 2)
        window = opts.stft_window;
        overlap = opts.stft_overlap;
        FFTLength = opts.stft_FFTLength;

        [EEG_stft, freqs, times] = stft(...
            EEG_data_split(idx).data', sampling_rate,...
            "Window", window,...
            "OverlapLength", overlap,...
            'FFTLength', FFTLength);

        % Remove negative frequencies
        EEG_stft = EEG_stft(ceil(size(EEG_stft, 1)/2 + 1):end, :, :);
        freqs = freqs(ceil(size(freqs, 1)/2 + 1):end);

        % Save stft info into struct
        EEG_data_split(idx).stft = EEG_stft;
        EEG_data_split(idx).freqs = freqs;
        EEG_data_split(idx).times = times;
    end
end


function [] = export_as_h5(data, participant_name, opts)
    % Saves the dataset to the location specified in opts.h5_save_path as
    % an .h5 file.
    % The STFT output is split into real and imaginary parts, since complex
    % values are not supported in HDF5.
    %
    % TODO: Put all data of one participant into same file. Make new level
    % for each recording
    
    filename = strcat(strrep(participant_name, "/", "-"), ".h5");
    filename = strrep(filename, ".set", "");
    
    filename_full_path = fullfile(opts.h5_save_path, filename);

    for window = 1:size(data, 2)
        h5create(filename_full_path, sprintf("/window_%s/stft/real", window), size(real(data(window).stft)));
        h5create(filename_full_path, sprintf("/window_%s/stft/imag", window), size(imag(data(window).stft)));

        h5write(filename_full_path, sprintf("/window_%s/stft/real", window), real(data(window).stft));
        h5write(filename_full_path, sprintf("/window_%s/stft/imag", window), imag(data(window).stft));

        h5create(filename_full_path, sprintf("/window_%s/taps", window), size(data(window).tap_timestamps));
        h5write(filename_full_path, sprintf("/window_%s/taps", window), data(window).tap_timestamps);
    end
end
