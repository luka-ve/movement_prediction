% Requires:
% github.com/codelableidenvelux/neubee/master
% EEGLAB

DATA_ROOT_PATH = "D:/Coding/Thesis/Data/EEG";
PPT_FILES = ["DS99/08_05_25_04_19.set"];
%PPT_FILES = ["DS99/08_05_25_04_19.set", "DS99/10_19_25_04_19.set"];

opts = struct();

opts.lowpass_freq = 45;
opts.highpass_freq = [];
opts.max_dist_between_sections = 30000;
opts.activity_windows_padding = 30000;

opts.stft_window = hann(64, "periodic");
opts.stft_overlap = floor(length(opts.stft_window) / 2); % 50% stride
opts.stft_FFTLength = 64;

opts.h5_save_path = fullfile("D:/Coding/Thesis/Data/STFT Output");


for ppt_file = PPT_FILES
    EEG = pop_loadset('filename', convertStringsToChars(fullfile(DATA_ROOT_PATH, ppt_file)));
    
    taps_all = concatenate_taps(EEG);
    
    EEG_clean = gettechnicallycleanEEG(EEG, opts.highpass_freq, opts.lowpass_freq);
    EEG_data_split = split_EEG(EEG_clean, taps_all, opts);
    EEG_data_split = perform_STFT(EEG_data_split, EEG.srate, opts);
    
    ppt_info = split(ppt_file, "/");
    
    filepath = export_as_h5(EEG_data_split, ppt_info(1), ppt_info(2), opts);
    
    fprintf("H5 file exported to %s\n", filepath);
end

fprintf("Finished exporting to %s\n", opts.h5_save_path); 
