% Requires:
% github.com/codelableidenvelux/neubee/master
% EEGLAB
% https://github.com/codelableidenvelux/CodelabTapDataProcessing

 
diary '/home/luka/Thesis/movement_prediction/MATLAB/Log/diary.txt';
diary on;

script_start_time = tic();

DATA_ROOT_PATH = "/media/Storage/Common_Data_Storage/EEG/Feb_2018_2020_RUSHMA_ProcessedEEG";
SAVE_PATH = "/media/Storage/User_Specific_Data_Storage/luka/EEG_ICA";


log_msg = sprintf('Looking for files in %s', DATA_ROOT_PATH);
disp(log_msg);
write_log_entry(log_msg, struct());

% Recursively find status.mat files
status_files = dir(fullfile(DATA_ROOT_PATH, "/DS*/Status.mat"));
status_files = status_files(~[status_files.isdir])';

files_to_analyze = {};
for status_file = status_files
   status = load(fullfile(status_file.folder, status_file.name));
   
   for substatus = status.eeg_name
       if substatus.EEG == 1 && substatus.Sensor == 1 && substatus.Phone == 1
           files_to_analyze(end+1).full_path = fullfile(status_file.folder, [substatus.processed_name, '.set']);
           files_to_analyze(end).subfolder = status_file.folder((regexp(status_file.folder, '/(?<=\/)\w+(?=$|(\/$))')+1):end);
           files_to_analyze(end).filename = substatus.processed_name;
           files_to_analyze(end).status_file = fullfile(status_file.folder, status_file.name);
       end
   end
end

% Config parameters
config.do_ica = logical(1);
config.min_FS_tap_distance = 500; % In milliseconds
config.EEG_hipass = 0.1;
config.EEG_lopass = 30;


%% ONLY FOR DEBUGGING %%
%%%%%%%%%%%%%%%%%%%%%%%%
%files_to_analyze = files_to_analyze(1);


%% Print out number of files
log_msg = sprintf('Found %d files. Starting analysis.', length(files_to_analyze));
disp(log_msg);
write_log_entry(log_msg, struct());

clear status status_file substatus;


%% ICA
for ppt = 1:length(files_to_analyze)
    ppt_file = files_to_analyze(ppt);
    
    start_time_ppt = tic();
    
    
    
    
    % Check if file already exists in save folder.
    % If so, skip participant.
    if exist(fullfile(SAVE_PATH, ppt_file.subfolder, [ppt_file.filename, '_ICA.set']), 'file')
        log_msg = 'Skipping participant: Target save file already exists';
        disp(log_msg);
        write_log_entry(log_msg, ppt_file);
        continue;
    end
    
    % Load File
    log_msg = ['Starting participant ', ppt_file.subfolder, '/', ppt_file.filename, ' ...'];
    write_log_entry(log_msg, ppt_file);
    EEG = pop_loadset('filename', convertStringsToChars(ppt_file.full_path));
    
    % Check if ppt has FS data
    % If not, skip
    if size(EEG.Aligned.BS.Data, 2) < 2
        log_msg = 'Skipping participant: No FS data';
        disp(log_msg);
        write_log_entry(log_msg, ppt_file);
        continue;
    end
    
    
    %% Align taps using decision tree
    % This is done first, as the decision tree also returns a decision
    % about whether participant should be ignored. If ignored, the loop
    % iteration is skipped.
    bandpass_range_BS = [1, 10];    
    bendsensor_data = getcleanedbsdata(EEG.Aligned.BS.Data(:, 1), EEG.srate, bandpass_range_BS);
    
    [EEG, simple] = decision_tree_alignment(EEG, bendsensor_data, 0);
    
    tap_idx = [];
    
    if simple == 1
        % Use model-based alignment
        tap_idx = concatenate_taps(EEG.Aligned.Phone.Model);
    elseif simple == 2
        % Use BS-based alignment
        tap_idx = concatenate_taps(EEG.Aligned.Phone.Corrected);
    elseif simple == 3
        % Discard participant
        log_msg = 'Skipping participant: Bad alignment.';
        write_log_entry(log_msg, ppt_file);
        continue;
    end
    
    tap_idx = tap_idx(:, 2);
    
    if isempty(tap_idx)
        log_msg = 'Skipping participant: No tap indices found.';
        write_log_entry(log_msg, ppt_file);
        continue;
    end
    
    %% Add tap indices to list of events
    %tap_event = struct();
        
    for tap = 1:length(tap_idx)
        EEG.urevent(end + 1).latency = tap_idx(tap);
        EEG.urevent(end).duration = 0.1;
        EEG.urevent(end).type = 'Tap';
        EEG.urevent(end).code = 'Tap';
        
        EEG.event(end + 1).latency = tap_idx(tap);
        EEG.event(end).duration = 0.1;
        EEG.event(end).type = 'Tap';
        EEG.event(end).code = 'Tap';
        EEG.event(end).urevent = length(EEG.urevent);        
    end
    
    
    
    
    %% Handle FS data
    % If FS data present, extract it  
    FS_sampling_rate = 1000;

    FS_data = EEG.Aligned.BS.Data(:, 2);

    % Generate FS events
    FS_event_idx = get_FS_taps(FS_data, FS_sampling_rate, config.min_FS_tap_distance);

    if isempty(FS_event_idx)
        log_msg = 'Skipping participant: No force sensor events detected.';
        write_log_entry(log_msg, ppt_file);
        continue;
    end
    
    
    % Add FS events
    %FS_events = struct();

    for FS_event = 1:length(FS_event_idx)
        EEG.urevent(end + 1).latency = FS_event_idx(FS_event);
        EEG.urevent(end).duration = 0.1;
        EEG.urevent(end).type = 'FS_event';
        EEG.urevent(end).code = 'FS_event';
        
        EEG.event(end + 1).latency = FS_event_idx(FS_event);
        EEG.event(end).duration = 0.1;
        EEG.event(end).type = 'FS_event';
        EEG.event(end).code = 'FS_event';
        EEG.event(end).urevent = length(EEG.urevent); 
    end
    
       
    
    %% Select subsequences
    % Padding size determines how many samples the regions are extended beyond the first and last event. 
    % Take care that it is not larger that max_dist / 2. Otherwise, regions
    % might overlap. This should not be a problem, since EEGLAB will
    % automatically merge overlapping regions when doing pop_select.
    
    max_dist_between_subsequences_in_samples = ms2idx(100000, EEG.srate);
    padding_size = 15000;
    EEG_tap_sequences = split_EEG(EEG.data, tap_idx, max_dist_between_subsequences_in_samples, padding_size, EEG.srate);
    EEG_FS_subsequences = split_EEG(FS_data', FS_event_idx, max_dist_between_subsequences_in_samples, padding_size, 1000);
    
    
    %% Clean EEG
    try
        EEG = gettechnicallycleanEEG(EEG, config.EEG_hipass, config.EEG_lopass);
    catch ME
        write_log_entry(ME.message, ppt_file);
        continue;
    end
    
    %% Select only regions with phone taps and FS taps
    tap_region_timestamps_seconds = reshape([EEG_tap_sequences(:).timestamps], 2, [])';
    FS_region_timestamps_seconds = reshape([EEG_FS_subsequences(:).timestamps], 2, [])';
    
    regions = vertcat(tap_region_timestamps_seconds, FS_region_timestamps_seconds);
    regions = sortrows(regions, 1);
    
    log_msg = sprintf('%d regions concatenated. %d FS regions, %d phone tap regions', size(regions, 1), size(FS_region_timestamps_seconds, 1), size(tap_region_timestamps_seconds, 1));
    write_log_entry(log_msg, ppt_file);
    
    EEG_taps_only = pop_select(EEG, 'point', regions);
    
    %% Run ICA on subsequences containing taps
    % For this, the data can simply be concatenated, since ICA considers
    % time points independently. Therefore, the discontinuity of
    % concatenated EEG data is not an issue here.
    if config.do_ica
        try
            EEG_taps_only = pop_runica(EEG_taps_only, 'icatype', 'runica');
        catch ME
            write_log_entry(ME.message, ppt_file);
            continue;
        end
    else
        write_log_entry('Skipping ICA: do_ica == false', ppt_file);
    end
    

    %% Save weights to new file.
    % Do this by either saving weights and spheres to a new file or
    % appending them to the original EEG script.
    % The issue with appending is that ICA weights will have been
    % calculated based on a specific prior cleaning step, not on the
    % EEG.data that was present in the original EEG struct.
    
    % Generate EEG file name
    % Check if subfolder exists
    if ~exist(fullfile(SAVE_PATH, ppt_file.subfolder), 'dir')
        mkdir(fullfile(SAVE_PATH, ppt_file.subfolder))
    end
    
    EEG_taps_only = pop_saveset(EEG_taps_only, 'filename', [ppt_file.filename, '_ICA.set'], 'filepath', convertStringsToChars(fullfile(SAVE_PATH, ppt_file.subfolder)));
    
    % Copy Status.mat
    [exit_code, msg] = copyfile(ppt_file.status_file, fullfile(SAVE_PATH, ppt_file.subfolder));
    
    elapsed_time = toc(start_time_ppt);
    log_msg = sprintf(['Finished participant ', ppt_file.subfolder, '/', ppt_file.filename, ' in %.0f minutes.'], elapsed_time / 60);
    disp(log_msg);
    write_log_entry(log_msg, ppt_file);
    
    clear EEG_taps_only log_msg start_time_ppt;
end

elapsed_time = toc(script_start_time);
log_msg = sprintf("Finished in %.0f minutes. Processed %d files.\n", elapsed_time / 60, length(files_to_analyze));
disp(log_msg);
write_log_entry(log_msg, struct());

diary off;