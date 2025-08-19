% =========================================================================
%                           try_plot.m
% -------------------------------------------------------------------------
% Description:
%   This script loads a pre-trained DRL agent, runs an evaluation
%   simulation, and plots the key performance indicators of the microgrid.
%   It can be run independently or called from main training scripts.
%
%   Features:
%   - Independent operation with file loading
%   - Integration support for post-training visualization
%   - Enhanced error handling and data validation
%   - Comprehensive performance metrics calculation
%   - Flexible data source configuration
% =========================================================================

% Clear workspace first if running as script (before parameter parsing)
if ~exist('varargin', 'var') || isempty(varargin)
    clear; clc; close all;
end

% Parse input arguments - support both function call and script execution
if exist('varargin', 'var') && ~isempty(varargin)
    % Called as function with parameters
    p = inputParser;
    addParameter(p, 'agent_file', 'final_trained_agent_random.mat', @ischar);
    addParameter(p, 'data_file', 'simulation_data_10days_random.mat', @ischar);
    addParameter(p, 'model_name', 'Microgrid2508020734', @ischar);
    addParameter(p, 'save_plots', true, @islogical);
    addParameter(p, 'show_plots', true, @islogical);
    parse(p, varargin{:});

    % Extract parameters
    results_filename = p.Results.agent_file;
    data_filename = p.Results.data_file;
    model_name = p.Results.model_name;
    save_plots = p.Results.save_plots;
    show_plots = p.Results.show_plots;
else
    % Default parameters when run as script
    results_filename = 'final_trained_agent_random.mat';
    data_filename = 'simulation_data_10days_random.mat';
    model_name = 'Microgrid2508020734';
    save_plots = true;
    show_plots = true;
end

%% 1. Configuration and Initialization
% -------------------------------------------------------------------------
fprintf('========================================\n');
fprintf('      DRL Training Results Plotter      \n');
fprintf('========================================\n');

% Check file existence
if ~exist(results_filename, 'file')
    error('Agent file not found: %s', results_filename);
end
if ~exist(data_filename, 'file')
    error('Data file not found: %s', data_filename);
end

    %% 2. Load Data and Prepare Workspace
    % -------------------------------------------------------------------------
    fprintf('>> Loading agent and training stats from: %s\n', results_filename);
    try
        training_results = load(results_filename);
        if isfield(training_results, 'agent')
            agent = training_results.agent;
            fprintf('... Loaded agent successfully.\n');
        else
            error('Agent variable not found in file.');
        end

        if isfield(training_results, 'trainingStats')
            fprintf('... Training statistics also loaded.\n');
        end
    catch ME
        error('Could not load the results file "%s": %s', results_filename, ME.message);
    end

    fprintf('>> Loading simulation data from: %s\n', data_filename);
    try
        sim_data = load(data_filename);
        required_fields = {'pv_power_profile', 'load_power_profile', 'price_profile'};
        for i = 1:length(required_fields)
            if ~isfield(sim_data, required_fields{i})
                error('Required field %s not found in data file.', required_fields{i});
            end
        end

        pv_power_profile = sim_data.pv_power_profile;
        load_power_profile = sim_data.load_power_profile;
        price_profile = sim_data.price_profile;

        if isfield(sim_data, 'simulationDays')
            simulationDays = sim_data.simulationDays;
        else
            simulationDays = length(pv_power_profile.Time) / 24;
        end

        fprintf('... Simulation data loaded successfully (%d days).\n', simulationDays);
    catch ME
        error('Could not load the data file "%s": %s', data_filename, ME.message);
    end

    %% 3. Prepare Model and Workspace
    % -------------------------------------------------------------------------
    fprintf('>> Preparing Simulink model and workspace...\n');

    % Check if model file exists
    model_file = [model_name, '.slx'];
    if ~exist(model_file, 'file')
        model_file = [model_name, '.mdl'];
        if ~exist(model_file, 'file')
            error('Model file not found: %s', model_name);
        end
    end

    % Force close and reload the model to ensure a clean state
    if bdIsLoaded(model_name)
        close_system(model_name, 0);
    end

    try
        load_system(model_name);
        fprintf('... Model loaded: %s\n', model_name);
    catch ME
        error('Failed to load model %s: %s', model_name, ME.message);
    end

    % Define the physical parameters required by the Simulink model
    PnomkW = 500;
    Pnom = PnomkW * 1e3;
    kWh_Rated = 100;
    C_rated_Ah = kWh_Rated * 1000 / 5000;
    Efficiency = 96;
    Initial_SOC_pc = 80;
    Initial_SOC_pc_MIN = 30;
    Initial_SOC_pc_MAX = 80;
    COST_PER_AH_LOSS = 0.25;
    SOC_UPPER_LIMIT = 95.0;
    SOC_LOWER_LIMIT = 15.0;
    SOH_FAILURE_THRESHOLD = 0.8;

    fprintf('... Physical model parameters defined.\n');

    % Assign required variables to the base workspace for the model to use
    assignin('base', 'agentObj', agent);
    assignin('base', 'agent', agent);
    assignin('base', 'pv_power_profile', pv_power_profile);
    assignin('base', 'load_power_profile', load_power_profile);
    assignin('base', 'price_profile', price_profile);
    assignin('base', 'Pnom', Pnom);
    assignin('base', 'PnomkW', PnomkW);
    assignin('base', 'kWh_Rated', kWh_Rated);
    assignin('base', 'C_rated_Ah', C_rated_Ah);
    assignin('base', 'Efficiency', Efficiency);
    assignin('base', 'Initial_SOC_pc', Initial_SOC_pc);

    fprintf('... Agent and data profiles assigned to base workspace.\n');

    %% 4. Run Evaluation Simulation
    % -------------------------------------------------------------------------
    fprintf('>> Running evaluation simulation...\n');

    try
        % Pre-simulation diagnostics
        fprintf('   Performing pre-simulation checks...\n');

        % Check model compilation
        try
            fprintf('   Checking model compilation...\n');
            [~] = get_param(model_name, 'CompiledSampleTime');
            fprintf('   ? Model compilation check passed.\n');
        catch
            fprintf('   Attempting to compile model...\n');
            try
                eval([model_name, '([],[],[],''compile'')']);
                eval([model_name, '([],[],[],''term'')']);
                fprintf('   ? Model compiled successfully.\n');
            catch compileError
                fprintf('   ? Model compilation failed: %s\n', compileError.message);
                error('Model compilation failed. Please check the Simulink model.');
            end
        end

        % Configure simulation input with enhanced stability settings
        simIn = Simulink.SimulationInput(model_name);

        % Calculate simulation time from data
        if isa(pv_power_profile, 'timeseries')
            sim_time = pv_power_profile.Time(end);
        else
            sim_time = simulationDays * 24 * 3600;
        end

        % Limit simulation time for stability (max 24 hours for evaluation)
        max_sim_time = 24 * 3600; % 24 hours
        if sim_time > max_sim_time
            fprintf('   Warning: Simulation time (%.1f h) exceeds maximum. Limiting to %.1f h.\n', ...
                    sim_time/3600, max_sim_time/3600);
            sim_time = max_sim_time;
        end

        % Basic simulation parameters
        simIn = simIn.setModelParameter('StopTime', num2str(sim_time));
        simIn = simIn.setModelParameter('ReturnWorkspaceOutputs', 'on');
        simIn = simIn.setModelParameter('SignalLogging', 'on');
        simIn = simIn.setModelParameter('SignalLoggingName', 'logsout');

        % Enhanced solver configuration for stability
        simIn = simIn.setModelParameter('SolverType', 'Variable-step');
        simIn = simIn.setModelParameter('Solver', 'ode23tb');
        simIn = simIn.setModelParameter('RelTol', '1e-3');
        simIn = simIn.setModelParameter('AbsTol', '1e-6');
        simIn = simIn.setModelParameter('MaxStep', 'auto');
        simIn = simIn.setModelParameter('InitialStep', 'auto');

        % Additional stability settings
        simIn = simIn.setModelParameter('ZeroCrossControl', 'UseLocalSettings');
        simIn = simIn.setModelParameter('AlgebraicLoopSolver', 'TrustRegion');
        simIn = simIn.setModelParameter('MinStepSizeMsg', 'none');

        % Disable unnecessary features for faster simulation
        simIn = simIn.setModelParameter('SaveFormat', 'Dataset');
        simIn = simIn.setModelParameter('SaveOutput', 'on');
        simIn = simIn.setModelParameter('SaveState', 'off');
        simIn = simIn.setModelParameter('SaveTime', 'on');

        % Run the simulation with progress indication
        fprintf('   Simulating for %.1f hours (%.0f seconds)...\n', sim_time/3600, sim_time);
        fprintf('   Using solver: ode23tb with enhanced stability settings\n');

        tic; % Start timing
        simOut = sim(simIn);
        elapsed_time = toc;

        fprintf('... Simulation completed successfully in %.1f seconds.\n', elapsed_time);

    catch ME
        fprintf('\nERROR: Evaluation simulation failed.\n');
        fprintf('Error Identifier: %s\n', ME.identifier);
        fprintf('Error Message: %s\n', ME.message);

        % Enhanced error diagnostics
        if strcmp(ME.identifier, 'MATLAB:MException:MultipleErrors')
            fprintf('\nDetailed Error Analysis:\n');
            if isfield(ME, 'cause') && ~isempty(ME.cause)
                for i = 1:length(ME.cause)
                    fprintf('  Error %d: %s\n', i, ME.cause{i}.message);
                    if ~isempty(ME.cause{i}.stack)
                        fprintf('    Location: %s (line %d)\n', ...
                                ME.cause{i}.stack(1).name, ME.cause{i}.stack(1).line);
                    end
                end
            end
        end

        % Common troubleshooting suggestions
        fprintf('\nTroubleshooting Suggestions:\n');
        fprintf('1. Check if all required variables are in base workspace\n');
        fprintf('2. Verify Simulink model configuration\n');
        fprintf('3. Ensure RL Agent block is properly configured\n');
        fprintf('4. Try running a shorter simulation (1 hour)\n');
        fprintf('5. Check for algebraic loops or solver issues\n');

        % Try to close the model before returning
        try
            close_system(model_name, 0);
        catch
            % Ignore errors when closing
        end
        return;
    end

    %% 5. Data Extraction and Processing
    % -------------------------------------------------------------------------
    fprintf('>> Extracting data and processing results...\n');

    try
        % Extract simulation outputs
        if isfield(simOut, 'logsout') && ~isempty(simOut.logsout)
            logsout = simOut.logsout;
        elseif isprop(simOut, 'logsout') && ~isempty(simOut.logsout)
            logsout = simOut.logsout;
        else
            logsout = simOut.get('logsout');
        end

        if isfield(simOut, 'tout') && ~isempty(simOut.tout)
            tout = simOut.tout;
        elseif isprop(simOut, 'tout') && ~isempty(simOut.tout)
            tout = simOut.tout;
        else
            tout = simOut.get('tout');
        end

        if isempty(tout) || isempty(logsout)
            error('Essential simulation output (time or logs) is missing.');
        end

        % Convert time to days for plotting
        time_h = tout / 3600;  % Time in hours
        days = tout / (3600 * 24);  % Time in days

        fprintf('   Simulation duration: %.2f hours (%.2f days)\n', time_h(end), days(end));

        % Extract signals with improved error handling
        signal_data = extractAllSignals(logsout);

        % Validate extracted data
        if isempty(fieldnames(signal_data))
            error('No valid signals could be extracted from simulation output.');
        end

        fprintf('... Data extraction completed. Found %d signals.\n', length(fieldnames(signal_data)));

    catch ME
        fprintf('\nERROR: Failed to extract simulation data.\n');
        fprintf('Error Message: %s\n', ME.message);
        fprintf('Available simulation output fields:\n');
        try
            disp(fieldnames(simOut));
        catch
            fprintf('Could not display simulation output structure.\n');
        end
        return;
    end

    %% 6. Generate Visualizations
    % -------------------------------------------------------------------------
    if show_plots
        fprintf('>> Generating performance plots...\n');

        try
            % Create main performance figure
            fig = createPerformancePlots(signal_data, days, time_h, simulationDays);

            % Save plots if requested
            if save_plots
                savePlots(fig, results_filename);
            end

            fprintf('... Plotting completed successfully.\n');

        catch ME
            fprintf('Warning: Plotting failed: %s\n', ME.message);
        end
    end

    %% 7. Performance Metrics Summary
    % -------------------------------------------------------------------------
    fprintf('>> Calculating performance metrics...\n');

    try
        metrics = calculatePerformanceMetrics(signal_data, time_h, days);
        displayMetricsSummary(metrics, simulationDays);

    catch ME
        fprintf('Warning: Metrics calculation failed: %s\n', ME.message);
    end

    %% 8. Cleanup
    % -------------------------------------------------------------------------
    try
        close_system(model_name, 0);
        fprintf('>> Model closed successfully.\n');
    catch
        % Ignore errors when closing
    end

fprintf('========================================\n');
fprintf('           Script Finished              \n');
fprintf('========================================\n');

%% Helper Functions
% =========================================================================

function signal_data = extractAllSignals(logsout)
    % Extract all available signals from logsout with error handling

    signal_data = struct();

    % List of expected signal names and their alternative names
    signal_map = containers.Map({...
        'P_pv', 'pv_power_profile', 'PV_Power'; ...
        'P_load', 'load_power_profile', 'Load_Power'; ...
        'P_batt', 'Battery_Power', 'Batt_Power'; ...
        'P_grid', 'Grid_Power'; ...
        'SOC', 'Battery_SOC', 'SOC_Battery'; ...
        'SOH', 'Battery_SOH', 'SOH_Battery'; ...
        'price', 'price_profile', 'Price'}, ...
        {'pv_power', 'load_power', 'batt_power', 'grid_power', 'soc', 'soh', 'price'});

    signal_names = keys(signal_map);

    for i = 1:length(signal_names)
        signal_name = signal_names{i};
        field_name = signal_map(signal_name);

        data = extractSignalData(logsout, signal_name);
        if ~isempty(data)
            signal_data.(field_name) = data;
        end
    end

    % If we didn't find the signals with expected names, try to extract by index
    if isempty(fieldnames(signal_data))
        fprintf('   Warning: No signals found with expected names. Trying alternative extraction...\n');
        signal_data = extractSignalsByIndex(logsout);
    end
end

function data = extractSignalData(logsout, signalName)
    % Safely extract signal data from logsout
    data = [];

    try
        if isa(logsout, 'Simulink.SimulationData.Dataset')
            % New format (R2020a+)
            signal = logsout.getElement(signalName);
            if ~isempty(signal)
                data = signal.Values.Data;
                fprintf('   Successfully extracted signal: %s\n', signalName);
            end
        else
            % Legacy format
            signal = logsout.get(signalName);
            if ~isempty(signal)
                data = signal.Data;
                fprintf('   Successfully extracted signal: %s\n', signalName);
            end
        end
    catch
        % Try alternative signal names or extraction methods
        try
            % Try with find method
            signal = logsout.find('Name', signalName);
            if ~isempty(signal)
                data = signal.Values.Data;
                fprintf('   Successfully extracted signal (alternative): %s\n', signalName);
            end
        catch
            % Signal not found or extraction failed
        end
    end
end

function signal_data = extractSignalsByIndex(logsout)
    % Extract signals by index when name-based extraction fails
    signal_data = struct();

    try
        if isa(logsout, 'Simulink.SimulationData.Dataset')
            num_signals = logsout.numElements;
            fprintf('   Found %d signals in dataset. Extracting by index...\n', num_signals);

            for i = 1:min(num_signals, 10)  % Limit to first 10 signals
                try
                    element = logsout.getElement(i);
                    if ~isempty(element) && ~isempty(element.Values)
                        field_name = sprintf('signal_%d', i);
                        signal_data.(field_name) = element.Values.Data;
                        fprintf('   Extracted signal %d as %s\n', i, field_name);
                    end
                catch
                    continue;
                end
            end
        end
    catch ME
        fprintf('   Warning: Index-based extraction also failed: %s\n', ME.message);
    end
end

function fig = createPerformancePlots(signal_data, days, ~, simulationDays)
    % Create comprehensive performance plots

    fig = figure('Name', 'DRL Microgrid Control Performance', ...
                 'NumberTitle', 'off', ...
                 'Position', [100 100 1400 900]);

    % Prepare data for plotting
    [P_pv_sim, P_load_sim, P_batt_sim, P_grid_sim, SOC_sim, SOH_sim, Price_sim] = ...
        prepareDataForPlotting(signal_data);

    % Plot 1: Power Balance
    subplot(3, 1, 1);
    hold on;
    if ~isempty(P_pv_sim)
        plot(days, P_pv_sim, 'g-', 'LineWidth', 1.5, 'DisplayName', 'PV Generation');
    end
    if ~isempty(P_load_sim)
        plot(days, P_load_sim, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Load Demand');
    end
    if ~isempty(P_grid_sim)
        plot(days, P_grid_sim, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Grid Power');
    end
    if ~isempty(P_batt_sim)
        plot(days, P_batt_sim, 'm-.', 'LineWidth', 2, 'DisplayName', 'Battery Power');
    end
    hold off;

    title(sprintf('System Power Balance (%d days)', simulationDays));
    xlabel('Time (days)');
    ylabel('Power (kW)');
    legend('show', 'Location', 'best');
    grid on;
    if ~isempty(days)
        xlim([0 days(end)]);
    end

    % Plot 2: SOC vs. Price
    subplot(3, 1, 2);
    if ~isempty(SOC_sim) || ~isempty(Price_sim)
        yyaxis left;
        if ~isempty(SOC_sim)
            plot(days, SOC_sim, 'b-', 'LineWidth', 1.5);
            ylabel('SOC (%)');
            ylim([0 100]);
        end

        yyaxis right;
        if ~isempty(Price_sim)
            plot(days, Price_sim, 'r--', 'LineWidth', 1.5);
            ylabel('Price ($/kWh)');
        end

        title('Battery SOC vs. Electricity Price');
        xlabel('Time (days)');
        legend({'SOC', 'Price'}, 'Location', 'best');
        grid on;
        if ~isempty(days)
            xlim([0 days(end)]);
        end
    else
        text(0.5, 0.5, 'SOC and Price data not available', ...
             'HorizontalAlignment', 'center', 'Units', 'normalized');
        title('Battery SOC vs. Electricity Price (Data Not Available)');
    end

    % Plot 3: SOH Degradation
    subplot(3, 1, 3);
    if ~isempty(SOH_sim)
        plot(days, SOH_sim * 100, 'k-', 'LineWidth', 1.5);

        initial_soh = SOH_sim(1) * 100;
        final_soh = SOH_sim(end) * 100;
        degradation = initial_soh - final_soh;

        title(sprintf('SOH Degradation (Total: %.4f%% over %d days)', degradation, simulationDays));
        xlabel('Time (days)');
        ylabel('SOH (%)');
        grid on;

        if ~isempty(days)
            xlim([0 days(end)]);
        end

        % Set appropriate y-axis limits
        ylim_padding = max(degradation * 0.1, 0.01);
        ylim([final_soh - ylim_padding, initial_soh + ylim_padding]);
    else
        text(0.5, 0.5, 'SOH data not available', ...
             'HorizontalAlignment', 'center', 'Units', 'normalized');
        title('SOH Degradation (Data Not Available)');
    end

    % Add overall title
    sgtitle('Microgrid Performance Evaluation', 'FontSize', 16, 'FontWeight', 'bold');
end

function [P_pv_sim, P_load_sim, P_batt_sim, P_grid_sim, SOC_sim, SOH_sim, Price_sim] = ...
    prepareDataForPlotting(signal_data)
    % Prepare and convert data for plotting

    % Initialize outputs
    P_pv_sim = []; P_load_sim = []; P_batt_sim = []; P_grid_sim = [];
    SOC_sim = []; SOH_sim = []; Price_sim = [];

    % Extract and convert power data (W to kW)
    if isfield(signal_data, 'pv_power') && ~isempty(signal_data.pv_power)
        P_pv_sim = signal_data.pv_power / 1000;
    end

    if isfield(signal_data, 'load_power') && ~isempty(signal_data.load_power)
        P_load_sim = signal_data.load_power / 1000;
    end

    if isfield(signal_data, 'batt_power') && ~isempty(signal_data.batt_power)
        P_batt_sim = signal_data.batt_power / 1000;
    end

    if isfield(signal_data, 'grid_power') && ~isempty(signal_data.grid_power)
        P_grid_sim = signal_data.grid_power / 1000;
    elseif ~isempty(P_load_sim) && ~isempty(P_pv_sim) && ~isempty(P_batt_sim)
        % Calculate grid power if not directly available
        P_grid_sim = P_load_sim - P_pv_sim - P_batt_sim;
    end

    % Extract other signals
    if isfield(signal_data, 'soc') && ~isempty(signal_data.soc)
        SOC_sim = signal_data.soc;
    end

    if isfield(signal_data, 'soh') && ~isempty(signal_data.soh)
        SOH_sim = signal_data.soh;
    end

    if isfield(signal_data, 'price') && ~isempty(signal_data.price)
        Price_sim = signal_data.price;
    end
end

function metrics = calculatePerformanceMetrics(signal_data, time_h, days)
    % Calculate comprehensive performance metrics

    metrics = struct();

    % Prepare data
    [P_pv_sim, P_load_sim, P_batt_sim, P_grid_sim, SOC_sim, SOH_sim, Price_sim] = ...
        prepareDataForPlotting(signal_data);

    % Time metrics
    metrics.simulation_duration_hours = time_h(end);
    metrics.simulation_duration_days = days(end);

    % Energy metrics (kWh)
    if ~isempty(P_pv_sim)
        metrics.total_pv_energy = trapz(time_h, P_pv_sim);
    else
        metrics.total_pv_energy = NaN;
    end

    if ~isempty(P_load_sim)
        metrics.total_load_energy = trapz(time_h, P_load_sim);
    else
        metrics.total_load_energy = NaN;
    end

    if ~isempty(P_grid_sim)
        metrics.total_grid_energy = trapz(time_h, P_grid_sim);
        metrics.grid_import_energy = trapz(time_h, max(P_grid_sim, 0));
        metrics.grid_export_energy = trapz(time_h, abs(min(P_grid_sim, 0)));
    else
        metrics.total_grid_energy = NaN;
        metrics.grid_import_energy = NaN;
        metrics.grid_export_energy = NaN;
    end

    if ~isempty(P_batt_sim)
        metrics.battery_charge_energy = trapz(time_h, max(-P_batt_sim, 0));
        metrics.battery_discharge_energy = trapz(time_h, max(P_batt_sim, 0));
    else
        metrics.battery_charge_energy = NaN;
        metrics.battery_discharge_energy = NaN;
    end

    % SOH metrics
    if ~isempty(SOH_sim)
        metrics.initial_soh = SOH_sim(1) * 100;
        metrics.final_soh = SOH_sim(end) * 100;
        metrics.soh_degradation = metrics.initial_soh - metrics.final_soh;
    else
        metrics.initial_soh = NaN;
        metrics.final_soh = NaN;
        metrics.soh_degradation = NaN;
    end

    % SOC metrics
    if ~isempty(SOC_sim)
        metrics.min_soc = min(SOC_sim);
        metrics.max_soc = max(SOC_sim);
        metrics.avg_soc = mean(SOC_sim);
    else
        metrics.min_soc = NaN;
        metrics.max_soc = NaN;
        metrics.avg_soc = NaN;
    end

    % Economic metrics
    if ~isempty(P_grid_sim) && ~isempty(Price_sim)
        % Calculate electricity cost (positive = cost, negative = revenue)
        metrics.electricity_cost = trapz(time_h, P_grid_sim .* Price_sim);
        metrics.avg_electricity_price = mean(Price_sim);
    else
        metrics.electricity_cost = NaN;
        metrics.avg_electricity_price = NaN;
    end

    % Efficiency metrics
    if ~isnan(metrics.total_pv_energy) && ~isnan(metrics.total_load_energy)
        metrics.pv_utilization = (metrics.total_pv_energy - metrics.grid_export_energy) / metrics.total_pv_energy * 100;
        metrics.self_sufficiency = (metrics.total_load_energy - metrics.grid_import_energy) / metrics.total_load_energy * 100;
    else
        metrics.pv_utilization = NaN;
        metrics.self_sufficiency = NaN;
    end
end

function displayMetricsSummary(metrics, ~)
    % Display comprehensive metrics summary

    fprintf('\n=== PERFORMANCE METRICS SUMMARY ===\n');
    fprintf('Simulation Duration: %.1f days (%.1f hours)\n', ...
            metrics.simulation_duration_days, metrics.simulation_duration_hours);

    fprintf('\n--- Energy Metrics ---\n');
    if ~isnan(metrics.total_pv_energy)
        fprintf('Total PV Generation: %.2f kWh\n', metrics.total_pv_energy);
    end
    if ~isnan(metrics.total_load_energy)
        fprintf('Total Load Consumption: %.2f kWh\n', metrics.total_load_energy);
    end
    if ~isnan(metrics.total_grid_energy)
        fprintf('Net Grid Exchange: %.2f kWh\n', metrics.total_grid_energy);
        if metrics.total_grid_energy > 0
            fprintf('  Grid Import: %.2f kWh\n', metrics.grid_import_energy);
        else
            fprintf('  Grid Export: %.2f kWh\n', metrics.grid_export_energy);
        end
    end

    fprintf('\n--- Battery Performance ---\n');
    if ~isnan(metrics.soh_degradation)
        fprintf('SOH Degradation: %.4f%% (from %.4f%% to %.4f%%)\n', ...
                metrics.soh_degradation, metrics.initial_soh, metrics.final_soh);
    end
    if ~isnan(metrics.min_soc)
        fprintf('SOC Range: %.1f%% - %.1f%% (avg: %.1f%%)\n', ...
                metrics.min_soc, metrics.max_soc, metrics.avg_soc);
    end
    if ~isnan(metrics.battery_charge_energy)
        fprintf('Battery Charge Energy: %.2f kWh\n', metrics.battery_charge_energy);
        fprintf('Battery Discharge Energy: %.2f kWh\n', metrics.battery_discharge_energy);
    end

    fprintf('\n--- Economic Metrics ---\n');
    if ~isnan(metrics.electricity_cost)
        fprintf('Total Electricity Cost: $%.2f\n', metrics.electricity_cost);
        fprintf('Average Electricity Price: $%.3f/kWh\n', metrics.avg_electricity_price);
    end

    fprintf('\n--- Efficiency Metrics ---\n');
    if ~isnan(metrics.pv_utilization)
        fprintf('PV Utilization: %.1f%%\n', metrics.pv_utilization);
        fprintf('Self-Sufficiency: %.1f%%\n', metrics.self_sufficiency);
    end

    fprintf('=====================================\n');
end

function savePlots(fig, results_filename)
    % Save plots to file

    try
        % Create plots directory if it doesn't exist
        plots_dir = 'plots';
        if ~exist(plots_dir, 'dir')
            mkdir(plots_dir);
        end

        % Generate filename based on agent filename
        [~, base_name, ~] = fileparts(results_filename);
        plot_filename = fullfile(plots_dir, [base_name, '_performance_plots.png']);

        % Save the figure
        saveas(fig, plot_filename);
        fprintf('   Performance plots saved to: %s\n', plot_filename);

        % Also save as MATLAB figure for future editing
        fig_filename = fullfile(plots_dir, [base_name, '_performance_plots.fig']);
        savefig(fig, fig_filename);
        fprintf('   MATLAB figure saved to: %s\n', fig_filename);

    catch ME
        fprintf('   Warning: Could not save plots: %s\n', ME.message);
    end
end

%% 5. Generate Plots
% -------------------------------------------------------------------------
fprintf('>> Generating performance plots...\n');

figure('Name', 'DRL Microgrid Control Performance', 'NumberTitle', 'off', 'Position', [100 100 1200 800]);

% Plot 1: Power Balance
subplot(3, 1, 1);
hold on;
plot(days, P_pv_sim, 'g-', 'LineWidth', 1.5);
plot(days, P_load_sim, 'b-', 'LineWidth', 1.5);
plot(days, P_grid_sim, 'r--', 'LineWidth', 1.5);
plot(days, P_batt_sim, 'm-.', 'LineWidth', 2);
hold off;
title('System Power Balance');
xlabel('Time (days)');
ylabel('Power (kW)');
legend({'PV', 'Load', 'Grid', 'Battery'}, 'Location', 'best');
grid on;
xlim([0 days(end)]);

% Plot 2: State of Charge (SOC) vs. Electricity Price
subplot(3, 1, 2);
hold on;
yyaxis left;
plot(days, SOC_sim, 'b-', 'LineWidth', 1.5);
ylabel('SOC (%)');
ylim([0 100]);
yyaxis right;
plot(days, Price_sim, 'r--', 'LineWidth', 1.5);
ylabel('Price ($/kWh)');
hold off;
title('SOC vs. Price');
xlabel('Time (days)');
legend({'SOC', 'Price'}, 'Location', 'best');
grid on;
xlim([0 days(end)]);

% Plot 3: State of Health (SOH) Degradation
subplot(3, 1, 3);
plot(days, SOH_sim * 100, 'k-', 'LineWidth', 1.5);
title('SOH Degradation');
xlabel('Time (days)');
ylabel('SOH (%)');
grid on;
xlim([0 days(end)]);
initial_soh = SOH_sim(1) * 100;
final_soh = SOH_sim(end) * 100;
ylim_padding = (initial_soh - final_soh) * 0.1;
if ylim_padding == 0
    ylim_padding = 0.01; 
end
ylim([final_soh - ylim_padding, initial_soh + ylim_padding]);
simulationDays = round(days(end));
legend(sprintf('Degradation over %d day(s): %.4f %%', simulationDays, initial_soh - final_soh), 'Location', 'best');

sgtitle('Microgrid Performance Evaluation', 'FontSize', 16, 'FontWeight', 'bold');

fprintf('... Plotting complete.\n');

%% 6. Performance Metrics Summary
% -------------------------------------------------------------------------
fprintf('\n--- PERFORMANCE METRICS SUMMARY ---\n');
fprintf('Simulation Duration: %.1f days\n', days(end));
fprintf('Initial SOH: %.4f%%\n', initial_soh);
fprintf('Final SOH: %.4f%%\n', final_soh);
fprintf('Total SOH Degradation: %.4f%%\n', initial_soh - final_soh);

% Calculate energy metrics
total_pv_energy = trapz(days * 24, P_pv_sim); % kWh
total_load_energy = trapz(days * 24, P_load_sim); % kWh
total_grid_energy = trapz(days * 24, P_grid_sim); % kWh (positive = import, negative = export)

fprintf('Total PV Generation: %.2f kWh\n', total_pv_energy);
fprintf('Total Load Consumption: %.2f kWh\n', total_load_energy);
fprintf('Net Grid Exchange: %.2f kWh\n', total_grid_energy);

if total_grid_energy > 0
    fprintf('Grid Status: Net Import (%.2f kWh)\n', total_grid_energy);
else
    fprintf('Grid Status: Net Export (%.2f kWh)\n', abs(total_grid_energy));
end

fprintf('-----------------------------------\n');

disp('========================================');
disp('           Script Finished              ');
disp('========================================');

