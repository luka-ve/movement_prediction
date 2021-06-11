clear;


%% Load data selected independent components
DATA_ROOT = "/media/Storage/User_Specific_Data_Storage/luka/EEG_ICA/";

% Load table form excel file
component_selection_path = "MATLAB/Component Selection.xlsx";
component_selection = readtable(component_selection_path, 'Range', 'A:F');

% Convert comma-separated string to numeric array
component_selection.SelectedComponentsNum = cellfun(@(x) [str2num(char(x))], component_selection.SelectedComponents, 'UniformOutput', false);

% Settings
electrodes = [1, 2, 6, 10, 16]; % Which electrodes to observe
taps_to_observe = [-2, -1, 1, 2]; % Which surrounding taps to observe
epoch_size = [-3, 0.5];

do_resample = 0;
new_sampling_rate = 1000; % Hz

% ONLY FOR TESTING
%component_selection = component_selection(1:6, :);

%% Reproject selected components

starting_dir = pwd(); % Need to save starting dir, as some LIMO functions will cd into other directories.

delta_times_per_tap = {};
SAVE_PATH = "/media/Storage/User_Specific_Data_Storage/luka/EEG_STUDY/";

% Arrays to hold information about files locations
set_files = {};
cont_files = {};
LIMO_files = {};
LIMOs = {};


for ppt_no = 1:size(component_selection, 1)
    ppt_info = table2struct(component_selection(ppt_no, :));
    
    % Load ppt file
    EEG1 = pop_loadset(ppt_info.Filename, convertStringsToChars(fullfile(DATA_ROOT, ppt_info.Participant)));
    
    % Resample if necessary
    if do_resample
        EEG1 = pop_resample(EEG1, new_sampling_rate);
    end
    
    % Select component to keep/reject
    comps_to_keep = ppt_info.SelectedComponentsNum;
    comps_to_reject = 1:size(EEG1.icachansind, 2);
    comps_to_reject(comps_to_keep) = [];
    
    % Reject non-selected components
    pop_subcomp(EEG1, comps_to_reject);
    
    % Interpolate missing channels
    pop_interp(EEG1,EEG1.Orignalchanlocs,'spherical');
    
    
    % Extract tap distances
    tap_event_indices = find(strcmp({EEG1.event.code}, 'Tap'));    
    tap_events = EEG1.event(tap_event_indices);
    tap_latencies = [tap_events.latency];
    delta_times_per_tap{end + 1} = get_tap_deltas(tap_latencies, taps_to_observe, EEG1.srate);
    EEG1.etc.delta_times_per_tap = delta_times_per_tap{end};
    EEG1.etc.delta_K_set = taps_to_observe;
    
    
    % Add tap distance information to EEG.event struct
    for tap_idx = 1:length(delta_times_per_tap{end})
        tap_event_idx = tap_event_indices(delta_times_per_tap{end}(tap_idx).tap_idx);
        
        for delta_t = 1:length(taps_to_observe)
            field_name = sprintf("t%d", taps_to_observe(delta_t));
            field_name = strrep(field_name, '-', 'm');
            
            % Set delta to NaN if taps are at concatenated border
            if any(abs(delta_times_per_tap{end}(tap_idx).deltas) >= 60000)
                EEG1.event(tap_event_idx).(field_name) = NaN;
            else
                EEG1.event(tap_event_idx).(field_name) = delta_times_per_tap{end}(tap_idx).deltas(delta_t);
            end
        end
    end    
    
    
    % Generate epochs
    EEG1 = pop_epoch(EEG1, {'Tap'}, epoch_size);
    
    % Define continuous predictors
    continuous = zeros(size(EEG1.epoch, 2), size(taps_to_observe, 2));
    for this_epoch = 1:size(EEG1.epoch, 2)
        which_current_event = find(cell2mat(EEG1.epoch(this_epoch).eventlatency) == 0);
        
        % Handle edge case in which multiple events have the exact same
        % latency (E.g., when stimulus and tap overlay exactly)
        correct_event = which_current_event(strcmp({EEG1.epoch(this_epoch).eventcode{which_current_event}}, "Tap"));
        
        % Extract predictor info
        continuous(this_epoch, 1) = EEG1.epoch(this_epoch).eventtm2{correct_event};
        continuous(this_epoch, 2) = EEG1.epoch(this_epoch).eventtm1{correct_event};
        continuous(this_epoch, 3) = EEG1.epoch(this_epoch).eventt1{correct_event};
        continuous(this_epoch, 4) = EEG1.epoch(this_epoch).eventt2{correct_event};
    end
    
    
            
    % Save epoched and processed data to new file
    if ~exist(fullfile(SAVE_PATH, ppt_info.Participant), 'dir')
        mkdir(fullfile(SAVE_PATH, ppt_info.Participant));
    end
    pop_saveset(EEG1, 'filename', ppt_info.Filename, 'filepath', convertStringsToChars(fullfile(SAVE_PATH, ppt_info.Participant)));
    
    
    save(fullfile(SAVE_PATH, ppt_info.Participant, [ppt_info.Filename(1:end-4), '_continuous.mat']), 'continuous');
    
    % Add to file arrays
    set_files{end + 1} = char(fullfile(SAVE_PATH, ppt_info.Participant, ppt_info.Filename));
    cont_files{end + 1} = char(fullfile(SAVE_PATH, ppt_info.Participant, [ppt_info.Filename(1:end-4), '_continuous.mat']));
    
    
    %% Do LIMO 1st level analysis using LIMO struct
    
    % Basic setup
    Cat = [];
    Cont = log10(abs(continuous));
    Cont = Cont(:, 2:3);
    
    LIMO = struct();
    LIMO.Level                    = 1;
    LIMO.dir                      = fullfile(SAVE_PATH, ppt_info.Participant);
    LIMO.Analysis = 'Time';
    LIMO.Type = 'Channels';
    
    LIMO.data.data_dir            = fullfile(SAVE_PATH, ppt_info.Participant);
    LIMO.data.data                = ppt_info.Filename;
    LIMO.data.chanlocs            = EEG1.chanlocs;
    LIMO.data.start               = -4000;
    LIMO.data.end                 = 500;
    LIMO.data.sampling_rate       = EEG1.srate;
    LIMO.data.Cat                 = Cat;
    LIMO.data.Cont                = Cont;
    LIMO.data.neighbouring_matrix = [];
    LIMO.design.fullfactorial     = 0;
    LIMO.design.zscore            = 1;
    LIMO.design.method            = 'OLS';
    LIMO.design.type_of_analysis  = 'Mass-univariate';
    LIMO.design.bootstrap         = 0;
    LIMO.design.tfce              = 0;
    
    % Generate Y
    Y = EEG1.data;    
    
    [LIMO.design.X, LIMO.design.nb_conditions, LIMO.design.nb_interactions, LIMO.design.nb_continuous] = limo_design_matrix(Y, LIMO, 0);

    LIMO.design.status = 'to do';
    LIMO.design.name = 'Delta times';
    
    % Remove trials with NaN
    % This is necessary since limo_design_matrix will automatically remove
    % trials with NaNs in the predictors.
    % NaNs are introduced to the data by the get_tap_deltas function.
    Y(:, :, any(isnan(continuous), 2)) = []; 
    
    
    
    LIMO.model = cell(size(Y, 1), 1);
    
    for current_electrode = 1:size(Y, 1)
        Y_now = squeeze(Y(current_electrode, :, :))';
        LIMO.model{current_electrode} = limo_glm(Y_now, LIMO);
    end

    LIMO.model = [LIMO.model{:}];
    
    LIMOs{ppt_no} = LIMO;
    
    LIMO_savepath = fullfile(SAVE_PATH, ppt_info.Participant, 'LIMO.mat');
    save(LIMO_savepath, 'LIMO');
    LIMO_files{end + 1} = LIMO_savepath;    
end

cd(starting_dir);

% Save file locations
save(fullfile(pwd(), 'save_locations.mat'), 'set_files', 'cont_files', 'LIMO_files');

LIMOs = [LIMOs{:}];
save('ALL_LIMO_INFO.mat', 'LIMOs');


%% LIMO Step 2

% Find Betas.mat files in ppt folder
beta_file_locs = dir([char(SAVE_PATH), '**/Betas.mat']);

beta_file_locs = [{beta_file_locs(:).folder}; {beta_file_locs(:).name}]';

expected_chanlocs = load('~/Thesis/movement_prediction/MATLAB/expected_chanlocs.mat');


% Make a new LIMO.mat file
LIMO = struct();
LIMO.dir = pwd();
LIMO.Analysis = 'Time';
LIMO.Level = 2;

LIMO.data.chanlocs = expected_chanlocs.expected_chanlocs;
LIMO.data.neighbouring_matrix = expected_chanlocs.channeighbstructmat;
LIMO.data.data = beta_file_locs{:, 2};
LIMO.data.data_dir = beta_file_locs{:, 1};
LIMO.data.sampling_rate = 1000;
%LIMO.data.trim1 = 0.1;
%LIMO.data.start = 0;
%LIMO.data.trim2 = 0.9;
%LIMO.data.end = sum(abs(epoch_size)) * 1000;

LIMO.design.bootstrap = 1000;
LIMO.design.tfce = 0;
LIMO.design.name = 'one sample t-test all electrodes';
LIMO.design.electrode = [];
LIMO.design.X = [];
LIMO.design.method = 'Trimmed Mean';

save('LIMO.mat', 'LIMO');

n_betas = size(LIMOs(1).model(1).betas, 1);

% Dimensions: electrodes * frames * betas * participants
betas = zeros(64, sum(abs(epoch_size)) * 1000, n_betas, size(LIMOs, 2));

for ppt = 1:size(LIMOs, 2)
    current_ppt_limo = LIMOs(ppt);
    
    for electrode = 1:size(current_ppt_limo.model, 2)    
        betas(electrode, :, :, ppt) = current_ppt_limo.model(electrode).betas';
    end
end

size(betas)
whos betas





% Plot betas for each electrode

electrodes = 1:size(betas, 1);

for beta = 1:size(betas, 3)
    figure;
    sgtitle(sprintf('Beta %d', beta));
    p = numSubplots(length(electrodes));
    
    for electrode_index = 1:length(electrodes)
        subplot(p(1), p(2), electrode_index);        
        plot(epoch_size(1) * 1000:epoch_size(2) * 1000 - 1, squeeze(betas(electrodes(electrode_index), :, beta, :)));
        hold on;
        
        % Add mean line
        plot(epoch_size(1) * 1000:epoch_size(2) * 1000 - 1, mean(squeeze(betas(electrodes(electrode_index), :, beta, :)), 2), 'LineWidth', 4);
        
        
        title(string(electrodes(electrode_index)));
        xline(0);
        yline(0);        
    end
end


% T-test for each beta
LIMO_paths(size(betas,3)) = string();

for current_beta_index = 1:size(betas,3)
    current_beta = squeeze(betas(:, :, current_beta_index, :));
   
    LIMO_paths(current_beta_index) = limo_random_robust(1, current_beta, current_beta_index, LIMO);
end


%maxclustersum = limo_getclustersum(f,p,channeighbstructmat,minnbchan,alphav)
load('H0/boot_table');
alpha = 0.05;
min_n_channels = 2;
n_boot = size(boot_table{1}, 2);



% All the above can be replaced by the following
mask = zeros(size(betas, 1), size(betas, 2), size(LIMO_paths, 2));
cluster_p = zeros(size(betas, 1), size(betas, 2), size(LIMO_paths, 2));

one_sample = zeros(size(betas, 1), size(betas, 2), 5, size(LIMO_paths, 2));

for current_beta = 1:size(LIMO_paths, 2)
    one_sample_tmp = load(fullfile(LIMO_paths{current_beta}, sprintf('one_sample_ttest_parameter_%d.mat', current_beta)));
    one_sample(:, :, :, current_beta) = one_sample_tmp.one_sample;    
    
    load(fullfile(LIMO_paths{current_beta}, 'H0', sprintf('H0_one_sample_ttest_parameter_%d.mat', current_beta)));
    
    [mask(:, :, current_beta), cluster_p(:, :, current_beta)] = limo_cluster_correction( ...
        squeeze(one_sample(:, :, 4, current_beta) .^ 2), ...
        squeeze(one_sample(:, :, 5, current_beta)), ...
        squeeze(H0_one_sample(:, :, 1, :) .^ 2), ...
        squeeze(H0_one_sample(:, :, 2, :)), ...
        expected_chanlocs.channeighbstructmat, ...
        2, ...
        alpha);
end

save('clustering_output.mat', 'mask', 'cluster_p');

%% Plot clusters



figure;
sgtitle('Significant clusters for each coefficient.')
tiledlayout(1, 3, 'TileSpacing', 'compact')


for current_beta = 1:size(mask, 3)
    clusters = unique(mask(:, :, current_beta))';
    clusters(clusters == 0) = []; % Remove 0, 0 is no significant cluster
    
    ax = nexttile;
    title(string(current_beta));
    
    hold on;
    xlim([1, size(cluster_indices, 2)]);
    ylim([1, size(cluster_indices, 1)]);
    
    this_beta_cluster_ps = {};
    
    for current_cluster = clusters
        cluster_indices = squeeze(mask(:, :, current_beta)) == current_cluster;
        [cluster_pos_x, cluster_pos_y] = find(cluster_indices');
        
        hold on;
        scatter(cluster_pos_x, cluster_pos_y);
        
        %title(string(current_cluster));
        
        %significant_betas = mean(squeeze(betas(:, :, current_beta, :)), 3);
        %significant_betas(cluster_indices) = significant_betas(cluster_indices)
        
        %length(significant_betas(~cluster_indices))
        
        this_cluster_p = squeeze(cluster_p(:, :, current_beta));
        this_beta_cluster_ps{current_cluster} = string(max(this_cluster_p(cluster_indices)));
    end
    
    legend(this_beta_cluster_ps);
end


%%









% boot_max_cluster_sum = zeros(n_boot, 1);
% for boot = 1:n_boot
%     boot_max_cluster_sum(boot) = limo_getclustersum( ...
%         squeeze(H0_one_sample(:, :, 1, boot) .^ 2), ...
%         squeeze(H0_one_sample(:, :, 2, boot)), ...
%         expected_chanlocs.channeighbstructmat, ...
%         min_n_channels, ...
%         alpha);
% end
% 
% % Sort bootstrapped distribution is then sorted to obtain a threshold for a
% % given alpha
% % Comment: Unnecessary, as limo_cluster_test already does this for us.
% U = round((1 - alpha) * n_boot);
% boot_max_cluster_sum_sorted = sort(boot_max_cluster_sum, 1);
% max_cluster_sum_threshold = boot_max_cluster_sum_sorted(U);
% 
% 
% 
% [mask, pval, maxval, maxclustersum_th] = limo_cluster_test( ...
%     squeeze(one_sample(:, :, 4) .^ 2), ...
%     squeeze(one_sample(:, :, 5)), ...
%     boot_max_cluster_sum, ...
%     expected_chanlocs.channeighbstructmat, ...
%     min_n_channels, ...
%     alpha);


