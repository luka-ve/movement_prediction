% Requires:
% github.com/codelableidenvelux/neubee/master
% EEGLAB
% https://github.com/codelableidenvelux/CodelabTapDataProcessing


script_start_time = tic();

DATA_ROOT_PATH = "D:/Coding/Thesis/Data/EEG";
PPT_FILES = ["DS95/12_02_11_04_19.set"];

SAVE_PATH = "~/Thesis/Data/EEG_ICA/";

% Instantiate log file
log_file = instantiate_log_file();


% Recursively find status.mat files
status_files = dir(fullfile(DATA_ROOT_PATH, "**/status.mat"));
status_files = status_files(~[status_files.isdir]);

files_to_analyze = [];
for status_file = status_files
   status = load(status_file);
   
   for substatus = status.eeg_name
       if substatus.EEG == 1 && substatus.Sensor == 1 && substatus.Phone == 1
           files_to_analyze = [files_to_analyze, fullpath(substatus.path, substatus.processed_name)];
       end
   end
end


for ppt_file = files_to_analyze
    % Load File
    EEG = pop_loadset('filename', convertStringsToChars(fullfile(DATA_ROOT_PATH, ppt_file)));
    
    
    
    %% Align taps using decision tree
    % This is done first, as the decision tree also returns a decision
    % about whether participant should be ignored. If ignored, the loop
    % iteration is skipped.
    bandpass_range = [1, 10];    
    bendsensor_data = getcleanedbsdata(EEG.Aligned.BS.Data(:, 1), EEG.srate, bandpass_range);
    
    if size(EEG.Aligned.BS.Data, 2) == 2
        forcesensor_data = EEG.Aligned.BS.Data(:, 2);
    end
    
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
        log_str = [ppt_file, now, simple];
        dlmwrite(log_file, log_str, '-append');
        continue;
    end
    
    %% Add tap indices to list of events for later epoching
    tap_event = struct();
    
    for tap = 1:length(tap_idx)
        tap_event(tap).latency = tap_idx(tap, 2);
        tap_event(tap).duration = 1;
        tap_event(tap).channel = 0;
        tap_event(tap).bvtime = [];
        tap_event(tap).bvmknum = 0;
        tap_event(tap).type = 'Tap';
        tap_event(tap).code = 'Tap';
        tap_event(tap).urevent = 0;
    end
    
    EEG.event = [EEG.event, tap_event];
    
    %% Clean EEG
    EEG = gettechnicallycleanEEG(EEG);
    
    %% Run ICA
    [weights, spheres] = runica(EEG.data, 'ncomps', 64, 'maxsteps', 512);
    
    % Save weights to new file. Append to EEG?
    
    
    % Write to log
    log_str = [ppt_file, now, simple];
    dlmwrite(log_file, log_str, '-append');
end

fprintf("Finished in %.2f seconds. Processed %d files.\n", toc(script_start_time), length(PPT_FILES));
