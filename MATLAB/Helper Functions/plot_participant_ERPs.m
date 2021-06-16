DATA_ROOT = "/media/Storage/User_Specific_Data_Storage/luka/EEG_ICA/";

% Load participants
component_selection_path = "MATLAB/Component Selection.xlsx";
component_selection = readtable(component_selection_path, 'Range', 'A:F');

% Convert comma-separated string to numeric array
component_selection.SelectedComponentsNum = cellfun(@(x) [str2num(char(x))], component_selection.SelectedComponents, 'UniformOutput', false);


electrodes = [16]; % Which electrodes to observe
epoch_size = [-4, 1];
epoch_size_sum = sum(abs(epoch_size)) * 1000;
baseline_removal_range = [-4000, -3500];

ERPs_taps_alldata = {};
ERPs_FS_alldata = {};
avg_ERPs_taps = zeros(size(component_selection, 1), epoch_size_sum);
avg_ERPs_FS = zeros(size(component_selection, 1), epoch_size_sum);

for ppt_no = 1:size(component_selection, 1)
    ppt_info = table2struct(component_selection(ppt_no, :));
    
    % Load ppt file
    EEG = pop_loadset(ppt_info.Filename, convertStringsToChars(fullfile(DATA_ROOT, ppt_info.Participant)));
    
    % Select component to keep/reject
    comps_to_keep = ppt_info.SelectedComponentsNum;
    comps_to_reject = 1:size(EEG.icachansind, 2);
    comps_to_reject(comps_to_keep) = [];
    
    % Reject non-selected components
    pop_subcomp(EEG, comps_to_reject);
    
    % Interpolate missing channels
    pop_interp(EEG,EEG.Orignalchanlocs,'spherical');
    
    % Epoch data
    
    EEG_taps = pop_epoch(EEG, {'Tap'}, epoch_size);
    EEG_FS = pop_epoch(EEG, {'FS_event'}, epoch_size);
    
    EEG_taps = pop_rmbase(EEG_taps, baseline_removal_range);
    EEG_FS = pop_rmbase(EEG_FS, baseline_removal_range);
    
    % Extract ERP data
    signal_tmp = eeg_getdatact(EEG_taps);
    ERPs_taps_alldata{ppt_no} = signal_tmp;
    avg_ERPs_taps(ppt_no, :) = mean(signal_tmp(electrodes, :, :), 3);
    
    signal_tmp = eeg_getdatact(EEG_FS);
    ERPs_FS_alldata{ppt_no} = signal_tmp;
    avg_ERPs_FS(ppt_no, :) = mean(signal_tmp(electrodes, :, :), 3);
end

%% Plot
figure();
tiledlayout(2, 2, 'TileSpacing', 'compact')

nexttile;
plot(avg_ERPs_FS');
title('Average ERPs of FS epochs');
xline(abs(epoch_size(1)) * 1000);
yline(0);

nexttile;
plot(avg_ERPs_taps');
title('Average ERPs of tap epochs');
xline(abs(epoch_size(1)) * 1000);
yline(0);

nexttile;
plot(normalize(avg_ERPs_FS'));
title('Average ERPs of FS epochs, normalized per participant', 'Interpreter', 'none');
xline(abs(epoch_size(1)) * 1000);
yline(0);

nexttile;
plot(normalize(avg_ERPs_taps'));
title('Average ERPs of Tap epochs, normalized per participant', 'Interpreter', 'none');
xline(abs(epoch_size(1)) * 1000);
yline(0)


legend_labels = cellfun(@(x) strrep(x(1:end-8), '_', '\_'), strcat(component_selection.Participant, '/', component_selection.Filename), 'UniformOutput', false);
lg = legend(legend_labels, 'Location', 'southoutside');
lg.Location = 'eastoutside';
