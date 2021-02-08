%% Requires:
% github.com/codelableidenvelux/neubee/master
% EEGLAB

DATA_PATH = "../../Data/EEG/";
PPT_FILE = "DS99/10_12_25_04_19.set";


EEG = pop_loadset('filename', fullfile('../../Data/EEG/DS99/08_05_25_04_19.set'));


% '../../Data/EEG/DS99/08_05_25_04_19.set'
% {"..\\..\\Data\\EEG\\DS99\\10_12_25_04_19.set"}

%% Remove Eye Blinks

EEG_clean = gettechnicallycleanEEG(EEG, [], 45);


%% Extract EEG data

EEG_data = EEG_clean.data;


%% PCA on original EEG data
EEG_PCA = struct();

[EEG_PCA.coeffs, EEG_PCA.score, EEG_PCA.latent, EEG_PCA.tsquared, EEG_PCA.explained] = pca(EEG_data');

figure();
tiledlayout(1,2)

% Scree plot
nexttile();
plot(EEG_PCA.explained);
yline(1);
ylabel("Eigenvalue")
xlabel("Principal Components")
title("Eigenvalues of Principal Components");

% Cumulative variance explained
nexttile;
plot(cumsum(EEG_PCA.explained));
yline(98);
xline(find(cumsum(EEG_PCA.explained) > 98, 1, 'first'));
ylabel("Cumulative Variance Explained")
xlabel("Principal Components")
title("Cumulative Variance Explained Over Principal Components");


%% Use dimension reduced EEG data
nPrinComps = 9;
EEGDataReduced = score(:, 1:nPrinComps);


%% Split file into instances of activity

% Find Taps that are further than max_dist milliseconds apart
max_dist_between_sections_in_ms = 30000;
window_padding_size_ms = 30000;

tap_distances = diff(EEG.Aligned.Phone.Corrected{1, 1}(:, 2));

larger_than_max_dists_idx = find(tap_distances > max_dist_between_sections_in_ms);
larger_than_max_dists_timestamps = EEG.Aligned.Phone.Corrected{1, 1}(larger_than_max_dists_idx, 2);


% Get indices of activity windows
activity_windows = zeros(size(larger_than_max_dists_timestamps, 1) + 1, 2);
activity_windows_taps = zeros(size(larger_than_max_dists_timestamps, 1) + 1, 2);

% Set start of first activity window
activity_windows(1, 1) = EEG.Aligned.Phone.Corrected{1, 1}(1, 2) - window_padding_size_ms;
activity_windows_taps(1, 1) = 1;

% Set end of last activity window
activity_windows(end, 2) = EEG.Aligned.Phone.Corrected{1, 1}(end, 2) + window_padding_size_ms;
activity_windows_taps(end, 2) = size(EEG.Aligned.Phone.Corrected{1, 1}, 1);

for window_start = 2:size(activity_windows, 1)
    
    activity_windows_taps(window_start, 1) = larger_than_max_dists_idx(window_start - 1) + 1;
    activity_windows(window_start, 1) = EEG.Aligned.Phone.Corrected{1, 1}(larger_than_max_dists_idx(window_start - 1) + 1, 2) - window_padding_size_ms;
end

for window_end = 1:(size(larger_than_max_dists_timestamps, 1))
    activity_windows_taps(window_end, 2) = larger_than_max_dists_idx(window_end);
    activity_windows(window_end, 2) = larger_than_max_dists_timestamps(window_end) + window_padding_size_ms;
end

% Put split EEG data into multidimensional struct. Each cell of the struct
% contains one window

EEG_data_split = struct();

for window = 1:size(activity_windows, 1)
    EEG_data_split(window).data = EEG_data(:, activity_windows(window, 1):activity_windows(window, 2));
    EEG_data_split(window).timestamps = activity_windows(window, :);
    
    tap_idx = find(EEG.Aligned.Phone.Corrected{1, 1}(:, 2) == EEG_data_split(window).timestamps(1));
    
    
    % Add tap timestamps, adjusted to the new timings/indices of the
    % activity windows
    EEG_data_split(window).tap_timestamps = int32(...
        EEG.Aligned.Phone.Corrected{1, 1}(activity_windows_taps(window, 1):activity_windows_taps(window, 2), 2) - activity_windows(window, 1));
end

clear window


% Plot EEG data of channel 1 and taps
figure();

plot(EEG_data(1, :));

hold on;

ups = zeros(size(EEG.Aligned.Phone.Corrected{1, 1}, 1), 1);
ups(EEG.Aligned.Phone.Corrected{1, 1}(:, 2)) = max(EEG_data(1, :));
plot(ups);

% Add timestamps for activity windows to plot
for i = reshape(activity_windows, 1, numel(activity_windows))
    xline(i);
end

hold off;

%% STFT
% Performs STFT on each EEG channel

for idx = 1:size(EEG_data_split, 2)
    window = hann(64, "periodic");
    overlap = floor(length(window) / 2); % 50% stride
    FFTLength = 64;

    [EEG_stft, freqs, times] = stft(...
        EEG_data_split(idx).data', EEG.srate,...
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


%% PCA on STFT features
% This bit performs PCA on each individual frequency band
stft_PCA = repmat(struct(), size(EEG_stft, 3), 1);
%zeros(size(EEG_stft, 3), 5);

for dimension = 1:size(EEG_stft, 3)
    EEG_data_split(dimension).PCA = struct();
    
    [EEG_data_split(dimension).PCA.coeffs, ...
        EEG_data_split(dimension).PCA.score, ...
        EEG_data_split(dimension).PCA.latent, ...
        EEG_data_split(dimension).PCA.tsquared, ...
        EEG_data_split(dimension).PCA.explained] = pca(reshape(EEG_stft(dimension, :, :), [size(EEG_stft, 2), size(EEG_stft, 3)]));
end



% OPEN QUESTIONS ABOUT PCA
% Which coefficients to use for other participants? -> Compare multiple
% participants
% 


%% Scree plot STFT PCA
figure();
plot([stft_PCA(:).explained]);
yline(1);
ylabel("Eigenvalue")
xlabel("Principal Components")
title("Eigenvalues of Principal Components");


%% Remove irrelevant frequency bands 
% with variance <= threshold
% Frequencies with no variance are not of interest to our model. Therefore,
% we can simply get rid of them

disp(var(EEG_stft(:, :, 1)'));

freqs_to_keep = 1:10;

EEG_stft = EEG_stft(freqs_to_keep, :, :);
freqs = freqs(freqs_to_keep);


%% Export to hdf5
filename = strcat(strrep(PPT_FILE, "/", "-"), ".h5");

for window = 1:size(EEG_data_split, 2)
    h5create(filename, sprintf("/window_%s/stft/real", window), size(real(EEG_data_split(window).stft)));
    h5create(filename, sprintf("/window_%s/stft/imag", window), size(imag(EEG_data_split(window).stft)));
    
    h5write(filename, sprintf("/window_%s/stft/real", window), real(EEG_data_split(window).stft));
    h5write(filename, sprintf("/window_%s/stft/imag", window), imag(EEG_data_split(window).stft));
    
    h5create(filename, sprintf("/window_%s/taps", window), size(EEG_data_split(window).tap_timestamps));
    h5write(filename, sprintf("/window_%s/taps", window), EEG_data_split(window).tap_timestamps);
end

