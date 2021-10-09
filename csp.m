% ----------------------------------------------------------------------- %
%                           H    Y    D    R    A                         %
% ----------------------------------------------------------------------- %
% Function 'csp' trains a Common Spatial Pattern (CSP) filter bank.       %
%                                                                         %
%   Input parameters:                                                     %
%       - X1:   Signal for the positive class, dimensions [C x T], where  %
%               C is the no. channels and T the no. samples.              %
%       - X2:   Signal for the negative class, dimensions [C x T], where  %
%               C is the no. channels and T the no. samples.              %
%                                                                         %
%   Output variables:                                                     %
%       - W:        Filter matrix (mixing matrix, forward model). Note that
%                   the columns of W are the spatial filters.             %
%       - lambda:   Eigenvalues of each filter.                           %
%       - A:        Demixing matrix (backward model).                     %
% ----------------------------------------------------------------------- %
%   Versions:                                                             %
%       - 1.0:     (19/07/2019) Original script.                          %
% ----------------------------------------------------------------------- %
%   Script information:                                                   %
%       - Version:      1.0.                                              %
%       - Author:       V. Martínez-Cagigal                               %
%       - Date:         19/07/2019                                        %
% ----------------------------------------------------------------------- %
%   Example of use:                                                       %
%       csp_example;                                                      %
% ----------------------------------------------------------------------- %
%   References:                                                           %
%       [1]     Blankertz, B., Tomioka, R., Lemm, S., Kawanabe, M., &     %
%               Muller, K. R. (2007). Optimizing spatial filters for robust 
%               EEG single-trial analysis. IEEE Signal processing magazine, 
%               25(1), 41-56.                                             %
% ----------------------------------------------------------------------- %
function [W, lambda, A] = csp(X1, X2)

    % Error detection
    if nargin < 2, error('Not enough parameters.'); end
    if length(size(X1))~=2 || length(size(X2))~=2
        error('The size of trial signals must be [C x T]');
    end
    
    % Compute the covariance matrix of each class
    S1 = cov(X1');   % S1~[C x C]
    S2 = cov(X2');   % S2~[C x C]

    % Solve the eigenvalue problem S1·W = l·S2·W
    [W,L] = eig(S1, S1 + S2);   % Mixing matrix W (spatial filters are columns)
    lambda = diag(L);           % Eigenvalues
    A = (inv(W))';              % Demixing matrix
    
    % Further notes:
    %   - CSP filtered signal is computed as: X_csp = W'*X;
end