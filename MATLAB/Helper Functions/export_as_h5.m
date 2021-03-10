function [filepath] = export_as_h5(data, participant_id, session_id, opts)
    % Saves the dataset to the location specified in opts.h5_save_path as
    % an .h5 file.
    % The STFT output is split into real and imaginary parts, since complex
    % values are not supported in HDF5.
    %
    % TODO: Put all data of one participant into same file. Make new level
    % for each recording
    
    filename = strcat(participant_id, ".h5");
    session_id_clean = strrep(session_id, ".set", "");
    
    filename_full_path = fullfile(opts.h5_save_path, filename);

    for window = 1:size(data, 2)
        h5create(filename_full_path, sprintf("/%s/window_%d/stft", session_id_clean, window), size(data(window).stft), 'Datatype', 'single');
        h5write(filename_full_path, sprintf("/%s/window_%d/stft", session_id_clean, window), data(window).stft);

        h5create(filename_full_path, sprintf("/%s/window_%d/taps", session_id_clean, window), size(data(window).tap_timestamps), 'DataType', 'int32');
        h5write(filename_full_path, sprintf("/%s/window_%d/taps", session_id_clean, window), data(window).tap_timestamps);
    end
    
    % Write meta data
    h5writeatt(filename_full_path, "/", "original_sampling_rate", opts.srate)
    h5writeatt(filename_full_path, "/", "stft_hopsize", opts.hopsize);
    h5writeatt(filename_full_path, "/", "stft_FFTLength", opts.stft_FFTLength);
    
    filepath = filename_full_path;
end
