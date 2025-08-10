function [agent, training_stats] = train_sac_microgrid(varargin)
% TRAIN_SAC_MICROGRID - Main training script for SAC microgrid agent
% ?????SAC??????????????
%
% This script performs the complete training workflow for SAC algorithm:
% 1. Load configuration and data
% 2. Create Simulink environment
% 3. Create SAC agent
% 4. Execute training
% 5. Save results
%
% Optional inputs:
%   'QuickTest' - Run with reduced episodes for testing (default: false)
%   'Episodes' - Override number of training episodes
%   'SaveResults' - Save training results (default: true)
%
% Outputs:
%   agent - Trained SAC agent
%   training_stats - Training statistics
%
% Author: Microgrid DRL Team
% Date: 2025-01-XX

%% === Parse Input Arguments ===
p = inputParser;
addParameter(p, 'QuickTest', false, @islogical);
addParameter(p, 'Episodes', [], @(x) isempty(x) || (isnumeric(x) && x > 0));
addParameter(p, 'SaveResults', true, @islogical);
parse(p, varargin{:});

quick_test = p.Results.QuickTest;
custom_episodes = p.Results.Episodes;
save_results = p.Results.SaveResults;

%% === Initialize ===
fprintf('=== SAC Microgrid Training Started ===\n');
fprintf('Time: %s\n', char(datetime('now')));

% Clear workspace and close figures
close all;

% Start timer
tic;

%% === Step 1: Load Configuration ===
fprintf('\n--- Step 1: Loading Configuration ---\n');
try
    % Load model configuration
    model_cfg = model_config();
    fprintf('? Model configuration loaded\n');

    % Load training configuration
    training_cfg = training_config_sac();
    fprintf('? SAC training configuration loaded\n');
    
    % Override episodes if specified
    if ~isempty(custom_episodes)
        training_cfg.training.max_episodes = custom_episodes;
        fprintf('? Episodes overridden to: %d\n', custom_episodes);
    end

    % Quick test mode
    if quick_test
        training_cfg.training.max_episodes = 10;
        training_cfg.training.max_steps_per_episode = 100;
        fprintf('? Quick test mode enabled (10 episodes, 100 steps)\n');
    end
    
catch ME
    error('Failed to load configuration: %s', ME.message);
end

%% === Step 2: Generate Training Data ===
fprintf('\n--- Step 2: Generating Training Data ---\n');
try
    % Generate microgrid profiles
    [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(model_config);
    fprintf('? Microgrid profiles generated\n');
    
    % Assign to base workspace for Simulink
    assignin('base', 'pv_profile', pv_profile);
    assignin('base', 'load_profile', load_profile);
    assignin('base', 'price_profile', price_profile);
    fprintf('? Data assigned to workspace\n');
    
catch ME
    error('Failed to generate training data: %s', ME.message);
end

%% === Step 3: Create MATLAB Environment ===
fprintf('\n--- Step 3: Creating MATLAB Environment ---\n');
try
    % ??จน??MATLAB??????????Simulink????
    [env, obs_info, action_info] = create_simple_matlab_environment();

    fprintf('? ??MATLAB??????????? (??Simulink????)\n');
    fprintf('   ?????: %d?\n', obs_info.Dimension(1));
    fprintf('   ???????: %d?, ??ฆถ: [%.0f, %.0f] W\n', ...
            action_info.Dimension(1), action_info.LowerLimit, action_info.UpperLimit);

catch ME
    error('Failed to create MATLAB environment: %s', ME.message);
end

%% === Step 4: Create SAC Agent ===
fprintf('\n--- Step 4: Creating SAC Agent ---\n');
try
    % Create SAC agent
    agent = create_sac_agent(obs_info, action_info, training_cfg);
    fprintf('? SAC agent created successfully\n');
    
catch ME
    error('Failed to create SAC agent: %s', ME.message);
end

%% === Step 5: Configure Training Options ===
fprintf('\n--- Step 5: Configuring Training Options ---\n');
try
    % Create training options
    training_options = rlTrainingOptions(...
        'MaxEpisodes', training_config.training.max_episodes, ...
        'MaxStepsPerEpisode', training_config.training.max_steps_per_episode, ...
        'ScoreAveragingWindow', training_config.training.score_averaging_window, ...
        'Verbose', training_config.options.verbose, ...
        'Plots', training_config.options.plots, ...
        'StopTrainingCriteria', training_config.training.stop_training_criteria, ...
        'StopTrainingValue', training_config.training.stop_training_value, ...
        'SaveAgentCriteria', training_config.training.save_agent_criteria, ...
        'SaveAgentValue', training_config.training.save_agent_value);
    
    fprintf('? Training options configured\n');
    fprintf('  Max Episodes: %d\n', training_config.training.max_episodes);
    fprintf('  Max Steps per Episode: %d\n', training_config.training.max_steps_per_episode);
    fprintf('  Stop Training Value: %.1f\n', training_config.training.stop_training_value);
    
catch ME
    error('Failed to configure training options: %s', ME.message);
end

%% === Step 6: Execute Training ===
fprintf('\n--- Step 6: Starting Training ---\n');
fprintf('This may take a while... Training progress will be displayed.\n');

try
    % Start training
    training_stats = train(agent, env, training_options);
    
    training_time = toc;
    fprintf('\n? Training completed successfully!\n');
    fprintf('  Total training time: %.2f minutes\n', training_time/60);
    
catch ME
    error('Training failed: %s', ME.message);
end

%% === Step 7: Save Results ===
if save_results
    fprintf('\n--- Step 7: Saving Results ---\n');
    try
        % Create save directory if it doesn't exist
        save_dir = 'models/sac/';
        if ~exist(save_dir, 'dir')
            mkdir(save_dir);
        end
        
        % Generate filename with timestamp
        timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        filename = sprintf('%strained_sac_agent_%s.mat', save_dir, timestamp);
        
        % Save agent and training stats
        save(filename, 'agent', 'training_stats', 'model_config', 'training_config');
        
        fprintf('? Results saved to: %s\n', filename);
        
        % Also save as latest
        latest_filename = sprintf('%slatest_sac_agent.mat', save_dir);
        save(latest_filename, 'agent', 'training_stats', 'model_config', 'training_config');
        fprintf('? Latest agent saved to: %s\n', latest_filename);
        
    catch ME
        warning(ME.identifier, '%s', ME.message);
    end
end

%% === Summary ===
fprintf('\n=== Training Summary ===\n');
fprintf('Algorithm: SAC\n');
fprintf('Episodes completed: %d\n', length(training_stats.EpisodeReward));
fprintf('Final episode reward: %.2f\n', training_stats.EpisodeReward(end));
fprintf('Average reward (last 50): %.2f\n', mean(training_stats.EpisodeReward(max(1,end-49):end)));
fprintf('Training time: %.2f minutes\n', training_time/60);

if save_results
    fprintf('\nNext steps:\n');
    fprintf('1. Run: evaluate_trained_agent to test the agent\n');
    fprintf('2. Check training plots for convergence\n');
    fprintf('3. Analyze results in the saved .mat file\n');
end

fprintf('\n=== SAC Training Completed ===\n');

end
