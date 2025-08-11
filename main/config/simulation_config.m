function config = simulation_config(config_name)
% SIMULATION_CONFIG - Unified configuration system for microgrid DRL training
%
% This function provides centralized configuration management for all
% simulation parameters, eliminating hardcoded values throughout the system.
%
% Usage:
%   config = simulation_config()                    % Default configuration
%   config = simulation_config('quick')            % Quick test configuration
%   config = simulation_config('research')         % Research configuration
%   config = simulation_config('comparison')       % Algorithm comparison
%
% Configuration Categories:
% - Simulation parameters (days, time steps, episodes)
% - Physical system parameters (battery, PV, grid)
% - Training parameters (algorithms, optimization)
% - Data generation parameters (weather, load patterns)
% - Hardware parameters (GPU/CPU, memory)

if nargin < 1
    config_name = 'default';
end

%% Base Configuration Structure
config = struct();

%% Simulation Parameters
switch lower(config_name)
    case 'quick'
        % Quick test configuration (5-10 minutes)
        config.simulation.days = 1;
        config.simulation.episodes = 5;
        config.simulation.time_step_hours = 1;
        config.simulation.max_steps_per_episode = 24;
        
    case 'research'
        % Research-grade configuration (2-4 hours)
        config.simulation.days = 30;
        config.simulation.episodes = 100;
        config.simulation.time_step_hours = 1;
        config.simulation.max_steps_per_episode = 720; % 30 days * 24 hours
        
    case 'comparison'
        % Algorithm comparison configuration (6-12 hours)
        config.simulation.days = 30;
        config.simulation.episodes = 200;
        config.simulation.time_step_hours = 1;
        config.simulation.max_steps_per_episode = 720;
        
    case 'extended'
        % Extended research configuration (1-2 days)
        config.simulation.days = 90;
        config.simulation.episodes = 500;
        config.simulation.time_step_hours = 1;
        config.simulation.max_steps_per_episode = 2160; % 90 days * 24 hours
        
    otherwise % 'default'
        % Default balanced configuration (30-60 minutes)
        config.simulation.days = 7;
        config.simulation.episodes = 50;
        config.simulation.time_step_hours = 1;
        config.simulation.max_steps_per_episode = 168; % 7 days * 24 hours
end

%% Physical System Parameters (Realistic Microgrid Specifications)
% Battery Energy Storage System (BESS) - Based on Tesla Megapack specifications
config.system.battery.capacity_kwh = 100;          % Battery capacity in kWh (realistic for small microgrid)
config.system.battery.power_kw = 50;               % Battery power rating in kW (0.5C rate, realistic)
config.system.battery.efficiency = 0.95;           % Round-trip efficiency (realistic Li-ion)
config.system.battery.initial_soc = 0.5;           % Initial state of charge (50%)
config.system.battery.soc_min = 0.15;              % Minimum SOC limit (15% for battery health)
config.system.battery.soc_max = 0.85;              % Maximum SOC limit (85% for battery health)
config.system.battery.initial_soh = 1.0;           % Initial state of health (100%)
config.system.battery.degradation_rate = 0.0001;   % Daily degradation rate (realistic aging)
config.system.battery.temperature_coeff = -0.005;  % Temperature coefficient (%/??C)

% Photovoltaic System - Based on commercial solar installations
config.system.pv.capacity_kw = 120;                % PV system capacity in kW (1.2x battery for realistic ratio)
config.system.pv.efficiency = 0.22;                % PV panel efficiency (modern monocrystalline)
config.system.pv.temperature_coeff = -0.004;       % Temperature coefficient (%/??C)
config.system.pv.irradiance_threshold = 50;        % Minimum irradiance for operation (W/m?)

% Grid Connection - Based on typical distribution network limits
config.system.grid.connection_limit_kw = 200;      % Grid connection limit (realistic for small microgrid)
config.system.grid.import_limit_kw = 150;          % Maximum import power (75% of connection)
config.system.grid.export_limit_kw = 100;          % Maximum export power (50% of connection)
config.system.grid.voltage_nominal = 400;          % Nominal voltage (V, 3-phase)
config.system.grid.frequency_nominal = 50;         % Nominal frequency (Hz, European standard)

%% Economic Parameters (Based on Chinese Electricity Market)
config.economics.electricity_price_base = 0.65;    % Base electricity price (CNY/kWh, realistic)
config.economics.peak_price_multiplier = 1.8;      % Peak hour price multiplier (8-11am, 6-9pm)
config.economics.valley_price_multiplier = 0.4;    % Valley hour price multiplier (11pm-7am)
config.economics.feed_in_tariff = 0.35;            % Feed-in tariff for PV export (CNY/kWh)
config.economics.battery_degradation_cost = 0.08;  % Battery degradation cost (CNY/kWh, realistic)
config.economics.grid_connection_cost = 0.02;      % Grid connection cost (CNY/kWh, reduced)
config.economics.demand_charge = 45;               % Demand charge (CNY/kW/month, realistic)
config.economics.carbon_credit = 0.05;             % Carbon credit value (CNY/kWh renewable)

%% Training Parameters
config.training.algorithm = 'ddpg';                % Default algorithm: 'ddpg', 'td3', 'sac'
config.training.score_averaging_window = 20;       % Episodes for score averaging
config.training.stop_training_criteria = 'AverageReward';
config.training.stop_training_value = -5000;       % Adjusted based on simulation days
config.training.save_agent_criteria = 'EpisodeReward';
config.training.save_agent_value = -8000;          % Adjusted based on simulation days

% Adjust training criteria based on simulation length
reward_scale_factor = config.simulation.days / 30; % Scale relative to 30-day baseline
config.training.stop_training_value = config.training.stop_training_value * reward_scale_factor;
config.training.save_agent_value = config.training.save_agent_value * reward_scale_factor;

%% Network Architecture Parameters
config.network.actor_layers = [128, 64];           % Actor network layers
config.network.critic_layers = [128, 64];          % Critic network layers
config.network.actor_learning_rate = 1e-4;         % Actor learning rate
config.network.critic_learning_rate = 1e-3;        % Critic learning rate
config.network.batch_size = 128;                   % Training batch size
config.network.buffer_size = 1e6;                  % Experience buffer size
config.network.target_smooth_factor = 1e-3;        % Target network update rate

%% Hardware Configuration
config.hardware.use_gpu = gpuDeviceCount > 0;      % Auto-detect GPU
config.hardware.parallel_workers = 0;              % Number of parallel workers (0 = auto)
config.hardware.memory_fraction = 0.8;             % GPU memory fraction to use

% Adjust network size based on hardware
if ~config.hardware.use_gpu
    % Smaller networks for CPU training
    config.network.actor_layers = [64, 32];
    config.network.critic_layers = [64, 32];
    config.network.batch_size = 64;
    config.network.buffer_size = 5e5;
end

%% Data Generation Parameters (Enhanced Physical Realism)
config.data.weather_pattern = 'seasonal';          % Realistic seasonal weather patterns
config.data.load_pattern = 'commercial';           % Commercial building load profile
config.data.price_pattern = 'time_of_use';         % Time-of-use pricing (realistic)
config.data.seasonal_variation = true;             % Enable seasonal variations
config.data.random_seed = 42;                      % Random seed for reproducibility
config.data.temperature_variation = true;          % Enable temperature effects
config.data.cloud_intermittency = true;            % Enable realistic cloud patterns
config.data.load_diversity_factor = 0.85;          % Load diversity factor (realistic)
config.data.pv_degradation_annual = 0.005;         % Annual PV degradation (0.5%/year)
config.data.weather_correlation = true;            % Correlate temperature, irradiance, load

%% Simulink Integration Parameters
config.simulink.use_simulink = true;               % Use Simulink model by default
config.simulink.model_name = 'Microgrid';          % Simulink model name
config.simulink.solver = 'ode45';                  % Simulink solver
config.simulink.relative_tolerance = 1e-3;         % Solver tolerance
config.simulink.absolute_tolerance = 1e-6;         % Solver tolerance
config.simulink.max_step_size = config.simulation.time_step_hours * 3600; % Max step size in seconds

%% Output and Logging Parameters
config.output.save_results = true;                 % Save training results
config.output.save_plots = true;                   % Generate and save plots
config.output.save_workspace = false;              % Save workspace variables
config.output.verbose_level = 1;                   % Verbosity level (0-3)
config.output.plot_training_progress = true;       % Show training progress plots
config.output.results_directory = 'results';       % Results directory name

%% Validation Parameters
config.validation.enable_pretraining_validation = true;    % Enable pre-training validation
config.validation.validation_episodes = 3;                 % Number of validation episodes
config.validation.validation_steps = 24;                   % Steps per validation episode

%% Configuration-specific overrides
switch lower(config_name)
    case 'quick'
        config.validation.enable_pretraining_validation = false;  % Disable for quick test
    case 'research'
        config.validation.enable_pretraining_validation = false;  % Disable for stability
end

%% Advanced Parameters
config.advanced.noise_variance = 0.01;             % Action noise variance (reduced for stability)
config.advanced.exploration_decay = 0.995;         % Exploration decay rate
config.advanced.gradient_threshold = 1.0;          % Gradient clipping threshold
config.advanced.discount_factor = 0.99;            % Reward discount factor

%% Configuration Metadata
config.meta.config_name = config_name;
config.meta.creation_time = datetime('now');
config.meta.version = '1.0';
config.meta.description = sprintf('Configuration for %s simulation', config_name);

%% Display Configuration Summary
if config.output.verbose_level > 0
    fprintf('Configuration loaded: %s\n', config_name);
    fprintf('  Simulation: %d days, %d episodes, %d hours/step\n', ...
            config.simulation.days, config.simulation.episodes, config.simulation.time_step_hours);
    fprintf('  Battery: %d kWh, %d kW\n', ...
            config.system.battery.capacity_kwh, config.system.battery.power_kw);
    if config.hardware.use_gpu
        fprintf('  Hardware: GPU\n');
    else
        fprintf('  Hardware: CPU\n');
    end
    if config.simulink.use_simulink
        fprintf('  Simulink: Enabled\n');
    else
        fprintf('  Simulink: Disabled\n');
    end
end

end
