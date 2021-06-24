clear;


%% Load data selected independent components
DATA_ROOT = "/media/Storage/User_Specific_Data_Storage/luka/EEG_ICA/";
SAVE_PATH_ROOT = "/media/Storage/User_Specific_Data_Storage/luka/EEG_STUDY/";

% Load table form excel file
component_selection_path = "MATLAB/Component Selection.xlsx";
component_selection = read_input_files(component_selection_path, DATA_ROOT, "Both");

% Settings
taps_to_observe = [-1, 1]; % Which surrounding taps to observe
epoch_size = [-3, 0.5];
FS_hat_max_window = [-400, 400]; % In samples
event_names = {'FS_event', 'Tap'};

do_resample = 0;
new_sampling_rate = 1000; % Hz
starting_dir = '/home/luka/Thesis/movement_prediction';

% ONLY FOR TESTING
%component_selection = component_selection(1:8, :);

%% Step 1
tic();

for event_name_cell = event_names
    event_name = event_name_cell{1};    

    SAVE_PATH = fullfile(SAVE_PATH_ROOT, event_name);

    if ~exist(SAVE_PATH, 'dir')
        mkdir(SAVE_PATH)
    end
    

    

    % Arrays to keep information about files locations.
    inter_tap_intervals = {};
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
        comps_to_reject = 1:size(EEG1.icaact, 1);
        comps_to_reject(comps_to_keep) = [];

        % Reject non-selected components
        EEG1 = pop_subcomp(EEG1, comps_to_reject);

        % Interpolate missing channels
        EEG1 = pop_interp(EEG1,EEG1.Orignalchanlocs,'spherical');


        % Extract tap distances
        delta_times_per_tap = {};
        
        tap_event_indices = find(strcmp({EEG1.event.code}, event_name));    
        tap_events = EEG1.event(tap_event_indices);
        tap_latencies = [tap_events.latency];
        [delta_times_per_tap{end + 1}, inter_tap_intervals{end + 1}] = get_tap_deltas(tap_latencies, taps_to_observe, EEG1.srate);
        EEG1.etc.delta_times_per_tap = delta_times_per_tap{end};
        EEG1.etc.delta_K_set = taps_to_observe;


        % Add tap distance information to EEG.event struct
        field_names = {};
        for tap_idx = 1:length(delta_times_per_tap{end})
            tap_event_idx = tap_event_indices(delta_times_per_tap{end}(tap_idx).tap_idx);

            for delta_t = 1:length(taps_to_observe)
                field_name = sprintf("t%d", taps_to_observe(delta_t));
                field_name = strrep(field_name, '-', 'm');
                field_names{delta_t} = field_name;

                % Set delta to NaN if taps are at concatenated border
                if any(abs(delta_times_per_tap{end}(tap_idx).deltas) >= 60000)
                    EEG1.event(tap_event_idx).(field_name) = NaN;
                else
                    EEG1.event(tap_event_idx).(field_name) = delta_times_per_tap{end}(tap_idx).deltas(delta_t);
                end
            end
        end    

        % Generate epochs
        EEG1 = pop_epoch(EEG1, {event_name}, epoch_size);
        
        EEG1 = pop_rmbase(EEG1, [-3000, -2500]);

        % Reject epochs based on thresholding
        electrodes_to_reject = [1:62];
        voltage_lower_threshold = -80; % In mV
        voltage_upper_threshold = 80;
        start_time = epoch_size(1);
        end_time = epoch_size(2);
        do_superpose = 0;
        do_reject = 1;
        EEG1 = pop_eegthresh(EEG1, 1, electrodes_to_reject, voltage_lower_threshold, voltage_upper_threshold, start_time, end_time, do_superpose, do_reject);

        % Define continuous predictors
        continuous = zeros(size(EEG1.epoch, 2), size(taps_to_observe, 2));
        for this_epoch = 1:size(EEG1.epoch, 2)
            which_current_event = find(cell2mat(EEG1.epoch(this_epoch).eventlatency) == 0);

            % Handle edge case in which multiple events have the exact same
            % latency (E.g., when stimulus and tap overlay exactly)
            correct_event = which_current_event(strcmp({EEG1.epoch(this_epoch).eventcode{which_current_event}}, event_name));

            % Extract predictor info
            for current_delta = 1:length(taps_to_observe)
                continuous(this_epoch, current_delta) = EEG1.epoch(this_epoch).(join(["event", field_names{current_delta}], '')){correct_event};
            end
            
            
            % Add FS_hat_max as predictor
            %idx_in_urevent = EEG1.epoch(this_epoch).eventurevent{correct_event};
            %latency_in_FS_signal = EEG1.urevent(idx_in_urevent).latency;
            %max_value_in_range = max(EEG1.Aligned.BS.Model((latency_in_FS_signal + FS_hat_max_window(1)):(latency_in_FS_signal + FS_hat_max_window(2))));
            %
            %continuous(this_epoch, end) = max_value_in_range;
        end

        continuous = log10(abs(continuous));


        % Save epoched and processed data to new file
        if ~exist(fullfile(SAVE_PATH, ppt_info.Participant), 'dir')
            mkdir(fullfile(SAVE_PATH, ppt_info.Participant));
        end
        pop_saveset(EEG1, 'filename', ppt_info.Filename, 'filepath', convertStringsToChars(fullfile(SAVE_PATH, ppt_info.Participant)));


        save(fullfile(SAVE_PATH, ppt_info.Participant, [ppt_info.Filename(1:end-4), '_continuous.mat']), 'continuous');

        % Add to file arrays
        set_files{end + 1} = char(fullfile(SAVE_PATH, ppt_info.Participant, ppt_info.Filename));
        cont_files{end + 1} = char(fullfile(SAVE_PATH, ppt_info.Participant, [ppt_info.Filename(1:end-4), '_continuous.mat']));


        % Do LIMO 1st level analysis using LIMO struct
        
        % Generate Y
        Y = EEG1.data;    
        
        % Remove trials with NaN
        % This is necessary since limo_design_matrix will automatically remove
        % trials with NaNs in the predictors.
        % NaNs are introduced to the data by the get_tap_deltas function.
        Y(:, :, any(isnan(continuous), 2)) = [];
        continuous(any(isnan(continuous), 2), :) = [];

        % Basic setup
        Cat = [];
        Cont = continuous;

        LIMO = struct();
        LIMO.Level                    = 1;
        LIMO.dir                      = fullfile(SAVE_PATH, ppt_info.Participant);
        LIMO.Analysis = 'Time';
        LIMO.Type = 'Channels';

        LIMO.data.data_dir            = fullfile(SAVE_PATH, ppt_info.Participant);
        LIMO.data.data                = ppt_info.Filename;
        LIMO.data.chanlocs            = EEG1.chanlocs;
        LIMO.data.start               = -3000;
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

        

        [LIMO.design.X, LIMO.design.nb_conditions, LIMO.design.nb_interactions, LIMO.design.nb_continuous] = limo_design_matrix(Y, LIMO, 0);

        LIMO.design.status = 'to do';
        LIMO.design.name = 'Delta times';

        if (numel(Y) == 0)
            continue;
        end


        LIMO.model = cell(size(Y, 1), 1);

        try
            for current_electrode = 1:size(Y, 1)
                Y_now = squeeze(Y(current_electrode, :, :))';
                LIMO.model{current_electrode} = limo_glm(Y_now, LIMO);
            end
        catch ME
            write_log_entry(ME.message, struct());
            continue;
        end

        LIMO.model = [LIMO.model{:}];
        LIMO.File = ppt_info.Filename;
        inter_tap_intervals{end + 1} = delta_times_per_tap;
        
        
        LIMOs{ppt_no} = LIMO;
        

        LIMO_savepath = fullfile(SAVE_PATH, ppt_info.Participant, 'LIMO.mat');
        save(LIMO_savepath, 'LIMO');
        LIMO_files{end + 1} = LIMO_savepath;
        
        % Rename files generated by LIMO
        movefile("Betas.mat", sprintf("Betas_%s.mat", ppt_info.Filename(1:(end-4))));
        movefile("R2.mat", sprintf("R2_%s.mat", ppt_info.Filename(1:(end-4))));
        movefile("LIMO.mat", sprintf("LIMO_%s.mat", ppt_info.Filename(1:(end-4))));
        movefile("Res.mat", sprintf("Res_%s.mat", ppt_info.Filename(1:(end-4))));
        movefile("Yhat.mat", sprintf("Yhat_%s.mat", ppt_info.Filename(1:(end-4))));
        movefile("Yr.mat", sprintf("Yr_%s.mat", ppt_info.Filename(1:(end-4))));
    end

    cd(starting_dir);

    % Save
    event_type_subdir = ['LIMO_output_', event_name];
    mkdir(event_type_subdir);

    save(fullfile(pwd(), event_type_subdir, 'save_locations.mat'), 'set_files', 'cont_files', 'LIMO_files');

    LIMOs = [LIMOs{:}];
    save(fullfile(pwd(), event_type_subdir, 'ALL_LIMO_INFO.mat'), 'LIMOs');
    save(fullfile(pwd(), event_type_subdir, 'inter_tap_intervals.mat'), 'inter_tap_intervals');
    
    disp(sprintf("Done for event type %s", event_name));
end



%% LIMO Step 2

for event_name_cell = event_names
    event_name = event_name_cell{1};
    
    %% Setup
    % Go into the sub directory for the current event type
    event_type_subdir = ['LIMO_output_', event_name];
    cd(fullfile(starting_dir, event_type_subdir));
    load('ALL_LIMO_INFO.mat');
    load('save_locations.mat');
    expected_chanlocs = load('~/Thesis/movement_prediction/MATLAB/expected_chanlocs.mat');
    
    
    betas = extract_betas(LIMOs);

    LIMO = make_LIMO_struct_step2(SAVE_PATH_ROOT, expected_chanlocs);
    
    LIMO_paths = run_ttests(betas, LIMO);   
    
    load('H0/boot_table');
    
    significance_threshold = 0.05;
    [mask, cluster_p, one_sample] = run_clustering(LIMO_paths, significance_threshold, expected_chanlocs);
    save('clustering_output.mat', 'mask', 'cluster_p', 'one_sample');
    
    
    
    %% Go back to base dir
    cd(starting_dir);
    
end

toc();

%% Plots
% Setup
load('LIMO_output_Tap/clustering_output.mat', 'mask', 'cluster_p', 'one_sample');
load('LIMO_output_Tap/ALL_LIMO_INFO.mat', 'LIMOs');
%%
epoch_size = [-3, 0.5]; % In seconds
betas = extract_betas(LIMOs);

% Plot betas for each electrode
%%
electrodes = [1, 2, 6, 10, 16];
PlottingFunctions.plot_betas(betas, electrodes, epoch_size, true);
%%
% Plot clusters
PlottingFunctions.plot_significant_clusters(mask, cluster_p, epoch_size);



%% Local functions

function betas = extract_betas(LIMOs)
    n_betas = size(LIMOs(1).model(1).betas, 1);
    epoch_size = size(LIMOs(1).model(1).betas, 2);
    
    % Dimensions: electrodes * frames * betas * participants
    
    betas = zeros(64, epoch_size, n_betas, size(LIMOs, 2));
    
    for ppt = 1:size(LIMOs, 2)
        current_ppt_limo = LIMOs(ppt);
        
        for electrode = 1:size(current_ppt_limo.model, 2)
            betas(electrode, :, :, ppt) = current_ppt_limo.model(electrode).betas';
        end
    end
end

function LIMO = make_LIMO_struct_step2(data_root_folder, expected_chanlocs)
    % Find beta files in save path
    beta_file_locs = dir([char(data_root_folder), '**/Betas*.mat']);    
    beta_file_locs = [{beta_file_locs(:).folder}; {beta_file_locs(:).name}]';

    LIMO = struct();
    LIMO.dir = pwd();
    LIMO.Analysis = 'Time';
    LIMO.Level = 2;
    
    LIMO.data.chanlocs = expected_chanlocs.expected_chanlocs;
    LIMO.data.neighbouring_matrix = expected_chanlocs.channeighbstructmat;
    LIMO.data.data = beta_file_locs{:, 2};
    LIMO.data.data_dir = beta_file_locs{:, 1};
    LIMO.data.sampling_rate = 1000;
    LIMO.design.bootstrap = 1000;
    LIMO.design.tfce = 0;
    LIMO.design.name = 'one sample t-test all electrodes';
    LIMO.design.electrode = [];
    LIMO.design.X = [];
    LIMO.design.method = 'Trimmed Mean';
    
    save('LIMO.mat', 'LIMO');
end

function LIMO_paths = run_ttests(betas, LIMO)
    LIMO_paths(size(betas,3)) = string();
    
    for current_beta_index = 1:size(betas,3)
        current_beta = squeeze(betas(:, :, current_beta_index, :));
        
        LIMO_paths(current_beta_index) = limo_random_robust(1, current_beta, current_beta_index, LIMO);
    end
end

function [mask, cluster_p, one_sample] = run_clustering(LIMO_paths, significance_threshold, expected_chanlocs)
    %min_n_channels = 2;
    %n_boot = size(boot_table{1}, 2);
    
    % Initialize empty matrices
    %mask = zeros(size(betas, 1), size(betas, 2), size(LIMO_paths, 2));
    %cluster_p = zeros(size(betas, 1), size(betas, 2), size(LIMO_paths, 2));
    
    %one_sample = zeros(size(betas, 1), size(betas, 2), 5, size(LIMO_paths, 2));
    
    for current_beta = size(LIMO_paths, 2):-1:1
        one_sample_tmp = load(fullfile(LIMO_paths{current_beta}, sprintf('one_sample_ttest_parameter_%d.mat', current_beta)), 'one_sample');
        one_sample(:, :, :, current_beta) = one_sample_tmp.one_sample;
        
        load(fullfile(LIMO_paths{current_beta}, 'H0', sprintf('H0_one_sample_ttest_parameter_%d.mat', current_beta)), 'H0_one_sample');
        
        [mask(:, :, current_beta), cluster_p(:, :, current_beta)] = limo_cluster_correction( ...
            squeeze(one_sample(:, :, 4, current_beta) .^ 2), ...
            squeeze(one_sample(:, :, 5, current_beta)), ...
            squeeze(H0_one_sample(:, :, 1, :) .^ 2), ...
            squeeze(H0_one_sample(:, :, 2, :)), ...
            expected_chanlocs.channeighbstructmat, ...
            2, ...
            significance_threshold);
    end
end

function component_selection = read_input_files(component_selection_path, data_path, which_components)
% Input:
% which_components: String. Which selected components to keep. Possible options: "Prep", "Brain", or "Both"
    component_selection = readtable(component_selection_path);

    % Convert comma-separated string to numeric array
    if strcmp(which_components, "Prep")
        component_selection.SelectedComponentsNum = cellfun(@(x) [str2num(char(x))], component_selection.PreparationOrientedComponents, 'UniformOutput', false);
    elseif strcmp(which_components, "Brain")
        component_selection.SelectedComponentsNum = cellfun(@(x) [str2num(char(x))], component_selection.BrainComponents, 'UniformOutput', false);
    elseif strcmp(which_components, "Both")
        component_selection.SelectedComponentsNum = cellfun(@(x) [str2num(char(x))], component_selection.PreparationOrientedComponents, 'UniformOutput', false);
        brain_components = cellfun(@(x) [str2num(char(x))], component_selection.BrainComponents, 'UniformOutput', false);
        
        for comp = 1:size(component_selection, 1)
            component_selection.SelectedComponentsNum{comp} = unique(sort([component_selection.SelectedComponentsNum{comp}, brain_components{comp}]));
        end
        
        %component_selection.SelectedComponentsNum = horzcat(component_selection.SelectedComponentsNum{:}, brain_components{:});
    end
    % Remove files from table that don't exist in data root folder or
    % entries without good components
    removable_entries = [];
    for file_ = 1:size(component_selection, 1)
        if ~exist(fullfile(data_path, component_selection.Participant(file_), component_selection.Filename(file_)), 'file') | ...
            component_selection.HasGoodComponents(file_) == 0
            removable_entries(end + 1) = file_;
        end
    end
    component_selection(removable_entries, :) = [];
end






