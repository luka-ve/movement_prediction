function EEG_data_split = perform_STFT(EEG_data_split, sampling_rate, opts)
    % Performs STFT
    % Returns the log of the squared absolute value of the STFT output.
    
    for idx = 1:size(EEG_data_split, 2)
        window = opts.stft_window;
        overlap = opts.stft_overlap;
        FFTLength = opts.stft_FFTLength;

        [EEG_stft, freqs, times] = stft(...
            EEG_data_split(idx).data', sampling_rate,...
            "Window", window,...
            "OverlapLength", overlap,...
            'FFTLength', FFTLength);

        % Remove negative frequencies
        EEG_stft = EEG_stft(ceil(size(EEG_stft, 1)/2 + 1):end, :, :);
        freqs = freqs(ceil(size(freqs, 1)/2 + 1):end);

        % Save stft info into struct
        EEG_data_split(idx).stft = log(abs(EEG_stft).^2);
        EEG_data_split(idx).freqs = freqs;
        EEG_data_split(idx).times = times;
    end
end
