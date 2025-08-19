% =========================================================================
%                    modular_plotting_system.m
% -------------------------------------------------------------------------
% Description:
%   Modular and extensible plotting system for microgrid simulation results
%   
%   Features:
%   - Independent plotting modules for different chart types
%   - Configurable plot styles and themes
%   - Automatic data detection and processing
%   - Multiple output formats (PNG, PDF, SVG, FIG)
%   - Batch plotting capabilities
%   - Integration with main simulation scripts
%   - Extensible architecture for custom plots
%
% Usage:
%   % Standalone plotting
%   modular_plotting_system('data_file', 'results.mat', 'plot_types', 'all');
%   
%   % Custom configuration
%   config = struct('theme', 'publication', 'resolution', 300, 'format', 'pdf');
%   modular_plotting_system('data_file', 'results.mat', 'config', config);
%
% Author: Augment Agent
% Date: 2025-08-06
% Version: 1.0
% =========================================================================

function plot_results = modular_plotting_system(varargin)
    % Main function for modular plotting system
    
    % Parse input arguments
    p = inputParser;
    addParameter(p, 'data_file', '', @ischar);
    addParameter(p, 'data_struct', [], @isstruct);
    addParameter(p, 'plot_types', 'all', @(x) ischar(x) || iscell(x));
    addParameter(p, 'output_dir', 'plots', @ischar);
    addParameter(p, 'config', struct(), @isstruct);
    addParameter(p, 'theme', 'default', @ischar);
    addParameter(p, 'save_plots', true, @islogical);
    addParameter(p, 'show_plots', true, @islogical);
    addParameter(p, 'format', 'png', @ischar);
    addParameter(p, 'resolution', 300, @isnumeric);
    addParameter(p, 'verbose', true, @islogical);
    parse(p, varargin{:});
    
    params = p.Results;
    
    try
        % Initialize plotting system
        plot_config = initializePlottingSystem(params);
        
        % Load and process data
        data = loadPlottingData(params);
        
        % Generate plots
        plot_results = generatePlots(data, plot_config);
        
        if params.verbose
            displayPlottingResults(plot_results);
        end
        
    catch ME
        handlePlottingError(ME, params);
        rethrow(ME);
    end
end

function plot_config = initializePlottingSystem(params)
    % Initialize plotting system configuration
    
    if params.verbose
        fprintf('=========================================================================\n');
        fprintf('                MODULAR PLOTTING SYSTEM v1.0\n');
        fprintf('=========================================================================\n');
    end
    
    % Create output directory
    if ~exist(params.output_dir, 'dir')
        mkdir(params.output_dir);
    end
    
    % Initialize configuration
    plot_config = struct();
    plot_config.output_dir = params.output_dir;
    plot_config.theme = params.theme;
    plot_config.save_plots = params.save_plots;
    plot_config.show_plots = params.show_plots;
    plot_config.format = params.format;
    plot_config.resolution = params.resolution;
    plot_config.verbose = params.verbose;
    
    % Merge with custom config
    if ~isempty(params.config)
        config_fields = fieldnames(params.config);
        for i = 1:length(config_fields)
            plot_config.(config_fields{i}) = params.config.(config_fields{i});
        end
    end
    
    % Set plot types
    if ischar(params.plot_types) && strcmp(params.plot_types, 'all')
        plot_config.plot_types = {'power_balance', 'soc_price', 'soh_degradation', ...
                                  'energy_flow', 'battery_performance', 'economic_analysis', ...
                                  'stability_metrics', 'long_term_trends'};
    elseif iscell(params.plot_types)
        plot_config.plot_types = params.plot_types;
    else
        plot_config.plot_types = {params.plot_types};
    end
    
    % Apply theme settings
    applyPlotTheme(plot_config.theme);
    
    if params.verbose
        fprintf('>> Plotting system initialized\n');
        fprintf('   Output directory: %s\n', plot_config.output_dir);
        fprintf('   Theme: %s\n', plot_config.theme);
        fprintf('   Plot types: %s\n', strjoin(plot_config.plot_types, ', '));
        fprintf('   Format: %s (%d DPI)\n', plot_config.format, plot_config.resolution);
        fprintf('=========================================================================\n\n');
    end
end

function applyPlotTheme(theme_name)
    % Apply plotting theme
    
    switch lower(theme_name)
        case 'publication'
            % Publication-ready theme
            set(groot, 'DefaultFigureColor', 'white');
            set(groot, 'DefaultAxesFontSize', 12);
            set(groot, 'DefaultAxesFontName', 'Times New Roman');
            set(groot, 'DefaultTextFontSize', 12);
            set(groot, 'DefaultTextFontName', 'Times New Roman');
            set(groot, 'DefaultLegendFontSize', 10);
            set(groot, 'DefaultAxesLineWidth', 1.2);
            set(groot, 'DefaultLineLineWidth', 1.5);
            
        case 'presentation'
            % Presentation theme with larger fonts
            set(groot, 'DefaultFigureColor', 'white');
            set(groot, 'DefaultAxesFontSize', 14);
            set(groot, 'DefaultAxesFontName', 'Arial');
            set(groot, 'DefaultTextFontSize', 14);
            set(groot, 'DefaultTextFontName', 'Arial');
            set(groot, 'DefaultLegendFontSize', 12);
            set(groot, 'DefaultAxesLineWidth', 1.5);
            set(groot, 'DefaultLineLineWidth', 2);
            
        case 'dark'
            % Dark theme
            set(groot, 'DefaultFigureColor', [0.1 0.1 0.1]);
            set(groot, 'DefaultAxesColor', [0.15 0.15 0.15]);
            set(groot, 'DefaultAxesXColor', 'white');
            set(groot, 'DefaultAxesYColor', 'white');
            set(groot, 'DefaultTextColor', 'white');
            set(groot, 'DefaultAxesFontSize', 11);
            
        otherwise % 'default'
            % MATLAB default theme
            set(groot, 'DefaultFigureColor', 'white');
            set(groot, 'DefaultAxesFontSize', 11);
            set(groot, 'DefaultAxesFontName', 'Helvetica');
            set(groot, 'DefaultTextFontSize', 11);
            set(groot, 'DefaultLegendFontSize', 9);
    end
end

function data = loadPlottingData(params)
    % Load data for plotting
    
    if ~isempty(params.data_struct)
        % Use provided data structure
        data = params.data_struct;
        
    elseif ~isempty(params.data_file)
        % Load from file
        if ~exist(params.data_file, 'file')
            error('Data file not found: %s', params.data_file);
        end
        
        loaded_data = load(params.data_file);
        
        % Try to find the main data structure
        if isfield(loaded_data, 'simulation_results')
            data = loaded_data.simulation_results;
        elseif isfield(loaded_data, 'results')
            data = loaded_data.results;
        else
            % Use the entire loaded structure
            data = loaded_data;
        end
        
    else
        error('No data source specified. Provide either data_file or data_struct.');
    end
    
    % Process and validate data
    data = processPlottingData(data);
end

function processed_data = processPlottingData(raw_data)
    % Process raw data for plotting
    
    processed_data = struct();
    
    % Detect data structure type
    if isfield(raw_data, 'segments') % High-performance simulation results
        processed_data = processSegmentedData(raw_data);
        
    elseif isfield(raw_data, 'daily_results') % Long-term simulation results
        processed_data = processLongTermData(raw_data);
        
    elseif isfield(raw_data, 'signals') % Direct signal data
        processed_data = processSignalData(raw_data);
        
    else
        % Try to extract data from various possible structures
        processed_data = extractDataFromStructure(raw_data);
    end
    
    % Validate processed data
    validatePlottingData(processed_data);
end

function data = processSegmentedData(raw_data)
    % Process segmented simulation data
    
    data = struct();
    data.type = 'segmented';
    data.segments = raw_data.segments;
    
    % Combine all segments
    combined_signals = struct();
    combined_time = [];
    
    for i = 1:length(raw_data.segments)
        segment = raw_data.segments{i};
        if isfield(segment, 'signals') && ~isempty(segment.signals)
            signal_names = fieldnames(segment.signals);
            
            for j = 1:length(signal_names)
                signal_name = signal_names{j};
                signal_data = segment.signals.(signal_name);
                
                if ~isempty(signal_data)
                    if ~isfield(combined_signals, signal_name)
                        combined_signals.(signal_name) = signal_data;
                    else
                        combined_signals.(signal_name) = [combined_signals.(signal_name); signal_data];
                    end
                end
            end
            
            % Combine time vectors
            if isfield(segment, 'time')
                time_offset = (i - 1) * segment.segment_days * 24 * 3600;
                adjusted_time = segment.time + time_offset;
                combined_time = [combined_time; adjusted_time];
            end
        end
    end
    
    data.signals = combined_signals;
    data.time = combined_time;
    data.time_days = combined_time / (24 * 3600);
    
    % Extract overall metrics if available
    if isfield(raw_data, 'overall_metrics')
        data.metrics = raw_data.overall_metrics;
    end
end

function data = processLongTermData(raw_data)
    % Process long-term simulation data
    
    data = struct();
    data.type = 'long_term';
    data.daily_results = raw_data.daily_results;
    
    % Extract time series from daily results
    combined_signals = struct();
    time_vector = [];
    
    for day = 1:length(raw_data.daily_results)
        daily_result = raw_data.daily_results{day};
        
        if ~isempty(daily_result) && isfield(daily_result, 'signals')
            signal_names = fieldnames(daily_result.signals);
            
            for i = 1:length(signal_names)
                signal_name = signal_names{i};
                signal_data = daily_result.signals.(signal_name);
                
                if ~isempty(signal_data)
                    if ~isfield(combined_signals, signal_name)
                        combined_signals.(signal_name) = signal_data;
                    else
                        combined_signals.(signal_name) = [combined_signals.(signal_name); signal_data];
                    end
                end
            end
            
            % Build time vector
            if isfield(daily_result, 'time')
                time_offset = (day - 1) * 24 * 3600;
                adjusted_time = daily_result.time + time_offset;
                time_vector = [time_vector; adjusted_time];
            end
        end
    end
    
    data.signals = combined_signals;
    data.time = time_vector;
    data.time_days = time_vector / (24 * 3600);
    
    % Extract overall statistics
    if isfield(raw_data, 'overall_stats')
        data.metrics = raw_data.overall_stats;
    end
end

function data = processSignalData(raw_data)
    % Process direct signal data
    
    data = struct();
    data.type = 'signals';
    data.signals = raw_data.signals;
    
    if isfield(raw_data, 'time')
        data.time = raw_data.time;
        data.time_days = raw_data.time / (24 * 3600);
    end
    
    if isfield(raw_data, 'metrics')
        data.metrics = raw_data.metrics;
    end
end

function data = extractDataFromStructure(raw_data)
    % Extract data from unknown structure
    
    data = struct();
    data.type = 'unknown';
    data.signals = struct();
    
    % Try to find common signal names
    common_signals = {'P_pv', 'P_load', 'P_batt', 'P_grid', 'SOC', 'SOH', 'price'};
    
    for i = 1:length(common_signals)
        signal_name = common_signals{i};
        if isfield(raw_data, signal_name)
            data.signals.(signal_name) = raw_data.(signal_name);
        end
    end
    
    % Try to find time vector
    time_fields = {'time', 'tout', 't', 'Time'};
    for i = 1:length(time_fields)
        if isfield(raw_data, time_fields{i})
            data.time = raw_data.(time_fields{i});
            data.time_days = data.time / (24 * 3600);
            break;
        end
    end
end

function validatePlottingData(data)
    % Validate data for plotting
    
    if ~isfield(data, 'signals') || isempty(data.signals)
        warning('No signal data found for plotting');
    end
    
    if ~isfield(data, 'time') || isempty(data.time)
        warning('No time vector found for plotting');
    end
    
    % Check for minimum required signals
    required_signals = {'P_pv', 'P_load', 'SOC'};
    missing_signals = {};
    
    for i = 1:length(required_signals)
        if ~isfield(data.signals, required_signals{i}) || isempty(data.signals.(required_signals{i}))
            missing_signals{end+1} = required_signals{i};
        end
    end
    
    if ~isempty(missing_signals)
        warning('Missing required signals for plotting: %s', strjoin(missing_signals, ', '));
    end
end

function plot_results = generatePlots(data, plot_config)
    % Generate all requested plots

    if plot_config.verbose
        fprintf('>> Generating plots...\n');
    end

    plot_results = struct();
    plot_results.generated_plots = {};
    plot_results.failed_plots = {};
    plot_results.plot_files = {};

    % Generate each requested plot type
    for i = 1:length(plot_config.plot_types)
        plot_type = plot_config.plot_types{i};

        try
            if plot_config.verbose
                fprintf('   Generating %s plot...\n', plot_type);
            end

            % Generate plot
            fig_handle = generateSinglePlot(data, plot_type, plot_config);

            if ~isempty(fig_handle)
                % Save plot if requested
                if plot_config.save_plots
                    plot_file = savePlot(fig_handle, plot_type, plot_config);
                    plot_results.plot_files{end+1} = plot_file;
                end

                % Close figure if not showing
                if ~plot_config.show_plots
                    close(fig_handle);
                end

                plot_results.generated_plots{end+1} = plot_type;
            end

        catch ME
            if plot_config.verbose
                fprintf('     Warning: Failed to generate %s plot: %s\n', plot_type, ME.message);
            end
            plot_results.failed_plots{end+1} = struct('type', plot_type, 'error', ME.message);
        end
    end

    if plot_config.verbose
        fprintf('   Plot generation complete. Generated: %d, Failed: %d\n', ...
                length(plot_results.generated_plots), length(plot_results.failed_plots));
    end
end

function fig_handle = generateSinglePlot(data, plot_type, plot_config)
    % Generate a single plot based on type

    switch lower(plot_type)
        case 'power_balance'
            fig_handle = plotPowerBalance(data, plot_config);
        case 'soc_price'
            fig_handle = plotSOCPrice(data, plot_config);
        case 'soh_degradation'
            fig_handle = plotSOHDegradation(data, plot_config);
        case 'energy_flow'
            fig_handle = plotEnergyFlow(data, plot_config);
        case 'battery_performance'
            fig_handle = plotBatteryPerformance(data, plot_config);
        case 'economic_analysis'
            fig_handle = plotEconomicAnalysis(data, plot_config);
        case 'stability_metrics'
            fig_handle = plotStabilityMetrics(data, plot_config);
        case 'long_term_trends'
            fig_handle = plotLongTermTrends(data, plot_config);
        otherwise
            warning('Unknown plot type: %s', plot_type);
            fig_handle = [];
    end
end

function fig_handle = plotPowerBalance(data, ~)
    % Plot system power balance

    fig_handle = figure('Name', 'System Power Balance', 'NumberTitle', 'off', ...
                       'Position', [100 100 1200 600]);

    if ~isfield(data, 'time_days') || ~isfield(data, 'signals')
        error('Insufficient data for power balance plot');
    end

    time_days = data.time_days;
    signals = data.signals;

    hold on;

    % Plot power signals
    if isfield(signals, 'P_pv') && ~isempty(signals.P_pv)
        plot(time_days, signals.P_pv / 1000, 'g-', 'LineWidth', 1.5, 'DisplayName', 'PV Generation');
    end

    if isfield(signals, 'P_load') && ~isempty(signals.P_load)
        plot(time_days, signals.P_load / 1000, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Load Demand');
    end

    if isfield(signals, 'P_batt') && ~isempty(signals.P_batt)
        plot(time_days, signals.P_batt / 1000, 'm-.', 'LineWidth', 2, 'DisplayName', 'Battery Power');
    end

    if isfield(signals, 'P_grid') && ~isempty(signals.P_grid)
        plot(time_days, signals.P_grid / 1000, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Grid Power');
    elseif isfield(signals, 'P_pv') && isfield(signals, 'P_load') && isfield(signals, 'P_batt')
        % Calculate grid power
        P_grid = signals.P_load - signals.P_pv - signals.P_batt;
        plot(time_days, P_grid / 1000, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Grid Power (calc)');
    end

    hold off;

    % Formatting
    xlabel('Time (days)');
    ylabel('Power (kW)');
    title('System Power Balance');
    legend('show', 'Location', 'best');
    grid on;

    if ~isempty(time_days)
        xlim([0 time_days(end)]);
    end

    % Add zero line
    yline(0, 'k:', 'Alpha', 0.5);
end

function fig_handle = plotSOCPrice(data, ~)
    % Plot SOC vs electricity price

    fig_handle = figure('Name', 'SOC vs Electricity Price', 'NumberTitle', 'off', ...
                       'Position', [150 150 1200 600]);

    if ~isfield(data, 'time_days') || ~isfield(data, 'signals')
        error('Insufficient data for SOC-price plot');
    end

    time_days = data.time_days;
    signals = data.signals;

    % Create dual y-axis plot
    yyaxis left;
    if isfield(signals, 'SOC') && ~isempty(signals.SOC)
        plot(time_days, signals.SOC, 'b-', 'LineWidth', 1.5);
        ylabel('SOC (%)');
        ylim([0 100]);
    end

    yyaxis right;
    if isfield(signals, 'price') && ~isempty(signals.price)
        plot(time_days, signals.price, 'r--', 'LineWidth', 1.5);
        ylabel('Electricity Price ($/kWh)');
    end

    % Formatting
    xlabel('Time (days)');
    title('Battery SOC vs Electricity Price');
    legend({'SOC', 'Price'}, 'Location', 'best');
    grid on;

    if ~isempty(time_days)
        xlim([0 time_days(end)]);
    end
end

function fig_handle = plotSOHDegradation(data, ~)
    % Plot SOH degradation over time

    fig_handle = figure('Name', 'SOH Degradation', 'NumberTitle', 'off', ...
                       'Position', [200 200 1200 600]);

    if ~isfield(data, 'time_days') || ~isfield(data, 'signals')
        error('Insufficient data for SOH degradation plot');
    end

    time_days = data.time_days;
    signals = data.signals;

    if isfield(signals, 'SOH') && ~isempty(signals.SOH)
        plot(time_days, signals.SOH * 100, 'k-', 'LineWidth', 1.5);

        % Calculate degradation
        initial_soh = signals.SOH(1) * 100;
        final_soh = signals.SOH(end) * 100;
        total_degradation = initial_soh - final_soh;

        % Formatting
        xlabel('Time (days)');
        ylabel('SOH (%)');
        title(sprintf('Battery SOH Degradation (Total: %.4f%% over %.1f days)', ...
                     total_degradation, time_days(end)));
        grid on;

        % Set appropriate y-axis limits
        ylim_padding = max(total_degradation * 0.1, 0.01);
        ylim([final_soh - ylim_padding, initial_soh + ylim_padding]);

        if ~isempty(time_days)
            xlim([0 time_days(end)]);
        end

        % Add degradation rate annotation
        if length(time_days) > 1
            degradation_rate = total_degradation / time_days(end);
            text(0.02, 0.98, sprintf('Degradation Rate: %.6f%%/day', degradation_rate), ...
                 'Units', 'normalized', 'VerticalAlignment', 'top', ...
                 'BackgroundColor', 'white', 'EdgeColor', 'black');
        end
    else
        % No SOH data available
        text(0.5, 0.5, 'SOH data not available', ...
             'HorizontalAlignment', 'center', 'Units', 'normalized', ...
             'FontSize', 14);
        title('Battery SOH Degradation (Data Not Available)');
    end
end

function fig_handle = plotEnergyFlow(data, ~)
    % Plot energy flow diagram/summary

    fig_handle = figure('Name', 'Energy Flow Analysis', 'NumberTitle', 'off', ...
                       'Position', [250 250 1000 800]);

    if ~isfield(data, 'metrics') && ~isfield(data, 'signals')
        error('Insufficient data for energy flow plot');
    end

    % Calculate energy metrics if not available
    if isfield(data, 'metrics')
        metrics = data.metrics;
    else
        metrics = calculateEnergyMetrics(data);
    end

    % Create energy flow visualization
    subplot(2, 2, 1);
    if isfield(metrics, 'total_pv_energy_kwh')
        energy_sources = [metrics.total_pv_energy_kwh];
        labels_sources = {'PV Generation'};
        pie(energy_sources, labels_sources);
        title('Energy Sources');
    end

    subplot(2, 2, 2);
    if isfield(metrics, 'total_load_energy_kwh')
        energy_consumption = [metrics.total_load_energy_kwh];
        labels_consumption = {'Load Consumption'};
        pie(energy_consumption, labels_consumption);
        title('Energy Consumption');
    end

    subplot(2, 2, 3);
    if isfield(metrics, 'battery_charge_energy') && isfield(metrics, 'battery_discharge_energy')
        battery_energy = [metrics.battery_charge_energy, metrics.battery_discharge_energy];
        labels_battery = {'Charge', 'Discharge'};
        pie(battery_energy, labels_battery);
        title('Battery Energy Flow');
    end

    subplot(2, 2, 4);
    if isfield(metrics, 'grid_import_energy') && isfield(metrics, 'grid_export_energy')
        grid_energy = [metrics.grid_import_energy, metrics.grid_export_energy];
        labels_grid = {'Import', 'Export'};
        pie(grid_energy, labels_grid);
        title('Grid Energy Exchange');
    end

    sgtitle('Energy Flow Analysis', 'FontSize', 16, 'FontWeight', 'bold');
end

function metrics = calculateEnergyMetrics(data)
    % Calculate energy metrics from signal data

    metrics = struct();

    if ~isfield(data, 'signals') || ~isfield(data, 'time')
        return;
    end

    signals = data.signals;
    time_hours = data.time / 3600;

    % Energy calculations
    if isfield(signals, 'P_pv') && ~isempty(signals.P_pv)
        metrics.total_pv_energy_kwh = trapz(time_hours, signals.P_pv / 1000);
    end

    if isfield(signals, 'P_load') && ~isempty(signals.P_load)
        metrics.total_load_energy_kwh = trapz(time_hours, signals.P_load / 1000);
    end

    if isfield(signals, 'P_batt') && ~isempty(signals.P_batt)
        P_batt_kW = signals.P_batt / 1000;
        metrics.battery_charge_energy = trapz(time_hours, max(-P_batt_kW, 0));
        metrics.battery_discharge_energy = trapz(time_hours, max(P_batt_kW, 0));
    end

    if isfield(signals, 'P_grid') && ~isempty(signals.P_grid)
        P_grid_kW = signals.P_grid / 1000;
        metrics.grid_import_energy = trapz(time_hours, max(P_grid_kW, 0));
        metrics.grid_export_energy = trapz(time_hours, abs(min(P_grid_kW, 0)));
    end
end

function fig_handle = plotBatteryPerformance(data, ~)
    % Plot comprehensive battery performance

    fig_handle = figure('Name', 'Battery Performance Analysis', 'NumberTitle', 'off', ...
                       'Position', [300 300 1200 800]);

    if ~isfield(data, 'signals')
        error('Insufficient data for battery performance plot');
    end

    signals = data.signals;
    time_days = data.time_days;

    % SOC subplot
    subplot(2, 2, 1);
    if isfield(signals, 'SOC') && ~isempty(signals.SOC)
        plot(time_days, signals.SOC, 'b-', 'LineWidth', 1.5);
        xlabel('Time (days)');
        ylabel('SOC (%)');
        title('State of Charge');
        grid on;
        ylim([0 100]);

        % Add operating limits
        yline(15, 'r--', 'Lower Limit', 'Alpha', 0.7);
        yline(95, 'r--', 'Upper Limit', 'Alpha', 0.7);
    end

    % SOH subplot
    subplot(2, 2, 2);
    if isfield(signals, 'SOH') && ~isempty(signals.SOH)
        plot(time_days, signals.SOH * 100, 'k-', 'LineWidth', 1.5);
        xlabel('Time (days)');
        ylabel('SOH (%)');
        title('State of Health');
        grid on;
    end

    % Battery power subplot
    subplot(2, 2, 3);
    if isfield(signals, 'P_batt') && ~isempty(signals.P_batt)
        plot(time_days, signals.P_batt / 1000, 'm-', 'LineWidth', 1.5);
        xlabel('Time (days)');
        ylabel('Power (kW)');
        title('Battery Power');
        grid on;
        yline(0, 'k:', 'Alpha', 0.5);

        % Add power limits
        yline(500, 'r--', 'Max Discharge', 'Alpha', 0.7);
        yline(-500, 'r--', 'Max Charge', 'Alpha', 0.7);
    end

    % Power vs SOC scatter plot
    subplot(2, 2, 4);
    if isfield(signals, 'P_batt') && isfield(signals, 'SOC') && ...
       ~isempty(signals.P_batt) && ~isempty(signals.SOC)
        scatter(signals.SOC, signals.P_batt / 1000, 10, time_days, 'filled');
        xlabel('SOC (%)');
        ylabel('Battery Power (kW)');
        title('Power vs SOC');
        colorbar('Label', 'Time (days)');
        grid on;
    end

    sgtitle('Battery Performance Analysis', 'FontSize', 16, 'FontWeight', 'bold');
end

function fig_handle = plotEconomicAnalysis(data, ~)
    % Plot economic analysis

    fig_handle = figure('Name', 'Economic Analysis', 'NumberTitle', 'off', ...
                       'Position', [350 350 1200 600]);

    if ~isfield(data, 'signals')
        error('Insufficient data for economic analysis plot');
    end

    signals = data.signals;
    time_days = data.time_days;

    % Price and grid power subplot
    subplot(2, 1, 1);
    yyaxis left;
    if isfield(signals, 'price') && ~isempty(signals.price)
        plot(time_days, signals.price, 'r-', 'LineWidth', 1.5);
        ylabel('Price ($/kWh)');
    end

    yyaxis right;
    if isfield(signals, 'P_grid') && ~isempty(signals.P_grid)
        plot(time_days, signals.P_grid / 1000, 'b-', 'LineWidth', 1.5);
        ylabel('Grid Power (kW)');
    end

    xlabel('Time (days)');
    title('Electricity Price vs Grid Power');
    legend({'Price', 'Grid Power'}, 'Location', 'best');
    grid on;

    % Cumulative cost subplot
    subplot(2, 1, 2);
    if isfield(signals, 'price') && isfield(signals, 'P_grid') && ...
       ~isempty(signals.price) && ~isempty(signals.P_grid)

        % Calculate instantaneous cost
        time_hours = data.time / 3600;
        dt = diff([0; time_hours]);
        instantaneous_cost = (signals.P_grid / 1000) .* signals.price .* dt;
        cumulative_cost = cumsum(instantaneous_cost);

        plot(time_days, cumulative_cost, 'g-', 'LineWidth', 2);
        xlabel('Time (days)');
        ylabel('Cumulative Cost ($)');
        title('Cumulative Electricity Cost');
        grid on;

        % Add final cost annotation
        final_cost = cumulative_cost(end);
        text(0.02, 0.98, sprintf('Total Cost: $%.2f', final_cost), ...
             'Units', 'normalized', 'VerticalAlignment', 'top', ...
             'BackgroundColor', 'white', 'EdgeColor', 'black');
    end

    sgtitle('Economic Analysis', 'FontSize', 16, 'FontWeight', 'bold');
end

function fig_handle = plotStabilityMetrics(data, ~)
    % Plot stability metrics

    fig_handle = figure('Name', 'Stability Metrics', 'NumberTitle', 'off', ...
                       'Position', [400 400 1200 600]);

    if strcmp(data.type, 'long_term') && isfield(data, 'daily_results')
        % Plot daily stability metrics
        num_days = length(data.daily_results);
        daily_stability = NaN(num_days, 1);
        days = NaN(num_days, 1);
        count = 0;

        for day = 1:num_days
            if ~isempty(data.daily_results{day}) && ...
               isfield(data.daily_results{day}, 'stability_check')
                stability = data.daily_results{day}.stability_check.is_stable;
                count = count + 1;
                daily_stability(count) = double(stability);
                days(count) = day;
            end
        end

        % Trim arrays to actual size
        if count > 0
            daily_stability = daily_stability(1:count);
            days = days(1:count);
        else
            daily_stability = [];
            days = [];
        end

        if ~isempty(daily_stability)
            subplot(2, 1, 1);
            bar(days, daily_stability, 'FaceColor', [0.2 0.6 0.8]);
            xlabel('Day');
            ylabel('Stable (1) / Unstable (0)');
            title('Daily Stability Status');
            grid on;
            ylim([-0.1 1.1]);

            % Moving average
            subplot(2, 1, 2);
            window_size = min(7, length(daily_stability));
            if length(daily_stability) >= window_size
                moving_avg = movmean(daily_stability, window_size);
                plot(days, moving_avg * 100, 'r-', 'LineWidth', 2);
                xlabel('Day');
                ylabel('Stability Percentage (%)');
                title(sprintf('Stability Trend (%d-day moving average)', window_size));
                grid on;
                ylim([0 100]);

                % Add stability threshold line
                yline(80, 'g--', 'Good Stability Threshold', 'Alpha', 0.7);
            end
        end
    else
        % Plot signal-based stability metrics
        text(0.5, 0.5, 'Stability metrics not available for this data type', ...
             'HorizontalAlignment', 'center', 'Units', 'normalized', ...
             'FontSize', 14);
    end

    sgtitle('Stability Metrics', 'FontSize', 16, 'FontWeight', 'bold');
end

function fig_handle = plotLongTermTrends(data, ~)
    % Plot long-term trends

    fig_handle = figure('Name', 'Long-term Trends', 'NumberTitle', 'off', ...
                       'Position', [450 450 1200 800]);

    if ~isfield(data, 'time_days') || length(data.time_days) < 7
        text(0.5, 0.5, 'Insufficient data for long-term trend analysis', ...
             'HorizontalAlignment', 'center', 'Units', 'normalized', ...
             'FontSize', 14);
        return;
    end

    time_days = data.time_days;
    signals = data.signals;

    % Daily averages
    num_days = floor(time_days(end));
    daily_avg_pv = zeros(num_days, 1);
    daily_avg_load = zeros(num_days, 1);
    daily_avg_soc = zeros(num_days, 1);
    daily_soh = zeros(num_days, 1);

    for day = 1:num_days
        day_indices = (time_days >= (day-1)) & (time_days < day);

        if any(day_indices)
            if isfield(signals, 'P_pv') && ~isempty(signals.P_pv)
                daily_avg_pv(day) = mean(signals.P_pv(day_indices)) / 1000;
            end
            if isfield(signals, 'P_load') && ~isempty(signals.P_load)
                daily_avg_load(day) = mean(signals.P_load(day_indices)) / 1000;
            end
            if isfield(signals, 'SOC') && ~isempty(signals.SOC)
                daily_avg_soc(day) = mean(signals.SOC(day_indices));
            end
            if isfield(signals, 'SOH') && ~isempty(signals.SOH)
                daily_soh(day) = mean(signals.SOH(day_indices)) * 100;
            end
        end
    end

    day_vector = 1:num_days;

    % Plot trends
    subplot(2, 2, 1);
    plot(day_vector, daily_avg_pv, 'g-', 'LineWidth', 1.5);
    xlabel('Day');
    ylabel('Average PV Power (kW)');
    title('Daily Average PV Generation Trend');
    grid on;

    subplot(2, 2, 2);
    plot(day_vector, daily_avg_load, 'b-', 'LineWidth', 1.5);
    xlabel('Day');
    ylabel('Average Load Power (kW)');
    title('Daily Average Load Demand Trend');
    grid on;

    subplot(2, 2, 3);
    plot(day_vector, daily_avg_soc, 'c-', 'LineWidth', 1.5);
    xlabel('Day');
    ylabel('Average SOC (%)');
    title('Daily Average SOC Trend');
    grid on;
    ylim([0 100]);

    subplot(2, 2, 4);
    if any(daily_soh > 0)
        plot(day_vector, daily_soh, 'k-', 'LineWidth', 1.5);
        xlabel('Day');
        ylabel('SOH (%)');
        title('SOH Degradation Trend');
        grid on;

        % Add trend line
        if length(day_vector) > 2
            p = polyfit(day_vector, daily_soh, 1);
            trend_line = polyval(p, day_vector);
            hold on;
            plot(day_vector, trend_line, 'r--', 'LineWidth', 1, 'Alpha', 0.7);
            hold off;

            % Add degradation rate
            degradation_rate = -p(1);
            legend({'SOH', sprintf('Trend (%.6f%%/day)', degradation_rate)}, 'Location', 'best');
        end
    end

    sgtitle('Long-term Trends Analysis', 'FontSize', 16, 'FontWeight', 'bold');
end

function plot_file = savePlot(fig_handle, plot_type, plot_config)
    % Save plot to file

    % Generate filename
    timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    filename = sprintf('%s_%s', plot_type, timestamp);
    plot_file = fullfile(plot_config.output_dir, [filename '.' plot_config.format]);

    try
        % Set figure properties for saving
        set(fig_handle, 'PaperPositionMode', 'auto');
        set(fig_handle, 'PaperUnits', 'inches');
        set(fig_handle, 'PaperPosition', [0 0 12 8]);

        % Save based on format
        switch lower(plot_config.format)
            case 'png'
                print(fig_handle, plot_file, '-dpng', sprintf('-r%d', plot_config.resolution));
            case 'pdf'
                print(fig_handle, plot_file, '-dpdf', '-bestfit');
            case 'svg'
                print(fig_handle, plot_file, '-dsvg');
            case 'eps'
                print(fig_handle, plot_file, '-depsc');
            case 'fig'
                savefig(fig_handle, plot_file);
            otherwise
                % Default to PNG
                print(fig_handle, plot_file, '-dpng', sprintf('-r%d', plot_config.resolution));
        end

        % Also save as .fig for future editing
        if ~strcmpi(plot_config.format, 'fig')
            fig_file = fullfile(plot_config.output_dir, [filename '.fig']);
            savefig(fig_handle, fig_file);
        end

    catch ME
        warning('Could not save plot %s: %s', plot_type, ME.message);
        plot_file = '';
    end
end

function displayPlottingResults(plot_results)
    % Display plotting results summary

    fprintf('=========================================================================\n');
    fprintf('                    PLOTTING RESULTS SUMMARY\n');
    fprintf('=========================================================================\n');

    fprintf('Generated Plots: %d\n', length(plot_results.generated_plots));
    if ~isempty(plot_results.generated_plots)
        for i = 1:length(plot_results.generated_plots)
            fprintf('  ? %s\n', plot_results.generated_plots{i});
        end
    end

    if ~isempty(plot_results.failed_plots)
        fprintf('\nFailed Plots: %d\n', length(plot_results.failed_plots));
        for i = 1:length(plot_results.failed_plots)
            fprintf('  ? %s: %s\n', plot_results.failed_plots{i}.type, ...
                    plot_results.failed_plots{i}.error);
        end
    end

    if ~isempty(plot_results.plot_files)
        fprintf('\nSaved Files:\n');
        for i = 1:length(plot_results.plot_files)
            if ~isempty(plot_results.plot_files{i})
                fprintf('  ? %s\n', plot_results.plot_files{i});
            end
        end
    end

    fprintf('=========================================================================\n');
end

function handlePlottingError(ME, params)
    % Handle plotting system errors

    fprintf('\nERROR: Plotting system failed\n');
    fprintf('Error: %s\n', ME.message);

    % Save error log
    if exist(params.output_dir, 'dir')
        error_file = fullfile(params.output_dir, 'plotting_error.log');
        try
            fid = fopen(error_file, 'w');
            if fid > 0
                fprintf(fid, 'Plotting Error Log\n');
                fprintf(fid, '==================\n');
                fprintf(fid, 'Timestamp: %s\n', string(datetime('now')));
                fprintf(fid, 'Error ID: %s\n', ME.identifier);
                fprintf(fid, 'Error Message: %s\n', ME.message);
                fprintf(fid, '\nStack Trace:\n');
                for i = 1:length(ME.stack)
                    fprintf(fid, '  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
                end
                fclose(fid);
                fprintf('Error log saved to: %s\n', error_file);
            end
        catch
            fprintf('Could not save error log\n');
        end
    end
end

% =========================================================================
%                           UTILITY FUNCTIONS
% =========================================================================

function integrated_plotting(simulation_results, varargin)
    % Integrated plotting function for use within simulation scripts
    %
    % Usage:
    %   integrated_plotting(simulation_results, 'plot_types', {'power_balance', 'soc_price'});
    %   integrated_plotting(simulation_results, 'theme', 'publication', 'format', 'pdf');

    % Parse additional arguments
    p = inputParser;
    addParameter(p, 'plot_types', 'all');
    addParameter(p, 'output_dir', 'integrated_plots');
    addParameter(p, 'theme', 'default');
    addParameter(p, 'format', 'png');
    addParameter(p, 'resolution', 300);
    addParameter(p, 'save_plots', true);
    addParameter(p, 'show_plots', false); % Default to not showing for integration
    addParameter(p, 'verbose', false);
    parse(p, varargin{:});

    % Call main plotting system
    try
        plot_results = modular_plotting_system('data_struct', simulation_results, ...
                                              'plot_types', p.Results.plot_types, ...
                                              'output_dir', p.Results.output_dir, ...
                                              'theme', p.Results.theme, ...
                                              'format', p.Results.format, ...
                                              'resolution', p.Results.resolution, ...
                                              'save_plots', p.Results.save_plots, ...
                                              'show_plots', p.Results.show_plots, ...
                                              'verbose', p.Results.verbose);

        if p.Results.verbose
            fprintf('>> Integrated plotting completed successfully\n');
        end

    catch ME
        if p.Results.verbose
            fprintf('>> Warning: Integrated plotting failed: %s\n', ME.message);
        end
    end
end

function batch_plotting(data_files, varargin)
    % Batch plotting function for multiple data files
    %
    % Usage:
    %   batch_plotting({'file1.mat', 'file2.mat'}, 'plot_types', 'power_balance');

    % Parse arguments
    p = inputParser;
    addParameter(p, 'plot_types', 'all');
    addParameter(p, 'output_dir', 'batch_plots');
    addParameter(p, 'theme', 'default');
    addParameter(p, 'format', 'png');
    addParameter(p, 'resolution', 300);
    addParameter(p, 'save_plots', true);
    addParameter(p, 'show_plots', false);
    addParameter(p, 'verbose', true);
    parse(p, varargin{:});

    fprintf('Starting batch plotting for %d files...\n', length(data_files));

    % Process each file
    for i = 1:length(data_files)
        data_file = data_files{i};

        if p.Results.verbose
            fprintf('Processing file %d/%d: %s\n', i, length(data_files), data_file);
        end

        try
            % Create subdirectory for this file
            [~, filename, ~] = fileparts(data_file);
            file_output_dir = fullfile(p.Results.output_dir, filename);

            % Generate plots
            modular_plotting_system('data_file', data_file, ...
                                   'plot_types', p.Results.plot_types, ...
                                   'output_dir', file_output_dir, ...
                                   'theme', p.Results.theme, ...
                                   'format', p.Results.format, ...
                                   'resolution', p.Results.resolution, ...
                                   'save_plots', p.Results.save_plots, ...
                                   'show_plots', p.Results.show_plots, ...
                                   'verbose', false);

        catch ME
            if p.Results.verbose
                fprintf('  Warning: Failed to process %s: %s\n', data_file, ME.message);
            end
        end
    end

    fprintf('Batch plotting completed.\n');
end

function fig_handle = custom_plot_template(data, ~)
    % Template for creating custom plot types
    % Copy and modify this function to create new plot types

    fig_handle = figure('Name', 'Custom Plot', 'NumberTitle', 'off', ...
                       'Position', [100 100 800 600]);

    % Extract data
    if isfield(data, 'signals') && isfield(data, 'time_days')
        signals = data.signals;
        time_days = data.time_days;

        % Create your custom plot here
        % Example:
        if isfield(signals, 'P_pv')
            plot(time_days, signals.P_pv / 1000, 'g-', 'LineWidth', 1.5);
            xlabel('Time (days)');
            ylabel('PV Power (kW)');
            title('Custom PV Plot');
            grid on;
        end
    else
        text(0.5, 0.5, 'Data not available for custom plot', ...
             'HorizontalAlignment', 'center', 'Units', 'normalized');
    end

    % Return figure handle (required)
    % fig_handle is automatically returned
end
