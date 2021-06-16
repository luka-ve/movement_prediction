function [result] = nanzscore(x)
% Usage: [result] = nanzscore(x)
%
% Calculates the zscore ignoring NANs
%
% Author: Enea Ceolini
    result = bsxfun(@rdivide, bsxfun(@minus, x, mean(x,'omitnan')), std(x, 'omitnan'));
end
