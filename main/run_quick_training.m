function run_quick_training(algorithm)
% RUN_QUICK_TRAINING - Simple wrapper for quick training
%
% This function provides a simple interface for the quick_start.bat
% to run quick training with algorithm selection.
%
% Usage:
%   run_quick_training()        % Default DDPG
%   run_quick_training('ddpg')  % DDPG algorithm
%   run_quick_training('td3')   % TD3 algorithm
%   run_quick_training('sac')   % SAC algorithm

if nargin < 1
    algorithm = 'ddpg';
end

fprintf('========================================\n');
fprintf('Quick Training Launcher\n');
fprintf('========================================\n');
fprintf('Algorithm: %s\n', upper(algorithm));
fprintf('Configuration: quick (1 day, 5 episodes)\n');
fprintf('Estimated time: ~5 minutes\n');
fprintf('========================================\n\n');

try
    % Run the training
    train_microgrid_drl('quick', algorithm);
    
    fprintf('\n========================================\n');
    fprintf('INFO: Quick training completed successfully!\n');
    fprintf('========================================\n');
    
catch ME
    fprintf('\n========================================\n');
    fprintf('ERROR: Quick training failed: %s\n', ME.message);
    fprintf('========================================\n');
    rethrow(ME);
end

end
