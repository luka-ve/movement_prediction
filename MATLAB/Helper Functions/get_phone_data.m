function [Phone, Transitions, idx] = get_phone_data(EEG, indices)
%% Get smartphone data based on different alignment rules
%
% **Usage:** [Phone, Transitions, idx] = get_phone_data(EEG, indices)
% 
% Input(s):
%   - EEG = EEG data from one participant
%   - indices =
%       If 0 use uncorrected phone indices
%       If 1 use corrected phone indices
%       If 2 use model corrected phone indices
%
% Output(s):
%   - Phone =
%   - Transitions =
%   - idx =
% Arko Ghosh, Leiden University

if indices == 0 
    Phone_d = []; Marker_d = []; 
    for ff = 1:size(EEG.Aligned.Phone.Blind,2)
        Phone_d = [Phone_d EEG.Aligned.Phone.Blind{1,ff}(:,2)'];
        Marker_d = [Marker_d min(EEG.Aligned.Phone.Blind{1,ff}(:,2)')];
    end
elseif indices == 1
    Phone_d = []; Marker_d = []; 
    for ff = 1:size(EEG.Aligned.Phone.Corrected,2)
        Phone_d = [Phone_d EEG.Aligned.Phone.Corrected{1,ff}(:,2)'];
        Marker_d = [Marker_d min(EEG.Aligned.Phone.Corrected{1,ff}(:,2)')];
    end
elseif indices == 2
    Phone_d = []; Marker_d = []; 
    for ff = 1:size(EEG.Aligned.BSnet.Phone.Corrected,2)
        Phone_d = [Phone_d EEG.Aligned.Phone.Model{1,ff}(:,2)'];
        Marker_d = [Marker_d min(EEG.Aligned.Phone.Model{1,ff}(:,2)')];
    end
end

Phone = double(ismember(1:EEG.pnts, Phone_d));
Transitions = double(ismember(1:EEG.pnts, Marker_d));
Transitions(Transitions<1) = deal(NaN) ;

idx = find(Phone>0.1); 
idx(diff(idx)<200) = [];

idx = find(Phone>0.1); 
idx(diff(idx)<200) = [];