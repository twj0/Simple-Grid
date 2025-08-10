function system_test()
% SYSTEM_TEST - Comprehensive system test for microgrid DRL framework
% Test all components of the microgrid DRL framework
%
% This function performs a comprehensive test of all system components
% to ensure everything is working correctly before training.
%
% Author: Microgrid DRL Team
% Date: 2025-01-XX

fprintf('=== Microgrid DRL Framework System Test ===\n');
fprintf('Time: %s\n', string(datetime('now')));
fprintf('MATLAB Version: %s\n', version('-release'));
fprintf('========================================\n\n');

test_results = struct();
test_count = 0;
passed_count = 0;

%% Test 1: Configuration Loading
test_count = test_count + 1;
fprintf('Test %d: Configuration Loading\n', test_count);
try
    model_cfg = model_config();
    training_cfg = training_config_ddpg();
    
    % Validate essential fields
    assert(isfield(model_cfg, 'battery'), 'Model config missing battery field');
    assert(isfield(training_cfg, 'training'), 'Training config missing training field');
    
    fprintf('? PASSED: Configuration loading successful\n');
    test_results.config_loading = true;
    passed_count = passed_count + 1;
    
catch ME
    fprintf('? FAILED: Configuration loading failed: %s\n', ME.message);
    test_results.config_loading = false;
end

%% Test 2: Data Generation
test_count = test_count + 1;
fprintf('\nTest %d: Data Generation\n', test_count);
try
    % Generate test data for 1 day
    test_config = model_cfg;
    test_config.simulation.simulation_days = 1;
    
    [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(test_config);
    
    % Validate data
    assert(isa(pv_profile, 'timeseries'), 'PV profile is not a timeseries');
    assert(isa(load_profile, 'timeseries'), 'Load profile is not a timeseries');
    assert(isa(price_profile, 'timeseries'), 'Price profile is not a timeseries');
    assert(length(pv_profile.Data) == 24, 'PV profile should have 24 hours of data');
    
    fprintf('? PASSED: Data generation successful\n');
    test_results.data_generation = true;
    passed_count = passed_count + 1;
    
catch ME
    fprintf('? FAILED: Data generation failed: %s\n', ME.message);
    test_results.data_generation = false;
end

%% Test 3: Simulink Model
test_count = test_count + 1;
fprintf('\nTest %d: Simulink Model\n', test_count);
try
    % Find model files
    model_files = [dir('*.slx'); dir('*.mdl')];
    assert(~isempty(model_files), 'No Simulink model files found');
    
    model_file = model_files(1).name;
    [~, model_name, ~] = fileparts(model_file);
    
    % Load model
    if ~bdIsLoaded(model_name)
        load_system(model_name);
    end
    
    % Check for RL Agent block
    rl_blocks = find_system(model_name, 'BlockType', 'RLAgent');
    assert(~isempty(rl_blocks), 'No RL Agent blocks found in model');
    
    fprintf('? PASSED: Simulink model validation successful\n');
    fprintf('  Model: %s\n', model_file);
    fprintf('  RL Agent: %s\n', rl_blocks{1});
    test_results.simulink_model = true;
    passed_count = passed_count + 1;
    
catch ME
    fprintf('? FAILED: Simulink model validation failed: %s\n', ME.message);
    test_results.simulink_model = false;
end

%% Test 4: Environment Creation
test_count = test_count + 1;
fprintf('\nTest %d: Environment Creation\n', test_count);
try
    % Assign test data to workspace
    assignin('base', 'pv_profile', pv_profile);
    assignin('base', 'load_profile', load_profile);
    assignin('base', 'price_profile', price_profile);
    
    % Try multiple environment creation methods for compatibility
    env_created = false;
    env = [];
    obs_info = [];
    action_info = [];
    
    % Method 1: Try create_environment_with_specs
    try
        [env, obs_info, action_info] = create_environment_with_specs(model_cfg);
        fprintf('  ✓ Environment created with create_environment_with_specs\n');
        env_created = true;
    catch ME1
        fprintf('  create_environment_with_specs failed: %s\n', ME1.message);
        
        % Method 2: Try compatible environment creation
        try
            env = create_compatible_environment(model_cfg);
            [obs_info, action_info] = get_environment_specs(env);
            fprintf('  ✓ Environment created with create_compatible_environment\n');
            env_created = true;
        catch ME2
            fprintf('  create_compatible_environment failed: %s\n', ME2.message);
            
            % Method 3: Try fallback creation
            try
                env = try_fallback_environment_creation(model_cfg);
                [obs_info, action_info] = get_environment_specs(env);
                fprintf('  ✓ Environment created with fallback method\n');
                env_created = true;
            catch ME3
                fprintf('  All environment creation methods failed\n');
            end
        end
    end
    
    if env_created
        % Validate environment
        assert(~isempty(env), 'Environment is empty');
        assert(~isempty(obs_info), 'Observation info is empty');
        assert(~isempty(action_info), 'Action info is empty');
        
        fprintf('✓ PASSED: Environment creation successful\n');
        fprintf('  Observation dims: %s\n', mat2str(obs_info.Dimension));
        fprintf('  Action dims: %s\n', mat2str(action_info.Dimension));
        test_results.environment_creation = true;
        passed_count = passed_count + 1;
    else
        fprintf('❌ FAILED: All environment creation methods failed\n');
        test_results.environment_creation = false;
    end
    
catch ME
    fprintf('? FAILED: Environment creation failed: %s\n', ME.message);
    test_results.environment_creation = false;
end

%% Test 5: Agent Creation
test_count = test_count + 1;
fprintf('\nTest %d: Agent Creation\n', test_count);
try
    if test_results.environment_creation
        % Create DDPG agent
        test_training_cfg = training_cfg;
        test_training_cfg.training.max_episodes = 5;
        test_training_cfg.training.max_steps_per_episode = 10;
        
        agent = create_ddpg_agent(obs_info, action_info, test_training_cfg);
        
        % Assign agent to workspace for Simulink compatibility
        assignin('base', 'agentObj', agent);
        
        % Validate agent
        assert(~isempty(agent), 'Agent is empty');
        
        fprintf('? PASSED: Agent creation successful\n');
        test_results.agent_creation = true;
        passed_count = passed_count + 1;
    else
        fprintf('? SKIPPED: Agent creation (environment creation failed)\n');
        test_results.agent_creation = false;
    end
    
catch ME
    fprintf('? FAILED: Agent creation failed: %s\n', ME.message);
    test_results.agent_creation = false;
end

%% Test 6: Environment Reset and Step
test_count = test_count + 1;
fprintf('\nTest %d: Environment Reset and Step\n', test_count);
try
    if test_results.environment_creation
        % Test environment reset
        obs = reset(env);
        assert(~isempty(obs), 'Reset observation is empty');
        assert(length(obs) == obs_info.Dimension(1), 'Observation dimension mismatch');
        
        % Test environment step
        random_action = action_info.LowerLimit + (action_info.UpperLimit - action_info.LowerLimit) * rand();
        [next_obs, reward, is_done, info] = step(env, random_action);
        
        assert(~isempty(next_obs), 'Step observation is empty');
        assert(isnumeric(reward), 'Reward is not numeric');
        assert(islogical(is_done), 'Done flag is not logical');
        
        fprintf('? PASSED: Environment reset and step successful\n');
        fprintf('  Observation size: %s\n', mat2str(size(obs)));
        fprintf('  Reward: %.4f\n', reward);
        test_results.environment_step = true;
        passed_count = passed_count + 1;
    else
        fprintf('? SKIPPED: Environment step test (environment creation failed)\n');
        test_results.environment_step = false;
    end
    
catch ME
    fprintf('? FAILED: Environment reset/step failed: %s\n', ME.message);
    test_results.environment_step = false;
end

%% Test 7: Training Options
test_count = test_count + 1;
fprintf('\nTest %d: Training Options\n', test_count);
try
    training_options = rlTrainingOptions(...
        'MaxEpisodes', 5, ...
        'MaxStepsPerEpisode', 10, ...
        'Verbose', false, ...
        'Plots', 'none');
    
    assert(~isempty(training_options), 'Training options is empty');
    
    fprintf('? PASSED: Training options creation successful\n');
    test_results.training_options = true;
    passed_count = passed_count + 1;
    
catch ME
    fprintf('? FAILED: Training options creation failed: %s\n', ME.message);
    test_results.training_options = false;
end

%% Test 8: Mini Training Run
test_count = test_count + 1;
fprintf('\nTest %d: Mini Training Run\n', test_count);
try
    if test_results.agent_creation && test_results.environment_creation && test_results.training_options
        fprintf('Running 2-episode mini training...\n');
        
        mini_options = rlTrainingOptions(...
            'MaxEpisodes', 2, ...
            'MaxStepsPerEpisode', 5, ...
            'Verbose', false, ...
            'Plots', 'none');
        
        training_stats = train(agent, env, mini_options);
        
        assert(~isempty(training_stats), 'Training stats is empty');
        assert(isfield(training_stats, 'EpisodeReward'), 'Training stats missing EpisodeReward');
        
        fprintf('? PASSED: Mini training run successful\n');
        fprintf('  Episodes completed: %d\n', length(training_stats.EpisodeReward));
        if ~isempty(training_stats.EpisodeReward)
            fprintf('  Final reward: %.4f\n', training_stats.EpisodeReward(end));
        end
        test_results.mini_training = true;
        passed_count = passed_count + 1;
    else
        fprintf('? SKIPPED: Mini training (prerequisites failed)\n');
        test_results.mini_training = false;
    end
    
catch ME
    fprintf('? FAILED: Mini training run failed: %s\n', ME.message);
    test_results.mini_training = false;
end

%% Test Summary
fprintf('\n========================================\n');
fprintf('=== SYSTEM TEST SUMMARY ===\n');
fprintf('========================================\n');
fprintf('Total Tests: %d\n', test_count);
fprintf('Passed: %d\n', passed_count);
fprintf('Failed: %d\n', test_count - passed_count);
fprintf('Success Rate: %.1f%%\n', (passed_count / test_count) * 100);

fprintf('\nDetailed Results:\n');
test_names = fieldnames(test_results);
for i = 1:length(test_names)
    status = test_results.(test_names{i});
    if status
        fprintf('  ? %s: PASSED\n', test_names{i});
    else
        fprintf('  ? %s: FAILED\n', test_names{i});
    end
end

if passed_count == test_count
    fprintf('\n? ALL TESTS PASSED! System is ready for training.\n');
    fprintf('\nNext steps:\n');
    fprintf('1. Run quick_train_test for a quick training verification\n');
    fprintf('2. Run train_ddpg_microgrid for full training\n');
else
    fprintf('\n? SOME TESTS FAILED. Please fix the issues before training.\n');
    fprintf('\nTroubleshooting:\n');
    fprintf('1. Run complete_fix to fix common issues\n');
    fprintf('2. Check MATLAB toolbox installations\n');
    fprintf('3. Verify Simulink model structure\n');
end

fprintf('\nSystem test completed at: %s\n', string(datetime('now')));

end
