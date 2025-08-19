function evaluation_results = evaluate_trained_agent(agent, env, evaluation_config)
% EVALUATE_TRAINED_AGENT - Evaluate trained RL agent performance
% Evaluate trained RL agent performance
%
% Inputs:
%   agent - Trained RL agent
%   env - RL environment
%   evaluation_config - Evaluation configuration structure
%
% Outputs:
%   evaluation_results - Evaluation results structure
%
% Author: Microgrid DRL Team
% Date: 2025-01-XX

fprintf('Starting agent evaluation...\n');

%% === Validate Inputs ===
% Validate inputs
assert(~isempty(agent), 'Agent cannot be empty');
assert(~isempty(env), 'Environment cannot be empty');
assert(isstruct(evaluation_config), 'evaluation_config must be a structure');

%% === Initialize Evaluation Results ===
% Initialize evaluation results
evaluation_results = struct();
evaluation_results.config = evaluation_config;
evaluation_results.timestamp = datetime('now');
evaluation_results.episodes = [];
evaluation_results.summary = struct();

%% === Run Evaluation Episodes ===
% Run evaluation episodes
fprintf('Running %d evaluation episodes...\n', evaluation_config.num_episodes);

episode_rewards = zeros(evaluation_config.num_episodes, 1);
episode_steps = zeros(evaluation_config.num_episodes, 1);
episode_data = cell(evaluation_config.num_episodes, 1);

for episode = 1:evaluation_config.num_episodes
    fprintf('  Episode %d/%d...', episode, evaluation_config.num_episodes);
    
    % Reset environment
    obs = reset(env);
    
    % Initialize episode tracking with preallocation
    episode_reward = 0;
    step_count = 0;
    max_steps = 1000; % Reasonable maximum for preallocation
    episode_observations = zeros(max_steps, length(obs));
    episode_actions = zeros(max_steps, 1);
    episode_rewards_step = zeros(max_steps, 1);
    actual_steps = 0;
    episode_done = false;
    
    % Run episode
    while ~episode_done && step_count < evaluation_config.max_steps_per_episode
        % Get action from agent
        action = getAction(agent, obs);
        
        % Take step in environment
        [next_obs, reward, is_done, ~] = step(env, action);
        
        % Store step data
        if evaluation_config.save_episode_data
            actual_steps = actual_steps + 1;
            if actual_steps <= max_steps
                episode_observations(actual_steps, :) = obs';
                episode_actions(actual_steps) = action;
                episode_rewards_step(actual_steps) = reward;
            end
        end
        
        % Update episode metrics
        episode_reward = episode_reward + reward;
        step_count = step_count + 1;
        
        % Update for next iteration
        obs = next_obs;
        episode_done = is_done;
    end
    
    % Store episode results
    episode_rewards(episode) = episode_reward;
    episode_steps(episode) = step_count;
    
    if evaluation_config.save_episode_data
        episode_data{episode} = struct(...
            'observations', episode_observations, ...
            'actions', episode_actions, ...
            'rewards', episode_rewards_step, ...
            'total_reward', episode_reward, ...
            'steps', step_count);
    end
    
    fprintf(' Reward: %.2f, Steps: %d\n', episode_reward, step_count);
end

%% === Calculate Summary Statistics ===
% Calculate summary statistics
fprintf('Calculating evaluation statistics...\n');

evaluation_results.summary.mean_reward = mean(episode_rewards);
evaluation_results.summary.std_reward = std(episode_rewards);
evaluation_results.summary.min_reward = min(episode_rewards);
evaluation_results.summary.max_reward = max(episode_rewards);
evaluation_results.summary.median_reward = median(episode_rewards);

evaluation_results.summary.mean_steps = mean(episode_steps);
evaluation_results.summary.std_steps = std(episode_steps);
evaluation_results.summary.min_steps = min(episode_steps);
evaluation_results.summary.max_steps = max(episode_steps);

evaluation_results.summary.success_rate = sum(episode_rewards > evaluation_config.success_threshold) / evaluation_config.num_episodes;

% Store raw data
evaluation_results.episode_rewards = episode_rewards;
evaluation_results.episode_steps = episode_steps;

if evaluation_config.save_episode_data
    evaluation_results.episode_data = episode_data;
end

%% === Run Detailed Simulation (if requested) ===
% Run detailed simulation for analysis
if evaluation_config.run_detailed_simulation
    fprintf('Running detailed simulation for analysis...\n');
    
    try
        % Reset environment for detailed run
        reset(env);
        
        % Configure simulation for data logging
        simIn = Simulink.SimulationInput(env.Model);
        simIn = simIn.setModelParameter('StopTime', num2str(evaluation_config.detailed_simulation_time));
        simIn = simIn.setModelParameter('ReturnWorkspaceOutputs', 'on');
        
        % Run detailed simulation
        simOut = sim(simIn);
        
        % Store simulation results
        evaluation_results.detailed_simulation = simOut;
        
        fprintf('Detailed simulation completed successfully\n');
        
    catch ME
        warning('Evaluation:DetailedSimulation', 'Detailed simulation failed: %s', ME.message);
        evaluation_results.detailed_simulation = [];
    end
end

%% === Generate Evaluation Report ===
% Generate evaluation report
fprintf('\n=== Agent Evaluation Results ===\n');
fprintf('Episodes: %d\n', evaluation_config.num_episodes);
fprintf('Mean Reward: %.2f ?? %.2f\n', evaluation_results.summary.mean_reward, evaluation_results.summary.std_reward);
fprintf('Reward Range: [%.2f, %.2f]\n', evaluation_results.summary.min_reward, evaluation_results.summary.max_reward);
fprintf('Median Reward: %.2f\n', evaluation_results.summary.median_reward);
fprintf('Mean Steps: %.1f ?? %.1f\n', evaluation_results.summary.mean_steps, evaluation_results.summary.std_steps);
fprintf('Success Rate: %.1f%% (threshold: %.2f)\n', evaluation_results.summary.success_rate * 100, evaluation_config.success_threshold);

%% === Save Results ===
% Save evaluation results
if evaluation_config.save_results
    try
        % Create results directory if it doesn't exist
        if ~exist(evaluation_config.results_directory, 'dir')
            mkdir(evaluation_config.results_directory);
        end
        
        % Generate filename with timestamp
        timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        results_filename = fullfile(evaluation_config.results_directory, ...
                                   sprintf('evaluation_results_%s.mat', timestamp));
        
        % Save results
        save(results_filename, 'evaluation_results', '-v7.3');
        
        fprintf('Evaluation results saved to: %s\n', results_filename);
        
    catch ME
        warning('Evaluation:SaveResults', 'Could not save evaluation results: %s', ME.message);
    end
end

%% === Generate Plots ===
% Generate evaluation plots
if evaluation_config.generate_plots
    try
        generateEvaluationPlots(evaluation_results, evaluation_config);
    catch ME
        warning('Evaluation:GeneratePlots', 'Could not generate evaluation plots: %s', ME.message);
    end
end

fprintf('Agent evaluation completed successfully\n');

end

function generateEvaluationPlots(evaluation_results, evaluation_config)
% Generate evaluation plots
% Generate evaluation plots

fprintf('Generating evaluation plots...\n');

% Create plots directory
plots_dir = fullfile(evaluation_config.results_directory, 'plots');
if ~exist(plots_dir, 'dir')
    mkdir(plots_dir);
end

% Episode rewards plot
fig1 = figure('Name', 'Episode Rewards', 'NumberTitle', 'off');
plot(1:length(evaluation_results.episode_rewards), evaluation_results.episode_rewards, 'b-', 'LineWidth', 1.5);
hold on;
yline(evaluation_results.summary.mean_reward, 'r--', 'Mean', 'LineWidth', 2);
yline(evaluation_config.success_threshold, 'g--', 'Success Threshold', 'LineWidth', 2);
xlabel('Episode');
ylabel('Total Reward');
title('Agent Performance - Episode Rewards');
grid on;
legend('Episode Rewards', 'Mean Reward', 'Success Threshold', 'Location', 'best');

% Save plot
saveas(fig1, fullfile(plots_dir, 'episode_rewards.png'));
close(fig1);

% Reward distribution histogram
fig2 = figure('Name', 'Reward Distribution', 'NumberTitle', 'off');
histogram(evaluation_results.episode_rewards, 20, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'none');
xlabel('Total Reward');
ylabel('Frequency');
title('Distribution of Episode Rewards');
grid on;

% Add statistics text
stats_text = sprintf('Mean: %.2f\nStd: %.2f\nMedian: %.2f', ...
                    evaluation_results.summary.mean_reward, ...
                    evaluation_results.summary.std_reward, ...
                    evaluation_results.summary.median_reward);
text(0.02, 0.98, stats_text, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
     'BackgroundColor', 'white', 'EdgeColor', 'black');

% Save plot
saveas(fig2, fullfile(plots_dir, 'reward_distribution.png'));
close(fig2);

fprintf('Evaluation plots saved to: %s\n', plots_dir);

end
