function config = load_custom_configuration()
% LOAD_CUSTOM_CONFIGURATION - User-customizable configuration for research
%
% This function allows researchers to define custom simulation parameters
% for specific research objectives while maintaining scientific rigor.
%
% USAGE:
%   config = load_custom_configuration()
%
% CUSTOMIZATION GUIDELINES:
% - Maintain physical realism in all parameters
% - Ensure time steps are appropriate for control objectives
% - Consider computational resources vs. simulation fidelity
% - Document all custom choices for reproducibility

fprintf('\n=== CUSTOM CONFIGURATION SETUP ===\n');
fprintf('Define your research-specific parameters:\n\n');

%% Interactive Parameter Definition
% Simulation Duration
fprintf('1. SIMULATION DURATION:\n');
days = input('   Enter simulation days (1-365): ');
if isempty(days) || days < 1 || days > 365
    days = 30;
    fprintf('   Using default: %d days\n', days);
end

% Training Episodes
fprintf('\n2. TRAINING EPISODES:\n');
episodes = input('   Enter number of episodes (10-1000): ');
if isempty(episodes) || episodes < 10 || episodes > 1000
    episodes = 100;
    fprintf('   Using default: %d episodes\n', episodes);
end

% Time Step
fprintf('\n3. CONTROL TIME STEP:\n');
fprintf('   Options: 0.25 (15min), 0.5 (30min), 1.0 (1hour), 2.0 (2hour)\n');
time_step = input('   Enter time step in hours: ');
if isempty(time_step) || ~ismember(time_step, [0.25, 0.5, 1.0, 2.0])
    time_step = 0.5;
    fprintf('   Using default: %.2f hours\n', time_step);
end

% Algorithm Selection
fprintf('\n4. ALGORITHM SELECTION:\n');
fprintf('   Options: ddpg, td3, sac\n');
algorithm = input('   Enter algorithm name: ', 's');
if isempty(algorithm) || ~ismember(lower(algorithm), {'ddpg', 'td3', 'sac'})
    algorithm = 'ddpg';
    fprintf('   Using default: %s\n', algorithm);
end

%% Build Configuration
config = struct();

% Simulation Parameters
config.simulation.days = days;
config.simulation.episodes = episodes;
config.simulation.time_step_hours = time_step;
config.simulation.max_steps_per_episode = 24 / time_step;  % Steps per day
config.simulation.description = sprintf('Custom %d-day study with %s algorithm', days, upper(algorithm));

% Load base physical parameters (scientifically validated)
base_config = simulation_config('research_30day');
config.system = base_config.system;
config.economics = base_config.economics;
config.simulink = base_config.simulink;
config.precision = base_config.precision;
config.output = base_config.output;
config.validation = base_config.validation;
config.advanced = base_config.advanced;

% Algorithm-specific parameters
config.training.algorithm = lower(algorithm);
switch lower(algorithm)
    case 'ddpg'
        config.network.actor_learning_rate = 1e-4;
        config.network.critic_learning_rate = 1e-3;
        config.network.batch_size = 128;
        config.advanced.noise_variance = 0.1;
    case 'td3'
        config.network.actor_learning_rate = 3e-4;
        config.network.critic_learning_rate = 3e-4;
        config.network.batch_size = 256;
        config.advanced.noise_variance = 0.1;
    case 'sac'
        config.network.actor_learning_rate = 3e-4;
        config.network.critic_learning_rate = 3e-4;
        config.network.batch_size = 256;
        config.advanced.entropy_coefficient = 0.2;
end

% Standard network architecture
config.network.actor_layers = [128, 64];
config.network.critic_layers = [128, 64];
config.network.buffer_size = 1e6;
config.network.target_smooth_factor = 1e-3;

% Hardware configuration
config.hardware.use_gpu = gpuDeviceCount > 0;
config.hardware.parallel_workers = 0;
config.hardware.memory_fraction = 0.8;

% Data generation parameters
config.data.weather_pattern = 'seasonal';
config.data.load_pattern = 'commercial';
config.data.price_pattern = 'time_of_use';
config.data.seasonal_variation = true;
config.data.random_seed = 42;
config.data.temperature_variation = true;
config.data.cloud_intermittency = true;
config.data.load_diversity_factor = 0.85;
config.data.pv_degradation_annual = 0.005;
config.data.weather_correlation = true;

% Training parameters
config.training.score_averaging_window = 20;
config.training.stop_training_criteria = 'AverageReward';
config.training.stop_training_value = -50 * (days / 30);  % Scale with duration
config.training.save_agent_criteria = 'EpisodeReward';
config.training.save_agent_value = -8000 * (days / 30);   % Scale with duration

% Metadata
config.meta.config_name = 'custom';
config.meta.creation_time = datetime('now');
config.meta.version = '1.0';
config.meta.description = config.simulation.description;

fprintf('\n=== CUSTOM CONFIGURATION SUMMARY ===\n');
fprintf('Simulation: %d days, %d episodes, %.2f hours/step\n', ...
        config.simulation.days, config.simulation.episodes, config.simulation.time_step_hours);
fprintf('Algorithm: %s\n', upper(config.training.algorithm));
fprintf('Steps per episode: %d\n', config.simulation.max_steps_per_episode);
fprintf('Estimated training time: %.1f hours\n', ...
        config.simulation.episodes * config.simulation.max_steps_per_episode * 0.001);
fprintf('Configuration ready for training.\n\n');

end
