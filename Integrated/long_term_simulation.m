% =========================================================================
%                    long_term_simulation.m
% -------------------------------------------------------------------------
% Description:
%   Specialized MATLAB script for long-term microgrid physical simulation
%   Supports stable simulation for 30-60 days with advanced memory management
%   
%   Key Features:
%   - Adaptive memory management with automatic cleanup
%   - Checkpoint-based simulation with resume capability
%   - Intelligent data compression and storage
%   - Numerical stability monitoring and correction
%   - Automatic error recovery and continuation
%   - Progressive data saving to prevent data loss
%
% Usage:
%   results = long_term_simulation('simulation_days', 60, 'checkpoint_interval', 7);
%
% Author: Augment Agent
% Date: 2025-08-06
% Version: 1.0
% =========================================================================

function results = long_term_simulation(varargin)
    % Parse input arguments
    p = inputParser;
    addParameter(p, 'simulation_days', 60, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'checkpoint_interval', 7, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'data_file', 'simulation_data_10days_random.mat', @ischar);
    addParameter(p, 'model_name', 'Microgrid2508020734', @ischar);
    addParameter(p, 'agent_file', 'final_trained_agent_random.mat', @ischar);
    addParameter(p, 'output_dir', 'long_term_results', @ischar);
    addParameter(p, 'memory_threshold_gb', 6, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'resume_from_checkpoint', '', @ischar);
    addParameter(p, 'stability_monitoring', true, @islogical);
    addParameter(p, 'auto_recovery', true, @islogical);
    addParameter(p, 'data_compression', true, @islogical);
    addParameter(p, 'verbose', true, @islogical);
    parse(p, varargin{:});
    
    config = p.Results;
    
    try
        % Initialize long-term simulation environment
        [sim_state, checkpoint_manager] = initializeLongTermSimulation(config);
        
        % Check for resume from checkpoint
        if ~isempty(config.resume_from_checkpoint)
            sim_state = resumeFromCheckpoint(config.resume_from_checkpoint, sim_state);
        end
        
        % Run long-term simulation with checkpointing
        results = runLongTermSimulation(config, sim_state, checkpoint_manager);
        
        % Finalize and save results
        results = finalizeLongTermResults(results, config);
        
    catch ME
        handleLongTermError(ME, config);
        rethrow(ME);
    finally
        cleanupLongTermSimulation(config);
    end
end

function [sim_state, checkpoint_manager] = initializeLongTermSimulation(config)
    % Initialize long-term simulation environment
    
    if config.verbose
        displayLongTermConfig(config);
    end
    
    % Create output directory structure
    createOutputDirectories(config);
    
    % Initialize simulation state
    sim_state = struct();
    sim_state.current_day = 1;
    sim_state.completed_days = 0;
    sim_state.start_time = datetime('now');
    sim_state.memory_usage_history = [];
    sim_state.stability_metrics = false(config.simulation_days, 1); % Pre-allocate logical array
    sim_state.stability_count = 0; % Track actual number of entries
    sim_state.error_count = 0;
    sim_state.recovery_count = 0;
    
    % Initialize checkpoint manager
    checkpoint_manager = struct();
    checkpoint_manager.interval = config.checkpoint_interval;
    checkpoint_manager.last_checkpoint = 0;
    checkpoint_manager.checkpoint_dir = fullfile(config.output_dir, 'checkpoints');
    checkpoint_manager.data_compression = config.data_compression;
    
    % Setup memory monitoring
    setupMemoryMonitoring(config);
    
    % Configure model for long-term stability
    configureLongTermModel(config);
    
    % Load and prepare extended data
    sim_state.data = prepareExtendedData(config);
    
    % Load agent
    sim_state.agent = loadAgent(config.agent_file)
    
    fprintf('>> Long-term simulation initialized for %d days\n\n', config.simulation_days);
end

function displayLongTermConfig(config)
    fprintf('=========================================================================\n');
    fprintf('              LONG-TERM MICROGRID SIMULATION v1.0\n');
    fprintf('=========================================================================\n');
    fprintf('Configuration:\n');
    fprintf('  Simulation Duration: %d days\n', config.simulation_days);
    fprintf('  Checkpoint Interval: %d days\n', config.checkpoint_interval);
    fprintf('  Memory Threshold: %.1f GB\n', config.memory_threshold_gb);
    if config.stability_monitoring
        fprintf('  Stability Monitoring: Enabled\n');
    else
        fprintf('  Stability Monitoring: Disabled\n');
    end
    if config.auto_recovery
        fprintf('  Auto Recovery: Enabled\n');
    else
        fprintf('  Auto Recovery: Disabled\n');
    end
    if config.data_compression
        fprintf('  Data Compression: Enabled\n');
    else
        fprintf('  Data Compression: Disabled\n');
    end
    if ~isempty(config.resume_from_checkpoint)
        fprintf('  Resume From: %s\n', config.resume_from_checkpoint);
    end
    fprintf('=========================================================================\n\n');
end

function createOutputDirectories(config)
    % Create necessary output directories
    dirs = {config.output_dir, ...
            fullfile(config.output_dir, 'checkpoints'), ...
            fullfile(config.output_dir, 'daily_results'), ...
            fullfile(config.output_dir, 'monitoring'), ...
            fullfile(config.output_dir, 'recovery_logs')};
    
    for i = 1:length(dirs)
        if ~exist(dirs{i}, 'dir')
            mkdir(dirs{i});
        end
    end
end

function setupMemoryMonitoring(config)
    % Setup memory monitoring system
    
    % Create memory monitor timer
    if ispc
        % Windows memory monitoring
        timer_obj = timer('ExecutionMode', 'fixedRate', ...
                         'Period', 60, ... % Check every minute
                         'TimerFcn', @(~,~) monitorMemoryUsage(config));
        start(timer_obj);
        
        % Store timer in base workspace for cleanup
        assignin('base', 'memory_monitor_timer', timer_obj);
    end
end

function monitorMemoryUsage(config)
    % Monitor memory usage and trigger cleanup if needed
    
    if ispc
        try
            [~, sys_info] = memory;
            available_gb = sys_info.PhysicalMemory.Available / 1e9;
            
            if available_gb < config.memory_threshold_gb
                fprintf('>> Memory threshold reached (%.1f GB available), triggering cleanup...\n', available_gb);
                
                % Aggressive memory cleanup
                evalin('base', 'clearvars -except agentObj agent memory_monitor_timer');
                java.lang.System.gc();
                
                % Log memory cleanup
                logMemoryCleanup(available_gb, config);
            end
        catch ME
            fprintf('Warning: Memory monitoring failed: %s\n', ME.message);
        end
    end
end

function logMemoryCleanup(available_gb, config)
    % Log memory cleanup events
    log_file = fullfile(config.output_dir, 'monitoring', 'memory_cleanup.log');
    
    try
        fid = fopen(log_file, 'a');
        if fid > 0
            fprintf(fid, '%s: Memory cleanup triggered, %.1f GB available\n', ...
                    string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), available_gb);
            fclose(fid);
        end
    catch
        % Ignore logging errors
    end
end

function configureLongTermModel(config)
    % Configure Simulink model for long-term stability
    
    model_name = config.model_name;
    
    % Close and reload model
    if bdIsLoaded(model_name)
        close_system(model_name, 0);
    end
    load_system(model_name);
    
    % Configure for maximum numerical stability
    set_param(model_name, 'SolverType', 'Variable-step');
    set_param(model_name, 'Solver', 'ode15s'); % Stiff solver for stability
    set_param(model_name, 'RelTol', '1e-4');   % Tighter tolerance
    set_param(model_name, 'AbsTol', '1e-7');   % Tighter absolute tolerance
    set_param(model_name, 'MaxStep', '3600');  % Maximum 1-hour step
    set_param(model_name, 'InitialStep', '1'); % Small initial step
    
    % Configure for stability
    set_param(model_name, 'ZeroCrossControl', 'UseLocalSettings');
    set_param(model_name, 'AlgebraicLoopSolver', 'TrustRegion');
    set_param(model_name, 'MinStepSizeMsg', 'warning');
    
    % Disable unnecessary features
    set_param(model_name, 'ConsistencyChecking', 'off');
    set_param(model_name, 'SolverProfiling', 'off');
    
    % Configure data logging for memory efficiency
    set_param(model_name, 'SignalLogging', 'on');
    set_param(model_name, 'SignalLoggingName', 'logsout');
    set_param(model_name, 'SaveFormat', 'Dataset');
    set_param(model_name, 'SaveOutput', 'on');
    set_param(model_name, 'SaveState', 'off');
    set_param(model_name, 'SaveTime', 'on');
    set_param(model_name, 'LimitDataPoints', 'on');
    set_param(model_name, 'MaxDataPoints', '10000'); % Limit data points
    
    fprintf('>> Model configured for long-term stability\n');
end

function extended_data = prepareExtendedData(config)
    % Prepare extended data for long-term simulation
    
    fprintf('>> Preparing extended data for %d days...\n', config.simulation_days);
    
    % Load base data
    base_data = load(config.data_file);
    
    % Generate extended data with seasonal variations
    extended_data = generateSeasonalData(base_data, config.simulation_days);
    
    fprintf('   Extended data prepared with seasonal variations\n');
end

function seasonal_data = generateSeasonalData(base_data, target_days)
    % Generate seasonal data with realistic long-term variations
    
    base_days = base_data.simulationDays;
    
    % Create seasonal variation patterns
    day_vector = 1:target_days;
    
    % Seasonal PV variation (higher in summer, lower in winter)
    pv_seasonal = 0.8 + 0.4 * sin(2*pi * day_vector / 365 + pi/2); % Peak in summer
    
    % Seasonal load variation (higher in winter for heating, summer for cooling)
    load_seasonal = 0.9 + 0.2 * (sin(2*pi * day_vector / 365) + sin(2*pi * day_vector / 365 + pi));
    
    % Weekly patterns
    weekly_pattern = 0.95 + 0.1 * sin(2*pi * day_vector / 7);
    
    % Pre-allocate arrays for better performance
    total_hours = target_days * 24;
    extended_pv = zeros(total_hours, 1);
    extended_load = zeros(total_hours, 1);
    extended_price = zeros(total_hours, 1);
    extended_time = zeros(total_hours, 1);

    for day = 1:target_days
        % Select base day (cycle through available data)
        base_day_idx = mod(day - 1, base_days) + 1;

        % Get base day data
        day_start_hour = (base_day_idx - 1) * 24 + 1;
        day_end_hour = base_day_idx * 24;

        pv_base = base_data.pv_power_profile.Data(day_start_hour:day_end_hour);
        load_base = base_data.load_power_profile.Data(day_start_hour:day_end_hour);
        price_base = base_data.price_profile.Data(day_start_hour:day_end_hour);

        % Apply seasonal and weekly variations
        pv_factor = pv_seasonal(day) * weekly_pattern(day);
        load_factor = load_seasonal(day) * weekly_pattern(day);

        % Add random daily variation
        daily_pv_var = 0.9 + 0.2 * rand();
        daily_load_var = 0.95 + 0.1 * rand();

        % Apply variations
        pv_day = pv_base * pv_factor * daily_pv_var;
        load_day = load_base * load_factor * daily_load_var;
        price_day = price_base; % Keep price patterns consistent

        % Create time vector for this day
        time_offset = (day - 1) * 24 * 3600;
        time_day = (0:3600:23*3600)' + time_offset;

        % Calculate indices for this day
        start_idx = (day - 1) * 24 + 1;
        end_idx = day * 24;

        % Store data in pre-allocated arrays
        extended_pv(start_idx:end_idx) = pv_day;
        extended_load(start_idx:end_idx) = load_day;
        extended_price(start_idx:end_idx) = price_day;
        extended_time(start_idx:end_idx) = time_day;
    end
    
    % Create seasonal data structure
    seasonal_data = base_data;
    seasonal_data.pv_power_profile = timeseries(extended_pv, extended_time, 'Name', 'Seasonal PV Power');
    seasonal_data.load_power_profile = timeseries(extended_load, extended_time, 'Name', 'Seasonal Load Power');
    seasonal_data.price_profile = timeseries(extended_price, extended_time, 'Name', 'Seasonal Price');
    seasonal_data.simulationDays = target_days;
end

function agent = loadAgent(agent_file)
    % Load trained agent

    if ~exist(agent_file, 'file')
        error('Agent file not found: %s', agent_file);
    end

    agent_data = load(agent_file);
    if isfield(agent_data, 'agent')
        agent = agent_data.agent;
        fprintf('>> Agent loaded successfully\n');
    else
        error('Agent variable not found in file: %s', agent_file);
    end
end

function results = runLongTermSimulation(config, sim_state, checkpoint_manager)
    % Run long-term simulation with checkpointing and recovery

    fprintf('>> Starting long-term simulation...\n');

    % Initialize results structure
    results = struct();
    results.config = config;
    results.daily_results = cell(config.simulation_days, 1);
    results.checkpoints = {};
    results.stability_log = [];
    results.recovery_log = [];

    % Assign agent to workspace
    assignin('base', 'agentObj', sim_state.agent);
    assignin('base', 'agent', sim_state.agent);

    % Main simulation loop
    while sim_state.current_day <= config.simulation_days
        try
            % Run daily simulation
            daily_result = runDailySimulation(config, sim_state, sim_state.current_day);

            % Store daily result
            results.daily_results{sim_state.current_day} = daily_result;

            % Update simulation state
            sim_state.completed_days = sim_state.current_day;
            sim_state.current_day = sim_state.current_day + 1;

            % Check for checkpoint
            if shouldCreateCheckpoint(sim_state, checkpoint_manager)
                createCheckpoint(sim_state, results, checkpoint_manager, config);
            end

            % Monitor stability
            if config.stability_monitoring
                monitorStability(daily_result, sim_state, config);
            end

            % Progress reporting
            if mod(sim_state.completed_days, 5) == 0 || sim_state.completed_days == config.simulation_days
                reportProgress(sim_state, config);
            end

        catch ME
            % Handle simulation error
            if config.auto_recovery
                recovery_success = attemptRecovery(ME, sim_state, config);
                if recovery_success
                    continue; % Retry current day
                end
            end

            % If recovery failed or disabled, rethrow error
            logSimulationError(ME, sim_state, config);
            rethrow(ME);
        end
    end

    fprintf('>> Long-term simulation completed successfully\n\n');
end

function daily_result = runDailySimulation(config, sim_state, day_num)
    % Run simulation for a single day

    % Prepare daily data
    daily_data = prepareDailyData(sim_state.data, day_num);

    % Assign daily data to workspace
    assignin('base', 'pv_power_profile', daily_data.pv_power_profile);
    assignin('base', 'load_power_profile', daily_data.load_power_profile);
    assignin('base', 'price_profile', daily_data.price_profile);

    % Configure simulation time for one day
    sim_time = 24 * 3600; % 24 hours in seconds
    set_param(config.model_name, 'StopTime', num2str(sim_time));

    % Run simulation
    simIn = Simulink.SimulationInput(config.model_name);
    simIn = simIn.setModelParameter('StopTime', num2str(sim_time));
    simIn = simIn.setModelParameter('ReturnWorkspaceOutputs', 'on');

    simOut = sim(simIn);

    % Process daily results
    daily_result = processDailyResult(simOut, day_num);

    % Save daily result if enabled
    if config.data_compression
        saveDailyResult(daily_result, day_num, config);
    end

    % Cleanup after daily simulation
    cleanupAfterDaily();
end

function daily_data = prepareDailyData(extended_data, day_num)
    % Prepare data for a specific day

    % Calculate hour indices for the day
    start_hour = (day_num - 1) * 24 + 1;
    end_hour = day_num * 24;

    % Extract daily data
    pv_data = extended_data.pv_power_profile.Data(start_hour:end_hour);
    load_data = extended_data.load_power_profile.Data(start_hour:end_hour);
    price_data = extended_data.price_profile.Data(start_hour:end_hour);

    % Create time vector for the day (0 to 23 hours)
    time_vector = (0:3600:23*3600)';

    % Create daily timeseries
    daily_data = struct();
    daily_data.pv_power_profile = timeseries(pv_data, time_vector, 'Name', sprintf('Day %d PV', day_num));
    daily_data.load_power_profile = timeseries(load_data, time_vector, 'Name', sprintf('Day %d Load', day_num));
    daily_data.price_profile = timeseries(price_data, time_vector, 'Name', sprintf('Day %d Price', day_num));
end

function daily_result = processDailyResult(simOut, day_num)
    % Process results from daily simulation

    daily_result = struct();
    daily_result.day_number = day_num;
    daily_result.timestamp = datetime('now');

    try
        % Extract simulation outputs
        if isfield(simOut, 'logsout')
            logsout = simOut.logsout;
        else
            logsout = simOut.get('logsout');
        end

        if isfield(simOut, 'tout')
            tout = simOut.tout;
        else
            tout = simOut.get('tout');
        end

        % Extract key signals
        daily_result.signals = extractDailySignals(logsout);
        daily_result.time = tout;

        % Calculate daily metrics
        daily_result.metrics = calculateDailyMetrics(daily_result.signals, tout);

        % Check for numerical issues
        daily_result.stability_check = checkNumericalStability(daily_result.signals);

    catch ME
        daily_result.error = ME.message;
        fprintf('Warning: Error processing day %d results: %s\n', day_num, ME.message);
    end
end

function signals = extractDailySignals(logsout)
    % Extract key signals from daily simulation

    signals = struct();
    signal_names = {'P_pv', 'P_load', 'P_batt', 'SOC', 'SOH', 'price'};

    for i = 1:length(signal_names)
        signal_name = signal_names{i};
        try
            if isa(logsout, 'Simulink.SimulationData.Dataset')
                element = logsout.getElement(signal_name);
                if ~isempty(element)
                    signals.(signal_name) = element.Values.Data;
                end
            else
                signal = logsout.get(signal_name);
                if ~isempty(signal)
                    signals.(signal_name) = signal.Data;
                end
            end
        catch
            % Signal not found, leave empty
            signals.(signal_name) = [];
        end
    end
end

function metrics = calculateDailyMetrics(signals, time)
    % Calculate metrics for daily simulation

    metrics = struct();

    if isempty(signals) || isempty(time)
        return;
    end

    time_hours = time / 3600;

    % Energy calculations
    if ~isempty(signals.P_pv)
        metrics.pv_energy = trapz(time_hours, signals.P_pv / 1000); % kWh
    end

    if ~isempty(signals.P_load)
        metrics.load_energy = trapz(time_hours, signals.P_load / 1000); % kWh
    end

    if ~isempty(signals.P_batt)
        P_batt_kW = signals.P_batt / 1000;
        metrics.battery_charge = trapz(time_hours, max(-P_batt_kW, 0));
        metrics.battery_discharge = trapz(time_hours, max(P_batt_kW, 0));
    end

    % SOC metrics
    if ~isempty(signals.SOC)
        metrics.soc_min = min(signals.SOC);
        metrics.soc_max = max(signals.SOC);
        metrics.soc_final = signals.SOC(end);
    end

    % SOH metrics
    if ~isempty(signals.SOH)
        metrics.soh_initial = signals.SOH(1);
        metrics.soh_final = signals.SOH(end);
        metrics.soh_degradation = (metrics.soh_initial - metrics.soh_final) * 100;
    end
end

function stability_check = checkNumericalStability(signals)
    % Check for numerical stability issues

    stability_check = struct();
    stability_check.has_nan = false;
    stability_check.has_inf = false;
    stability_check.large_values = false;
    stability_check.rapid_changes = false;

    signal_names = fieldnames(signals);

    for i = 1:length(signal_names)
        signal_name = signal_names{i};
        data = signals.(signal_name);

        if ~isempty(data)
            % Check for NaN values
            if any(isnan(data))
                stability_check.has_nan = true;
                stability_check.nan_signals{end+1} = signal_name;
            end

            % Check for infinite values
            if any(isinf(data))
                stability_check.has_inf = true;
                stability_check.inf_signals{end+1} = signal_name;
            end

            % Check for unreasonably large values
            if any(abs(data) > 1e6)
                stability_check.large_values = true;
                stability_check.large_signals{end+1} = signal_name;
            end

            % Check for rapid changes (potential numerical instability)
            if length(data) > 1
                diff_data = diff(data);
                if any(abs(diff_data) > 1e5)
                    stability_check.rapid_changes = true;
                    stability_check.rapid_signals{end+1} = signal_name;
                end
            end
        end
    end

    % Overall stability assessment
    stability_check.is_stable = ~(stability_check.has_nan || stability_check.has_inf || ...
                                  stability_check.large_values || stability_check.rapid_changes);
end

function should_checkpoint = shouldCreateCheckpoint(sim_state, checkpoint_manager)
    % Determine if a checkpoint should be created

    days_since_checkpoint = sim_state.completed_days - checkpoint_manager.last_checkpoint;
    should_checkpoint = days_since_checkpoint >= checkpoint_manager.interval;
end

function createCheckpoint(sim_state, results, checkpoint_manager, config)
    % Create simulation checkpoint

    fprintf('   Creating checkpoint at day %d...\n', sim_state.completed_days);

    checkpoint_file = fullfile(checkpoint_manager.checkpoint_dir, ...
                              sprintf('checkpoint_day_%03d.mat', sim_state.completed_days));

    try
        % Prepare checkpoint data
        checkpoint_data = struct();
        checkpoint_data.sim_state = sim_state;
        checkpoint_data.completed_results = results.daily_results(1:sim_state.completed_days);
        checkpoint_data.timestamp = datetime('now');
        checkpoint_data.config = config;

        % Save checkpoint with compression if enabled
        if checkpoint_manager.data_compression
            save(checkpoint_file, 'checkpoint_data', '-v7.3', '-nocompression');
        else
            save(checkpoint_file, 'checkpoint_data', '-v7.3');
        end

        % Update checkpoint manager
        checkpoint_manager.last_checkpoint = sim_state.completed_days;
        results.checkpoints{end+1} = checkpoint_file;

        fprintf('     Checkpoint saved: %s\n', checkpoint_file);

    catch ME
        fprintf('     Warning: Could not create checkpoint: %s\n', ME.message);
    end
end

function sim_state = resumeFromCheckpoint(checkpoint_file, sim_state)
    % Resume simulation from checkpoint

    fprintf('>> Resuming from checkpoint: %s\n', checkpoint_file);

    if ~exist(checkpoint_file, 'file')
        error('Checkpoint file not found: %s', checkpoint_file);
    end

    try
        checkpoint_data = load(checkpoint_file);

        if isfield(checkpoint_data, 'checkpoint_data')
            saved_state = checkpoint_data.checkpoint_data.sim_state;

            % Restore simulation state
            sim_state.current_day = saved_state.completed_days + 1;
            sim_state.completed_days = saved_state.completed_days;
            sim_state.memory_usage_history = saved_state.memory_usage_history;
            sim_state.stability_metrics = saved_state.stability_metrics;
            sim_state.error_count = saved_state.error_count;
            sim_state.recovery_count = saved_state.recovery_count;

            fprintf('   Resumed from day %d\n', sim_state.current_day);
        else
            error('Invalid checkpoint file format');
        end

    catch ME
        error('Could not resume from checkpoint: %s', ME.message);
    end
end

function monitorStability(daily_result, sim_state, config)
    % Monitor simulation stability

    if isfield(daily_result, 'stability_check')
        stability = daily_result.stability_check;

        % Log stability metrics
        sim_state.stability_count = sim_state.stability_count + 1;
        sim_state.stability_metrics(sim_state.stability_count) = stability.is_stable;

        % Check for stability issues
        if ~stability.is_stable
            fprintf('   Warning: Stability issues detected on day %d\n', daily_result.day_number);

            % Log detailed stability information
            logStabilityIssue(daily_result, config);

            % Check if intervention is needed
            recent_start = max(1, sim_state.stability_count-6);
            recent_end = sim_state.stability_count;
            recent_stability = sim_state.stability_metrics(recent_start:recent_end); % Last 7 days
            unstable_ratio = sum(~recent_stability) / length(recent_stability);

            if unstable_ratio > 0.5 % More than 50% unstable in recent days
                fprintf('   Critical: High instability detected, consider intervention\n');
                logCriticalStability(sim_state, config);
            end
        end
    end
end

function logStabilityIssue(daily_result, config)
    % Log stability issues to file

    log_file = fullfile(config.output_dir, 'monitoring', 'stability_issues.log');

    try
        fid = fopen(log_file, 'a');
        if fid > 0
            fprintf(fid, '%s: Day %d stability issues:\n', ...
                    string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), daily_result.day_number);

            stability = daily_result.stability_check;
            if stability.has_nan
                fprintf(fid, '  - NaN values in signals: %s\n', strjoin(stability.nan_signals, ', '));
            end
            if stability.has_inf
                fprintf(fid, '  - Infinite values in signals: %s\n', strjoin(stability.inf_signals, ', '));
            end
            if stability.large_values
                fprintf(fid, '  - Large values in signals: %s\n', strjoin(stability.large_signals, ', '));
            end
            if stability.rapid_changes
                fprintf(fid, '  - Rapid changes in signals: %s\n', strjoin(stability.rapid_signals, ', '));
            end

            fclose(fid);
        end
    catch
        % Ignore logging errors
    end
end

function logCriticalStability(sim_state, config)
    % Log critical stability issues

    log_file = fullfile(config.output_dir, 'monitoring', 'critical_stability.log');

    try
        fid = fopen(log_file, 'a');
        if fid > 0
            fprintf(fid, '%s: Critical stability issue at day %d\n', ...
                    string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), sim_state.completed_days);
            recent_start = max(1, sim_state.stability_count-6);
            recent_end = sim_state.stability_count;
            fprintf(fid, '  Recent stability: %s\n', ...
                    mat2str(sim_state.stability_metrics(recent_start:recent_end)));
            fclose(fid);
        end
    catch
        % Ignore logging errors
    end
end

function reportProgress(sim_state, config)
    % Report simulation progress

    progress_pct = (sim_state.completed_days / config.simulation_days) * 100;
    elapsed_time = datetime('now') - sim_state.start_time;

    fprintf('   Progress: Day %d/%d (%.1f%%) - Elapsed: %s\n', ...
            sim_state.completed_days, config.simulation_days, progress_pct, ...
            char(elapsed_time));

    % Estimate remaining time
    if sim_state.completed_days > 0
        time_per_day = elapsed_time / sim_state.completed_days;
        remaining_days = config.simulation_days - sim_state.completed_days;
        estimated_remaining = time_per_day * remaining_days;

        fprintf('   Estimated remaining time: %s\n', char(estimated_remaining));
    end
end

function recovery_success = attemptRecovery(ME, sim_state, config)
    % Attempt to recover from simulation error

    fprintf('   Attempting recovery from error: %s\n', ME.message);

    sim_state.error_count = sim_state.error_count + 1;
    recovery_success = false;

    try
        % Recovery strategy 1: Memory cleanup and retry
        if contains(ME.message, 'memory') || contains(ME.message, 'Memory')
            fprintf('     Recovery strategy: Memory cleanup\n');

            % Aggressive memory cleanup
            evalin('base', 'clearvars -except agentObj agent memory_monitor_timer');
            java.lang.System.gc();
            pause(2); % Allow cleanup to complete

            recovery_success = true;
        end

        % Recovery strategy 2: Model reset for numerical issues
        if contains(ME.message, 'solver') || contains(ME.message, 'numerical')
            fprintf('     Recovery strategy: Model reset\n');

            % Close and reload model
            close_system(config.model_name, 0);
            load_system(config.model_name);
            configureLongTermModel(config);

            recovery_success = true;
        end

        % Recovery strategy 3: Reduce solver tolerance for stability
        if contains(ME.message, 'step size') || contains(ME.message, 'tolerance')
            fprintf('     Recovery strategy: Adjust solver settings\n');

            % Make solver more conservative
            set_param(config.model_name, 'RelTol', '1e-5');
            set_param(config.model_name, 'AbsTol', '1e-8');
            set_param(config.model_name, 'MaxStep', '1800'); % Smaller max step

            recovery_success = true;
        end

        if recovery_success
            sim_state.recovery_count = sim_state.recovery_count + 1;
            fprintf('     Recovery successful (attempt %d)\n', sim_state.recovery_count);

            % Log recovery
            logRecovery(ME, sim_state, config);
        else
            fprintf('     Recovery failed - no applicable strategy\n');
        end

    catch recovery_error
        fprintf('     Recovery failed with error: %s\n', recovery_error.message);
        recovery_success = false;
    end
end

function logRecovery(ME, sim_state, config)
    % Log recovery attempts

    log_file = fullfile(config.output_dir, 'recovery_logs', 'recovery.log');

    try
        fid = fopen(log_file, 'a');
        if fid > 0
            fprintf(fid, '%s: Recovery at day %d\n', ...
                    string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), sim_state.current_day);
            fprintf(fid, '  Original error: %s\n', ME.message);
            fprintf(fid, '  Recovery count: %d\n', sim_state.recovery_count);
            fclose(fid);
        end
    catch
        % Ignore logging errors
    end
end

function logSimulationError(ME, sim_state, config)
    % Log simulation errors

    log_file = fullfile(config.output_dir, 'recovery_logs', 'errors.log');

    try
        fid = fopen(log_file, 'a');
        if fid > 0
            fprintf(fid, '%s: Fatal error at day %d\n', ...
                    string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), sim_state.current_day);
            fprintf(fid, '  Error: %s\n', ME.message);
            fprintf(fid, '  Error count: %d\n', sim_state.error_count);
            fclose(fid);
        end
    catch
        % Ignore logging errors
    end
end

function saveDailyResult(daily_result, day_num, config)
    % Save daily result with compression

    filename = fullfile(config.output_dir, 'daily_results', ...
                       sprintf('day_%03d_result.mat', day_num));

    try
        if config.data_compression
            % Save only essential data
            compressed_result = struct();
            compressed_result.day_number = daily_result.day_number;
            compressed_result.metrics = daily_result.metrics;
            compressed_result.stability_check = daily_result.stability_check;
            compressed_result.timestamp = daily_result.timestamp;

            save(filename, 'compressed_result', '-v7.3');
        else
            save(filename, 'daily_result', '-v7.3');
        end
    catch ME
        fprintf('Warning: Could not save daily result for day %d: %s\n', day_num, ME.message);
    end
end

function cleanupAfterDaily()
    % Cleanup after daily simulation

    % Clear temporary variables from base workspace
    evalin('base', 'clearvars -except agentObj agent memory_monitor_timer');

    % Force garbage collection
    java.lang.System.gc();
end

function results = finalizeLongTermResults(results, config)
    % Finalize and save long-term results

    fprintf('>> Finalizing long-term results...\n');

    % Calculate overall statistics
    results.overall_stats = calculateOverallStats(results, config);

    % Generate summary report
    results.summary_report = generateSummaryReport(results, config);

    % Save final results
    final_results_file = fullfile(config.output_dir, 'final_long_term_results.mat');

    try
        save(final_results_file, 'results', '-v7.3');
        fprintf('   Final results saved to: %s\n', final_results_file);
    catch ME
        fprintf('   Warning: Could not save final results: %s\n', ME.message);
    end

    % Generate text summary
    generateTextSummary(results, config);

    fprintf('   Long-term results finalized.\n\n');
end

function overall_stats = calculateOverallStats(results, config)
    % Calculate overall statistics from all daily results

    overall_stats = struct();

    % Initialize accumulators
    total_pv_energy = 0;
    total_load_energy = 0;
    total_battery_charge = 0;
    total_battery_discharge = 0;
    soc_values = NaN(config.simulation_days, 1); % Pre-allocate with NaN
    soh_values = NaN(config.simulation_days, 1); % Pre-allocate with NaN
    soc_count = 0;
    soh_count = 0;
    stability_count = 0;

    % Process all daily results
    for day = 1:config.simulation_days
        if ~isempty(results.daily_results{day}) && isfield(results.daily_results{day}, 'metrics')
            metrics = results.daily_results{day}.metrics;

            % Accumulate energy metrics
            if isfield(metrics, 'pv_energy')
                total_pv_energy = total_pv_energy + metrics.pv_energy;
            end
            if isfield(metrics, 'load_energy')
                total_load_energy = total_load_energy + metrics.load_energy;
            end
            if isfield(metrics, 'battery_charge')
                total_battery_charge = total_battery_charge + metrics.battery_charge;
            end
            if isfield(metrics, 'battery_discharge')
                total_battery_discharge = total_battery_discharge + metrics.battery_discharge;
            end

            % Collect SOC and SOH values
            if isfield(metrics, 'soc_final')
                soc_count = soc_count + 1;
                soc_values(soc_count) = metrics.soc_final;
            end
            if isfield(metrics, 'soh_final')
                soh_count = soh_count + 1;
                soh_values(soh_count) = metrics.soh_final;
            end

            % Count stable days
            if isfield(results.daily_results{day}, 'stability_check') && ...
               results.daily_results{day}.stability_check.is_stable
                stability_count = stability_count + 1;
            end
        end
    end

    % Calculate overall statistics
    overall_stats.total_pv_energy_kwh = total_pv_energy;
    overall_stats.total_load_energy_kwh = total_load_energy;
    overall_stats.total_battery_charge_kwh = total_battery_charge;
    overall_stats.total_battery_discharge_kwh = total_battery_discharge;
    overall_stats.net_grid_energy_kwh = total_load_energy - total_pv_energy;

    if soc_count > 0
        valid_soc = soc_values(1:soc_count);
        overall_stats.final_soc = valid_soc(end);
        overall_stats.avg_soc = mean(valid_soc);
        overall_stats.soc_range = [min(valid_soc), max(valid_soc)];
    end

    if soh_count > 0
        valid_soh = soh_values(1:soh_count);
        overall_stats.initial_soh = valid_soh(1);
        overall_stats.final_soh = valid_soh(end);
        overall_stats.total_soh_degradation = (valid_soh(1) - valid_soh(end)) * 100;
    end

    overall_stats.stability_ratio = stability_count / config.simulation_days;
    overall_stats.simulation_days = config.simulation_days;
end

function summary_report = generateSummaryReport(results, config)
    % Generate summary report

    summary_report = struct();
    summary_report.simulation_config = config;
    summary_report.completion_time = datetime('now');
    summary_report.overall_stats = results.overall_stats;

    % Performance metrics
    if isfield(results, 'overall_stats')
        stats = results.overall_stats;

        % Energy efficiency
        if isfield(stats, 'total_pv_energy_kwh') && stats.total_pv_energy_kwh > 0
            summary_report.pv_utilization_pct = ((stats.total_pv_energy_kwh - max(0, -stats.net_grid_energy_kwh)) / stats.total_pv_energy_kwh) * 100;
        end

        if isfield(stats, 'total_load_energy_kwh') && stats.total_load_energy_kwh > 0
            summary_report.self_sufficiency_pct = ((stats.total_load_energy_kwh - max(0, stats.net_grid_energy_kwh)) / stats.total_load_energy_kwh) * 100;
        end

        % Battery performance
        if isfield(stats, 'total_battery_charge_kwh') && isfield(stats, 'total_battery_discharge_kwh')
            if stats.total_battery_charge_kwh > 0
                summary_report.battery_efficiency_pct = (stats.total_battery_discharge_kwh / stats.total_battery_charge_kwh) * 100;
            end
        end

        % Stability assessment
        summary_report.stability_assessment = assessStability(stats.stability_ratio);
    end
end

function assessment = assessStability(stability_ratio)
    % Assess simulation stability

    if stability_ratio >= 0.95
        assessment = 'Excellent';
    elseif stability_ratio >= 0.90
        assessment = 'Good';
    elseif stability_ratio >= 0.80
        assessment = 'Fair';
    elseif stability_ratio >= 0.70
        assessment = 'Poor';
    else
        assessment = 'Critical';
    end
end

function generateTextSummary(results, config)
    % Generate human-readable text summary

    summary_file = fullfile(config.output_dir, 'simulation_summary.txt');

    try
        fid = fopen(summary_file, 'w');
        if fid > 0
            fprintf(fid, 'LONG-TERM MICROGRID SIMULATION SUMMARY\n');
            fprintf(fid, '=====================================\n\n');

            fprintf(fid, 'Simulation Configuration:\n');
            fprintf(fid, '  Duration: %d days\n', config.simulation_days);
            fprintf(fid, '  Checkpoint Interval: %d days\n', config.checkpoint_interval);
            fprintf(fid, '  Completion Time: %s\n\n', char(results.summary_report.completion_time));

            if isfield(results, 'overall_stats')
                stats = results.overall_stats;

                fprintf(fid, 'Energy Performance:\n');
                if isfield(stats, 'total_pv_energy_kwh')
                    fprintf(fid, '  Total PV Generation: %.2f kWh\n', stats.total_pv_energy_kwh);
                end
                if isfield(stats, 'total_load_energy_kwh')
                    fprintf(fid, '  Total Load Consumption: %.2f kWh\n', stats.total_load_energy_kwh);
                end
                if isfield(stats, 'net_grid_energy_kwh')
                    fprintf(fid, '  Net Grid Exchange: %.2f kWh\n', stats.net_grid_energy_kwh);
                end

                fprintf(fid, '\nBattery Performance:\n');
                if isfield(stats, 'total_soh_degradation')
                    fprintf(fid, '  Total SOH Degradation: %.4f%%\n', stats.total_soh_degradation);
                end
                if isfield(stats, 'final_soc')
                    fprintf(fid, '  Final SOC: %.1f%%\n', stats.final_soc);
                end

                fprintf(fid, '\nStability Assessment:\n');
                fprintf(fid, '  Stability Ratio: %.1f%%\n', stats.stability_ratio * 100);
                fprintf(fid, '  Assessment: %s\n', results.summary_report.stability_assessment);
            end

            fclose(fid);
            fprintf('   Text summary saved to: %s\n', summary_file);
        end
    catch ME
        fprintf('   Warning: Could not generate text summary: %s\n', ME.message);
    end
end

function handleLongTermError(ME, config)
    % Handle long-term simulation errors

    fprintf('\nERROR: Long-term simulation failed\n');
    fprintf('Error: %s\n', ME.message);

    % Save error information
    error_file = fullfile(config.output_dir, 'simulation_error.mat');
    try
        error_info = struct();
        error_info.error = ME;
        error_info.config = config;
        error_info.timestamp = datetime('now');

        save(error_file, 'error_info');
        fprintf('Error information saved to: %s\n', error_file);
    catch
        fprintf('Could not save error information\n');
    end
end

function cleanupLongTermSimulation(config)
    % Cleanup long-term simulation resources

    % Stop memory monitor timer
    try
        timer_obj = evalin('base', 'memory_monitor_timer');
        if isvalid(timer_obj)
            stop(timer_obj);
            delete(timer_obj);
        end
        evalin('base', 'clear memory_monitor_timer');
    catch
        % Timer may not exist
    end

    % Close model
    try
        if bdIsLoaded(config.model_name)
            close_system(config.model_name, 0);
        end
    catch
        % Ignore cleanup errors
    end

    % Final cleanup
    java.lang.System.gc();
end
