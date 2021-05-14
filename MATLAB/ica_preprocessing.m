% Requires:
% github.com/codelableidenvelux/neubee/master
% EEGLAB
% https://github.com/codelableidenvelux/CodelabTapDataProcessing


diary '/home/luka/Thesis/movement_prediction/MATLAB/Log/diary.txt';
diary on;

script_start_time = tic();

DATA_ROOT_PATH = "/media/Storage/Common_Data_Storage/EEG/Feb_2018_2020_RUSHMA_ProcessedEEG";

%PPT_FILES = ["DS95/12_02_11_04_19.set"];

SAVE_PATH = "/media/Storage/User_Specific_Data_Storage/luka/EEG_ICA";



log_msg = sprintf('Looking for files in %s', DATA_ROOT_PATH);
disp(log_msg);
write_log_entry(log_msg, struct());

% Recursively find status.mat files
status_files = dir(fullfile(DATA_ROOT_PATH, "/**/Status.mat"));
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


%% ONLY FOR DEBUGGING %%
%%%%%%%%%%%%%%%%%%%%%%%%
%files_to_analyze = files_to_analyze1;


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
    if exist(fullfile(SAVE_PATH, ppt_file.subfolder, [ppt_file.filename, '_taps.set']), 'file')
        log_msg = 'Skipping participant: Target save file already exists';
        disp(log_msg);
        write_log_entry(log_msg, ppt_file);
        continue;
    end
    disp(['Analyzing participant ', ppt_file.subfolder, '/', ppt_file.filename, '...']); 
    
    % Load File
    log_msg = ['Starting participant ', ppt_file.subfolder, '/', ppt_file.filename, ' ...'];
    write_log_entry(log_msg, ppt_file);
    EEG = pop_loadset('filename', convertStringsToChars(ppt_file.full_path));
    
    
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
    
    
    %% Add tap indices to list of events for LiMo epoching
    tap_event = struct();
    
    % Ensure that all fields in the original .events struct are also
    % present in new tap events
    for tap = 1:length(tap_idx)
        tap_event(tap).latency = tap_idx(tap);
        tap_event(tap).duration = 1;
        tap_event(tap).channel = 0;
        tap_event(tap).bvtime = [];
        tap_event(tap).bvmknum = 0;
        tap_event(tap).type = 'Tap';
        tap_event(tap).code = 'Tap';
        tap_event(tap).urevent = 0;
    end
    
    if ~isempty(tap_idx)
        EEG.event = [EEG.event, tap_event];
    else
        log_msg = 'Skipping participant: No tap indices found.';
        write_log_entry(log_msg, ppt_file);
        continue;
    end
    
    
    %% Clean EEG
    try
        EEG = gettechnicallycleanEEG(EEG, 0.1, 30);
    catch ME
        write_log_entry(ME.message, ppt_file);
        continue;
    end
    
    
    %% Extract subsequences than contain phone taps so that ICA only acts on
    % relevant sequences
    max_dist_between_subsequences_in_samples = ms2idx(100000, EEG.srate);
    
    % Padding size determines how many samples the regions are extended beyond the first and last event. 
    % Take care that it is not larger that max_dist / 2. Otherwise, regions
    % might overlap. This should not be a problem, since EEGLAB will
    % automatically merge overlapping regions when doing pop_select.
    padding_size = 20000;
    EEG_tap_sequences = split_EEG(EEG.data, tap_idx, max_dist_between_subsequences_in_samples, 30000, EEG.srate);
    
  
    
    %% Run ICA on subsequences containing taps
    % For this, the data can simply be concatenated, since ICA considers
    % time points independently. Therefore, the discontinuity of
    % concatenated EEG data is not an issue here.
    
    %% Select only regions with taps
    tap_region_timestamps_seconds = idx2ms(reshape([EEG_tap_sequences(:).timestamps], 2, [])', EEG.srate) / 1000;
    
    EEG_taps_only = pop_select(EEG, 'time', tap_region_timestamps_seconds);
    
    %% Run ICA on tap EEG
    try
        EEG_taps_only = pop_runica(EEG_taps_only, 'icatype', 'runica');
    catch ME
        write_log_entry(ME.message, ppt_file);
        continue;
    end
    
    %% Handle FS data
    % If FS data present, extract it and run separate ICA    
    if size(EEG.Aligned.BS.Data, 2) == 2
        FS_sampling_rate = 1000;
        
        FS_data = EEG.Aligned.BS.Data(:, 2);
        
        % Generate FS events
        FS_event_idx = get_FS_taps(FS_data, FS_sampling_rate);
        
        EEG_FS_subsequences = split_EEG(FS_data', FS_event_idx, max_dist_between_subsequences_in_samples, 20000, 1000);
        
        FS_region_timestamps_seconds = idx2ms(reshape([EEG_FS_subsequences(:).timestamps], 2, [])', EEG.srate) / 1000;
        
        % Add FS events
        FS_events = struct();
    
        % Ensure that all fields in the original .events struct are also
        % present in new tap events
        for FS_event = 1:length(FS_event_idx)
            FS_events(FS_event).latency = FS_event_idx(FS_event);
            FS_events(FS_event).duration = 1;
            FS_events(FS_event).channel = 0;
            FS_events(FS_event).bvtime = [];
            FS_events(FS_event).bvmknum = 0;
            FS_events(FS_event).type = 'FS_event';
            FS_events(FS_event).code = 'FS_event';
            FS_events(FS_event).urevent = 0;
        end
        x
        if ~isempty(FS_events)
            EEG.event = [EEG.event, FS_events];
        end
    
        EEG_FS_only = pop_select(EEG, 'time', FS_region_timestamps_seconds);
        
        % Run ICA on FS-event EEG
        try
            EEG_FS_only = pop_runica(EEG_FS_only, 'icatype', 'runica');
        catch ME
            write_log_entry(ME.message, ppt_file);
            %continue;
        end
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
    
    EEG_taps_only = pop_saveset(EEG_taps_only, 'filename', [ppt_file.filename, '_taps.set'], 'filepath', convertStringsToChars(fullfile(SAVE_PATH, ppt_file.subfolder)));
    
    if exist('EEG_FS_only', 'var')
        EEG_FS_only = pop_saveset(EEG_FS_only, [ppt_file.filename, '_FS.set'], convertStringsToChars(fullfile(SAVE_PATH, ppt_file.subfolder)));
    end
    
    % Copy Status.mat
    [exit_code, msg] = copyfile(ppt_file.status_file, fullfile(SAVE_PATH, ppt_file.subfolder));
    
    elapsed_time = toc(start_time_ppt);
    log_msg = sprintf(['Finished participant ', ppt_file.subfolder, '/', ppt_file.filename, ' in %.0f seconds.'], elapsed_time);
    disp(log_msg);
    write_log_entry(log_msg, ppt_file);
    
    clear EEG_FS_only EEG_taps_only log_msg start_time_ppt;
end

elapsed_time = toc(script_start_time);
log_msg = sprintf("Finished in %.0f seconds. Processed %d files.\n", elapsed_time, length(files_to_analyze));
disp(log_msg);
write_log_entry(log_msg, struct());

diary off;