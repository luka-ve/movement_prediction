function plot_FS_distribution(data, event_type)
% USAGE:
% data: A vector of FS peak values around taps
% event_type: A string saygint which kind of event the data was locked to.
% Only used for plot title.
    if ~exist('event_type', 'var')
        event_type = " ";
    end
    
    figure;
    
    histogram(data(:, end));
    
    title(join(["FS_{hat} max distribution of event type", event_type], " "));
end