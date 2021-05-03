function [EEG_OUT] = preprocess_data(EEG_IN)
    % Preprocesses and cleans data
    EEG_OUT = gettechnicallycleanEEG(EEG_IN, [], 45);
    
end
