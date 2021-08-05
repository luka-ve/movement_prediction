function jid = iti2JID(itis, varargin)
% Calcuates the Joint Interval Distribution (JID) for the list of taps in
% input. 
%    jid = taps2JID(iti, ...);
%    Positional parameters:
% 
%      itis             An array (Nx1) of inter-tap intervals  in ms.
%    
%    Optional input parameters:
% 
%      'Bins'           Number of bins (per side) in the JID. Basically the
%                       length of the side of the JID matrix.
%      'MinH'           The minimum delta(t) value to consider in the JID
%                       space expressed in log10(ms) space. Default 1.5 ~ 30 ms
%                       10 ^ 1.5 = 31.6.
%      'MaxH'           The maximum delta(t) value to consider in the JID
%                       space expressed in log10 space. Default 5 ~  100 s
%                       10 ^ 5 = 100000.
%      'Bandwidth'      Of the Kernel density estimation. Default is 0.1.
%
%   Returns: JID a matrix of size Bins-by-Bins. 
%
%   Example: basic JIS of taps sequences.
%   SUBJECT = getTapDataParsed('138eff3d0b5c67d04df39c63e6f978e62e8628eb');
%   all_taps = double(cell2mat(SUBJECT.taps.taps));  % in ms
%   JID = taps2JID(all_taps); 
% 
% Enea Ceolini, Leiden University, 26/05/2021

p = inputParser;
addRequired(p,'itis');
addOptional(p,'Bins', 50);
addOptional(p,'MinH', 1.5);
addOptional(p,'MaxH', 5.0);
addOptional(p,'Bandwidth', 0.1);

parse(p,itis,varargin{:});

BINS = p.Results.Bins;
MIN_H = p.Results.MinH;
MAX_H = p.Results.MaxH;
bandwidth = p.Results.Bandwidth;


dt = log10(itis);

dt_dt = [dt(1:end-1), dt(2:end)];

gridx = linspace(MIN_H, MAX_H, BINS);

[x1, x2] = meshgrid(gridx, gridx);
x1 = x1(:);
x2 = x2(:);
xi = [x1 x2];

jid = reshape(ksdensity(dt_dt,xi, 'Bandwidth', bandwidth), BINS, BINS);

