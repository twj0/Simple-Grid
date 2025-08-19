function setup_project_paths()
% SETUP_PROJECT_PATHS - Adds all necessary project subfolders to the MATLAB path.
% This script should be run once from the 'main' directory at the start of
% each MATLAB session to ensure all functions are available.

% Get the directory of this script (the 'main' directory)
main_dir = fileparts(mfilename('fullpath'));

disp('Adding project paths...');

% Add the 'config' directory
config_dir = fullfile(main_dir, 'config');
if exist(config_dir, 'dir')
    addpath(config_dir);
end

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
        fprintf('INFO: Workspace data loaded successfully.\n');
    else
        fprintf('INFO: Workspace data not available. Run `complete_fix` to generate it.\n');
    end
catch ME
    fprintf('ERROR: Failed to load workspace data: %s\n', ME.message);
end

% Test scientific configuration system access after path setup
fprintf('\nTesting configuration access...\n');
try
    config = simulation_config('quick_1day');
    fprintf('Configuration loaded: %s\n', config.meta.config_name);
    fprintf('  Simulation: %d days, %d episodes, %e hours/step\n', ...
            config.simulation.days, config.simulation.episodes, config.simulation.time_step_hours);
    fprintf('  Battery: %d kWh, %d kW\n', ...
            config.system.battery.capacity_kwh, config.system.battery.power_kw);
    if config.hardware.use_gpu
        fprintf('  Hardware: GPU\n');
    else
        fprintf('  Hardware: CPU\n');
    end
    if config.simulink.use_simulink
        fprintf('  Simulink Model: %s (REQUIRED)\n', config.simulink.model_name);
    else
        fprintf('  Simulink Model: Disabled\n');
    end
    fprintf('INFO: Configuration access test passed.\n');
catch ME
    fprintf('ERROR: Configuration access test failed: %s\n', ME.message);
    fprintf('Attempting to fix path issues...\n');

    % Try to find and add config directory explicitly
    config_dir = fullfile(main_dir, 'config');
    if exist(config_dir, 'dir')
        addpath(config_dir);
        fprintf('Added config directory explicitly: %s\n', config_dir);
        rehash;
        try
            config = simulation_config('quick_1day');
            fprintf('INFO: Configuration path fix was successful.\n');
        catch
            fprintf('ERROR: Configuration is still not accessible after attempting to fix the path.\n');
        end
    end
end

end
