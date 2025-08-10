function results = evaluate_trained_agent(varargin)
% EVALUATE_TRAINED_AGENT - Evaluate a trained microgrid agent
% 评估训练好的微电网智能体
%
% This script loads a trained agent and evaluates its performance
% on the microgrid simulation environment.
%
% Optional inputs:
%   'AgentFile' - Path to trained agent .mat file (default: latest)
%   'Algorithm' - Algorithm type: 'ddpg', 'td3', 'sac' (default: 'ddpg')
%   'SimulationDays' - Number of days to simulate (default: 7)
%   'PlotResults' - Generate plots (default: true)
%
% Outputs:
%   results - Evaluation results structure
%
% Author: Microgrid DRL Team
% Date: 2025-01-XX

%% === Parse Input Arguments ===
p = inputParser;
addParameter(p, 'AgentFile', '', @ischar);
addParameter(p, 'Algorithm', 'ddpg', @(x) ismember(x, {'ddpg', 'td3', 'sac'}));
addParameter(p, 'SimulationDays', 7, @(x) isnumeric(x) && x > 0);
addParameter(p, 'PlotResults', true, @islogical);
parse(p, varargin{:});

agent_file = p.Results.AgentFile;
algorithm = p.Results.Algorithm;
simulation_days = p.Results.SimulationDays;
plot_results = p.Results.PlotResults;

%% === Initialize ===
fprintf('=== Trained Agent Evaluation ===\n');
fprintf('Time: %s\n', char(datetime('now')));

% Clear workspace and close figures
close all;

%% === Step 1: Load Trained Agent ===
fprintf('\n--- Step 1: Loading Trained Agent ---\n');

if isempty(agent_file)
    % Use latest agent file
    agent_file = sprintf('models/%s/latest_%s_agent.mat', algorithm, algorithm);
end

try
    if ~exist(agent_file, 'file')
        error('Agent file not found: %s', agent_file);
    end
    
    loaded_data = load(agent_file);
    agent = loaded_data.agent;
    model_cfg = loaded_data.model_cfg;
    training_cfg = loaded_data.training_cfg;
    
    fprintf('? Agent loaded from: %s\n', agent_file);
    fprintf('? Algorithm: %s\n', upper(algorithm));
    
catch ME
    error('Failed to load agent: %s', ME.message);
end

%% === Step 2: Generate Evaluation Data ===
fprintf('\n--- Step 2: Generating Evaluation Data ---\n');

try
    % Override simulation days in config
    model_config.simulation.simulation_days = simulation_days;
    
    % Generate fresh data for evaluation
    [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(model_config, ...
        'SimulationDays', simulation_days, ...
        'Season', 'mixed', ...
        'WeatherPattern', 'mixed');
    
    % Assign to base workspace for Simulink
    assignin('base', 'pv_profile', pv_profile);
    assignin('base', 'load_profile', load_profile);
    assignin('base', 'price_profile', price_profile);
    
    fprintf('? Evaluation data generated (%d days)\n', simulation_days);
    
catch ME
    error('Failed to generate evaluation data: %s', ME.message);
end

%% === Step 3: Create Environment ===
fprintf('\n--- Step 3: Creating Evaluation Environment ---\n');

try
    % Create environment for evaluation
    env = create_simulink_environment(model_config, 'ValidationMode', true);
    fprintf('? Evaluation environment created\n');
    
catch ME
    error('Failed to create evaluation environment: %s', ME.message);
end

%% === Step 4: Run Simulation ===
fprintf('\n--- Step 4: Running Simulation ---\n');

try
    % Configure simulation options
    max_steps = simulation_days * 24; % One step per hour
    sim_options = rlSimulationOptions('MaxSteps', max_steps);
    
    fprintf('Running simulation with trained agent...\n');
    fprintf('Max steps: %d (%.1f days)\n', max_steps, max_steps/24);
    
    % Run simulation
    tic;
    experience = sim(env, agent, sim_options);
    sim_time = toc;
    
    fprintf('? Simulation completed in %.2f seconds\n', sim_time);
    fprintf('? Total steps: %d\n', length(experience.Reward));
    
catch ME
    error('Simulation failed: %s', ME.message);
end

%% === Step 5: Extract and Analyze Results ===
fprintf('\n--- Step 5: Analyzing Results ---\n');

try
    % Extract data from experience
    observations = experience.Observation.obs1.Data;
    actions = experience.Action.act1.Data;
    rewards = experience.Reward.Data;
    
    % Parse observations (assuming order: PV, Load, SOC, SOH, Price, Hour, Day)
    pv_power = observations(:, 1);
    load_power = observations(:, 2);
    soc = observations(:, 3);
    soh = observations(:, 4);
    electricity_price = observations(:, 5);
    
    % Actions (battery power)
    battery_power = actions;
    
    % Calculate grid power
    grid_power = load_power - pv_power - battery_power;
    
    % Calculate performance metrics
    total_reward = sum(rewards);
    avg_reward = mean(rewards);
    total_cost = -sum(grid_power .* electricity_price) / 1000; % Convert to currency units
    
    % SOC statistics
    soc_min = min(soc);
    soc_max = max(soc);
    soc_avg = mean(soc);
    
    % SOH degradation
    soh_initial = soh(1);
    soh_final = soh(end);
    soh_degradation = soh_initial - soh_final;
    
    % Create results structure
    results = struct();
    results.simulation_days = simulation_days;
    results.total_steps = length(rewards);
    results.total_reward = total_reward;
    results.avg_reward = avg_reward;
    results.total_cost = total_cost;
    results.soc_min = soc_min;
    results.soc_max = soc_max;
    results.soc_avg = soc_avg;
    results.soh_initial = soh_initial;
    results.soh_final = soh_final;
    results.soh_degradation = soh_degradation;
    results.time_series.pv_power = pv_power;
    results.time_series.load_power = load_power;
    results.time_series.battery_power = battery_power;
    results.time_series.grid_power = grid_power;
    results.time_series.soc = soc;
    results.time_series.soh = soh;
    results.time_series.rewards = rewards;
    results.time_series.price = electricity_price;
    
    fprintf('? Results analyzed\n');
    
catch ME
    error('Failed to analyze results: %s', ME.message);
end

%% === Step 6: Display Summary ===
fprintf('\n=== Evaluation Summary ===\n');
fprintf('Simulation period: %.1f days\n', simulation_days);
fprintf('Total reward: %.2f\n', total_reward);
fprintf('Average reward: %.2f\n', avg_reward);
fprintf('Total electricity cost: %.2f\n', total_cost);
fprintf('SOC range: %.1f%% - %.1f%% (avg: %.1f%%)\n', soc_min, soc_max, soc_avg);
fprintf('SOH degradation: %.4f (%.2f%%)\n', soh_degradation, soh_degradation*100);

%% === Step 7: Generate Plots ===
if plot_results
    fprintf('\n--- Step 7: Generating Plots ---\n');
    
    try
        % Create time vector (hours)
        time_hours = (0:length(rewards)-1)';
        
        % Create figure with subplots
        figure('Name', 'Agent Evaluation Results', 'Position', [100, 100, 1200, 800]);
        
        % Plot 1: Power flows
        subplot(2, 3, 1);
        plot(time_hours, pv_power, 'g-', 'LineWidth', 1.5); hold on;
        plot(time_hours, load_power, 'r-', 'LineWidth', 1.5);
        plot(time_hours, battery_power, 'b-', 'LineWidth', 1.5);
        plot(time_hours, grid_power, 'k--', 'LineWidth', 1);
        xlabel('Time (hours)');
        ylabel('Power (kW)');
        title('Power Flows');
        legend('PV', 'Load', 'Battery', 'Grid', 'Location', 'best');
        grid on;
        
        % Plot 2: SOC and SOH
        subplot(2, 3, 2);
        yyaxis left;
        plot(time_hours, soc, 'b-', 'LineWidth', 2);
        ylabel('SOC (%)');
        yyaxis right;
        plot(time_hours, soh, 'r-', 'LineWidth', 2);
        ylabel('SOH (p.u.)');
        xlabel('Time (hours)');
        title('Battery State');
        grid on;
        
        % Plot 3: Rewards
        subplot(2, 3, 3);
        plot(time_hours, rewards, 'k-', 'LineWidth', 1);
        xlabel('Time (hours)');
        ylabel('Reward');
        title('Instantaneous Rewards');
        grid on;
        
        % Plot 4: Cumulative reward
        subplot(2, 3, 4);
        plot(time_hours, cumsum(rewards), 'b-', 'LineWidth', 2);
        xlabel('Time (hours)');
        ylabel('Cumulative Reward');
        title('Cumulative Rewards');
        grid on;
        
        % Plot 5: Electricity price and battery action
        subplot(2, 3, 5);
        yyaxis left;
        plot(time_hours, electricity_price, 'g-', 'LineWidth', 1.5);
        ylabel('Price ($/kWh)');
        yyaxis right;
        plot(time_hours, battery_power, 'b-', 'LineWidth', 1.5);
        ylabel('Battery Power (kW)');
        xlabel('Time (hours)');
        title('Price vs Battery Action');
        grid on;
        
        % Plot 6: SOC histogram
        subplot(2, 3, 6);
        histogram(soc, 20, 'FaceColor', 'blue', 'Alpha', 0.7);
        xlabel('SOC (%)');
        ylabel('Frequency');
        title('SOC Distribution');
        grid on;
        
        sgtitle(sprintf('%s Agent Evaluation - %d Days', upper(algorithm), simulation_days));
        
        fprintf('? Plots generated\n');
        
    catch ME
        warning(ME.identifier, '%s', ME.message);
    end
end

fprintf('\n=== Evaluation Completed ===\n');

end
