%% Load files
DATA_ROOT_PATH = "D:/Coding/Thesis/Data/EEG/";
PPT_FILE = ["DS95/12_02_11_04_19.set", "DS97/12_05_18_04_19.set", "DS99/08_05_25_04_19.set", "DS98/09_35_12_03_19.set", "DS98/11_43_12_03_19.set"];

PPT_FILE= ["DS32/08_13_15_04_19.set", "DS33/08_09_18_04_19.set"];

%% Plot avg epochs
clear EEG

test_set = 1;

% Load file
EEG = pop_loadset('filename', convertStringsToChars(fullfile(DATA_ROOT_PATH, PPT_FILE(test_set))));

% Cleaning
EEG_clean = gettechnicallycleanEEG(EEG, 0, 10);

EEG_data = EEG_clean.data;

all_taps = concatenate_taps(EEG);
all_taps = all_taps(:, 2);


% Remove Line Noise using CleanLine
% Requires https://github.com/sccn/cleanline
% EEG_clean = pop_cleanline(EEG, ...
%     'bandwidth', 2,...
%     'chanlist', [1:20],... % Only first 20 channels for exploration. CHANGE THIS TO ALL CHANNELS LATER
%     'computepower', 1,...
%     'linefreqs', 50,...
%     'newversion', 0,...
%     'normSpectrum', 0,...
%     'p', 0.01,...
%     'pad', 2,...
%     'plotfigures', 0,...
%     'scanforlines', 1,...
%     'sigtype', 'Channels',...
%     'taperbandwidth', 2,...
%     'tau', 100,...
%     'verb', 1,...
%     'winsize', 4,...
%     'winstep', 2);



channel = 14;
eeg_window = -5000:1:1000;

% Pad EEG Data in case epoch overhangs end of data
EEG_data = [EEG_data, zeros(64, 1000)];

epochs = zeros(length(all_taps), length(eeg_window));

for ii = 1:length(all_taps)
    epochs(ii, :) = EEG_data(channel, all_taps(ii) + eeg_window);
    
    % Smooth data over short window
    filter_size = 10;
    epochs(ii, :) = smoothdata(epochs(ii, :), 2, 'movmean', filter_size);
    
    % Zscore
    epochs(ii, :) = zscore(epochs(ii, :), 0);
    
    % Baseline correction
    epochs(ii, :) = epochs(ii, :) - mean(epochs(ii, 1:1000));
end

epochs_mean = mean(epochs, 1);

filename = strrep(PPT_FILE(test_set), "/", "-");

figure();
plot(eeg_window, epochs_mean);
title(join(["Avg Epoch. ", "Channel: ", channel, "Participant: ", filename]));
xline(0);
saveas(gcf, join(["Averaged_Epoch_", filename, ".jpg"]));

figure();
spectrogram(epochs_mean, [], [], [], 1000, 'yaxis');
title(join(["Avg Epoch Spec.", "Channel: ", channel, "Participant: ", filename]));
saveas(gcf, join(["Averaged_Epoch_Spectrogram_", filename, ".jpg"]));

% Ridge regression
%delta_t = repmat(flip(0:1:2000), size(epochs, 1), 1);

%B = lasso(delta_t, epochs);
