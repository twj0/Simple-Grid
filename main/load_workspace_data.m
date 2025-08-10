function success = load_workspace_data()
% LOAD_WORKSPACE_DATA - Load microgrid data variables to workspace
% This function loads the required data variables from .mat files to the base workspace
% ensuring they persist across MATLAB sessions
%
% Returns:
%   success - true if all data loaded successfully, false otherwise

fprintf('=== Loading Workspace Data ===\n');

success = false;
data_dir = fullfile(pwd, 'data');

% Check if data directory exists
if ~exist(data_dir, 'dir')
    fprintf('? Data directory not found: %s\n', data_dir);
    fprintf('Run complete_fix to generate data first\n');
    return;
end

% Define data files
pv_file = fullfile(data_dir, 'pv_power_profile.mat');
load_file = fullfile(data_dir, 'load_power_profile.mat');
price_file = fullfile(data_dir, 'price_profile.mat');
workspace_file = fullfile(data_dir, 'microgrid_workspace.mat');

% Method 1: Try to load combined workspace file
if exist(workspace_file, 'file')
    try
        fprintf('Loading combined workspace file...\n');
        load_data = load(workspace_file);
        
        % Assign variables to base workspace
        assignin('base', 'pv_power_profile', load_data.pv_power_profile);
        assignin('base', 'load_power_profile', load_data.load_power_profile);
        assignin('base', 'price_profile', load_data.price_profile);
        
        fprintf('? All data loaded from combined workspace file\n');
        fprintf('  PV profile: %d points\n', length(load_data.pv_power_profile.Time));
        fprintf('  Load profile: %d points\n', length(load_data.load_power_profile.Time));
        fprintf('  Price profile: %d points\n', length(load_data.price_profile.Time));
        
        success = true;
        return;
        
    catch ME
        fprintf('? Failed to load combined workspace: %s\n', ME.message);
        fprintf('Trying individual files...\n');
    end
end

% Method 2: Load individual files
fprintf('Loading individual data files...\n');
try
    % Load PV profile
    if exist(pv_file, 'file')
        pv_data = load(pv_file);
        assignin('base', 'pv_power_profile', pv_data.pv_power_profile);
        fprintf('? PV profile loaded\n');
    else
        fprintf('? PV profile file not found: %s\n', pv_file);
        return;
    end
    
    % Load load profile
    if exist(load_file, 'file')
        load_data = load(load_file);
        assignin('base', 'load_power_profile', load_data.load_power_profile);
        fprintf('? Load profile loaded\n');
    else
        fprintf('? Load profile file not found: %s\n', load_file);
        return;
    end
    
    % Load price profile
    if exist(price_file, 'file')
        price_data = load(price_file);
        assignin('base', 'price_profile', price_data.price_profile);
        fprintf('? Price profile loaded\n');
    else
        fprintf('? Price profile file not found: %s\n', price_file);
        return;
    end
    
    fprintf('? All individual files loaded successfully\n');
    success = true;
    
catch ME
    fprintf('? Failed to load individual files: %s\n', ME.message);
    return;
end

% Verify data in workspace
fprintf('\nVerifying data in workspace...\n');
required_vars = {'pv_power_profile', 'load_power_profile', 'price_profile'};
all_present = true;

for i = 1:length(required_vars)
    var_name = required_vars{i};
    if evalin('base', sprintf('exist(''%s'', ''var'')', var_name))
        var_data = evalin('base', var_name);
        if isa(var_data, 'timeseries')
            fprintf('  ? %s: %d points\n', var_name, length(var_data.Time));
        else
            fprintf('  ? %s: Wrong type (%s)\n', var_name, class(var_data));
            all_present = false;
        end
    else
        fprintf('  ? %s: Not found in workspace\n', var_name);
        all_present = false;
    end
end

if all_present
    fprintf('? All required variables verified in workspace\n');
    success = true;
else
    fprintf('? Some variables missing or incorrect\n');
    success = false;
end

fprintf('=== Data Loading Complete ===\n');

end
