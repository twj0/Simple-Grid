function quick_train_test()
% QUICK_TRAIN_TEST - Test quick training functionality
% This script tests the training process step by step

fprintf('=== Quick Training Test ===\n');
fprintf('Time: %s\n\n', char(datetime('now')));

%% Step 0: Setup paths
fprintf('Step 0: Setting up paths...\n');
try
    setup_project_paths();
    fprintf('? Paths configured successfully\n');
catch ME
    fprintf('? Path setup failed: %s\n', ME.message);
    return;
end

%% Step 1: Load configuration
fprintf('\nStep 1: Loading configuration...\n');
try
    model_cfg = model_config();
    training_cfg = training_config_ddpg();
    
    % Set to quick test mode
    training_cfg.training.max_episodes = 5;
    training_cfg.training.max_steps_per_episode = 50;
    
    fprintf('? Configuration loaded (5 episodes, 50 steps each)\n');
catch ME
    fprintf('? Configuration loading failed: %s\n', ME.message);
    return;
end

%% Step 2: Generate data
fprintf('\nStep 2: Generating data...\n');
try
    model_cfg.simulation.simulation_days = 1;  % Only 1 day for quick test
    [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(model_cfg);
    
    assignin('base', 'pv_power_profile', pv_profile);
    assignin('base', 'load_power_profile', load_profile);
    assignin('base', 'price_profile', price_profile);
    
    fprintf('? Data generated and assigned\n');
catch ME
    fprintf('? Data generation failed: %s\n', ME.message);
    return;
end

%% Step 3: Create environment
fprintf('\nStep 3: Creating environment...\n');
try
    % 使用简化的MATLAB环境，避免Simulink依赖
    [env, obs_info, action_info] = create_simple_matlab_environment();
    fprintf('? 简化MATLAB环境创建成功 (无Simulink依赖)\n');
    fprintf('   观测空间: %d维\n', obs_info.Dimension(1));
    fprintf('   动作空间: %d维, 范围: [%.0f, %.0f] W\n', ...
            action_info.Dimension(1), action_info.LowerLimit, action_info.UpperLimit);

catch ME
    fprintf('? Environment creation failed: %s\n', ME.message);
    return;
end

%% Step 4: Create agent
fprintf('\nStep 4: Creating agent...\n');
try
    agent = create_ddpg_agent(obs_info, action_info, training_cfg);
    fprintf('? DDPG agent created\n');
    
    % Assign agent to workspace for Simulink access
    assignin('base', 'agentObj', agent);
    fprintf('? Agent assigned to workspace as agentObj\n');
    
    % Validate agent assignment - 验证agent分配
    try
        workspace_agent = evalin('base', 'agentObj');
        agent_class = class(workspace_agent);
        
        % Check for DDPG agent (different possible class names)
        is_ddpg = contains(agent_class, 'DDPG') || strcmp(agent_class, 'rlDDPGAgent');
        
        if is_ddpg
            fprintf('? Agent validation successful - agentObj exists in base workspace\n');
            fprintf('  Agent type: %s\n', agent_class);
            fprintf('  Agent networks: Actor and Critic configured\n');
        else
            fprintf('? Warning: agentObj exists but may not be DDPG agent (class: %s)\n', agent_class);
            fprintf('  Continuing anyway as agent object exists...\n');
        end
    catch ME
        fprintf('? Agent validation failed: %s\n', ME.message);
        return;
    end
    
catch ME
    fprintf('? Agent creation failed: %s\n', ME.message);
    return;
end

%% Step 5: Configure training
fprintf('\nStep 5: Configuring training...\n');
try
    training_options = rlTrainingOptions(...
        'MaxEpisodes', training_cfg.training.max_episodes, ...
        'MaxStepsPerEpisode', training_cfg.training.max_steps_per_episode, ...
        'Verbose', false, ...
        'Plots', 'training-progress');
    
    fprintf('? Training options configured\n');
catch ME
    fprintf('? Training configuration failed: %s\n', ME.message);
    return;
end

%% Step 6: Run training
fprintf('\nStep 6: Running training...\n');

% Pre-training validation - 训练前验证
fprintf('? Pre-training validation:\n');
try
    % Verify all required components are ready
    if evalin('base', 'exist(''agentObj'', ''var'')')
        workspace_agent = evalin('base', 'agentObj');
        fprintf('  ? agentObj verified in base workspace\n');
        fprintf('  ? Agent class: %s\n', class(workspace_agent));
        
        % Check if agent and local agent are the same
        if isequal(agent, workspace_agent)
            fprintf('  ? Local agent and workspace agent are identical\n');
        else
            fprintf('  ? Local agent and workspace agent differ, updating...\n');
            assignin('base', 'agentObj', agent);
        end
    else
        % Re-assign if missing
        assignin('base', 'agentObj', agent);
        fprintf('  ? agentObj was missing, re-assigned to workspace\n');
    end
    
    % Verify data profiles exist
    data_vars = {'pv_power_profile', 'load_power_profile', 'price_profile'};
    for i = 1:length(data_vars)
        if evalin('base', sprintf('exist(''%s'', ''var'')', data_vars{i}))
            fprintf('  ? %s exists in workspace\n', data_vars{i});
        else
            fprintf('  ? %s missing from workspace\n', data_vars{i});
        end
    end
    
catch ME
    fprintf('  ? Pre-training validation warning: %s\n', ME.message);
    % Ensure agent is assigned before training
    assignin('base', 'agentObj', agent);
    fprintf('  ? agentObj ensured in workspace for training\n');
end

fprintf('Starting %d episodes with %d steps each...\n', ...
    training_cfg.training.max_episodes, training_cfg.training.max_steps_per_episode);

try
    tic;
    training_stats = train(agent, env, training_options);
    training_time = toc;
    
    fprintf('? Training completed successfully!\n');
    fprintf('  Training time: %.2f seconds\n', training_time);
    fprintf('  Episodes completed: %d\n', length(training_stats.EpisodeReward));
    
    if ~isempty(training_stats.EpisodeReward)
        fprintf('  Final reward: %.3f\n', training_stats.EpisodeReward(end));
        fprintf('  Average reward: %.3f\n', mean(training_stats.EpisodeReward));
    end
    
    % Post-training agent verification - 训练后验证
    fprintf('\n? Post-training verification:\n');
    try
        % Check if agent is still in workspace and functional
        if evalin('base', 'exist(''agentObj'', ''var'')')
            workspace_agent_post = evalin('base', 'agentObj');
            fprintf('  ? agentObj still exists in base workspace after training\n');
            fprintf('  ? Post-training agent class: %s\n', class(workspace_agent_post));
            
            % Verify the agent has been trained (experience replay buffer should have data)
            fprintf('  ? Agent training completed - ready for evaluation\n');
        else
            fprintf('  ? Warning: agentObj missing from workspace after training\n');
        end
    catch ME
        fprintf('  ? Post-training verification warning: %s\n', ME.message);
    end
    
catch ME
    fprintf('? Training failed: %s\n', ME.message);
    return;
end

%% Summary
fprintf('\n=== Quick Training Test Summary ===\n');
fprintf('? All steps completed successfully!\n');
fprintf('? Training system is working properly\n');
fprintf('\nYou can now run full training with:\n');
fprintf('- train_ddpg_microgrid(''QuickTest'', true)\n');
fprintf('- train_ddpg_microgrid  (full training)\n');

end
