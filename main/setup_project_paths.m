function setup_project_paths()
% SETUP_PROJECT_PATHS - Adds all necessary project subfolders to the MATLAB path.
% This script should be run once from the 'main' directory at the start of
% each MATLAB session to ensure all functions are available.

% Get the directory of this script (the 'main' directory)
main_dir = fileparts(mfilename('fullpath'));

disp('Adding project paths...');

% Add the 'scripts' root directory
scripts_dir = fullfile(main_dir, 'scripts');
addpath(scripts_dir);

% Add all subdirectories within 'scripts'
addpath(fullfile(scripts_dir, 'agents', 'ddpg'));
addpath(fullfile(scripts_dir, 'agents', 'sac'));
addpath(fullfile(scripts_dir, 'agents', 'td3'));
addpath(fullfile(scripts_dir, 'config'));
addpath(fullfile(scripts_dir, 'data_generation'));
addpath(fullfile(scripts_dir, 'environments'));
addpath(fullfile(scripts_dir, 'models'));
addpath(fullfile(scripts_dir, 'rewards'));
addpath(fullfile(scripts_dir, 'training'));
addpath(fullfile(scripts_dir, 'evaluation'));
addpath(fullfile(scripts_dir, 'visualization'));

% Add Integrated folder for compatibility (if exists)
integrated_path = fullfile(main_dir, '..', 'Integrated');
if exist(integrated_path, 'dir')
    addpath(integrated_path);
    fprintf('Added Integrated folder to path for compatibility\n');
end

disp('Project paths have been set up successfully.');

% Force MATLAB to refresh the path cache, which can solve issues where
% functions are not found even though they are on the path.
rehash;
fprintf('MATLAB path cache has been refreshed.\n');

% Auto-load workspace data if available
fprintf('\nChecking for workspace data...\n');
try
    if load_workspace_data()
        fprintf('? Workspace data loaded successfully\n');
    else
        fprintf('? Workspace data not available - run complete_fix to generate\n');
    end
catch ME
    fprintf('? Failed to load workspace data: %s\n', ME.message);
end

% Test configuration access after path setup
fprintf('\nTesting configuration access...\n');
try
    test_config = model_config();
    fprintf('? Configuration test passed\n');
catch ME
    fprintf('? Configuration test failed: %s\n', ME.message);
    fprintf('Attempting to fix path issues...\n');
    
    % Try to find and add config directory explicitly
    config_dir = fullfile(main_dir, 'scripts', 'config');
    if exist(config_dir, 'dir')
        addpath(config_dir);
        fprintf('Added config directory explicitly: %s\n', config_dir);
        rehash;
        try
            test_config = model_config();
            fprintf('? Configuration fix successful\n');
        catch
            fprintf('? Configuration still not accessible\n');
        end
    end
end

end
