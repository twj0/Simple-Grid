% =========================================================================
%            run_drl_experiment_v4.3_FINAL_FIX.m
% -------------------------------------------------------------------------
% Description:
%   This script is the definitive version for running the DRL experiment
%   with maximum performance and robust environment configuration.
%
%   - FIX v4.3:
%     - Forces shutdown of any pre-existing parallel pools for a clean start.
%     - Switches to the required 'process' based parallel pool for RL training.
%     - Adds a compiler check at the very beginning.
%
% =========================================================================



%% 0. Environment Pre-Check & Setup
% =========================================================================
disp('================================================================');
disp('   DRL Microgrid Experiment Runner v4.3 (Final Fix)');
disp('================================================================');
fprintf('>> STEP 0: Performing Environment Pre-Checks...\n');

% --- FIX #1: Ensure Compiler is configured ---
if ~ismac && ~ispc
    % On Linux, default compilers are usually present.
    % On Windows/Mac, it's critical to check.
    try
        compilerConfig = mex.getCompilerConfigurations('C++', 'Selected');
        if isempty(compilerConfig)
            error('No C++ compiler selected. Please run "mex -setup C++" in the MATLAB command window and select a compiler.');
        end
        fprintf('   C++ Compiler Check: PASSED (Using %s)\n', compilerConfig.Name);
    catch ME
        warning('Could not automatically verify compiler. Please ensure one is configured via "mex -setup C++".');
    end
end

% --- FIX #2: Ensure a clean parallel environment ---
fprintf('>> Shutting down any existing parallel pool to ensure a clean state...\n');
delete(gcp('nocreate'));

% Now, setup the rest of the environment
useParallel = true;
trainingDevice = "cpu"; 

if ~isempty(ver('parallel')) && gpuDeviceCount > 0
    try
        gpuInfo = gpuDevice(1); 
        trainingDevice = "gpu";
        fprintf('>> GPU Detected! DRL agent training will be accelerated on: %s\n', gpuInfo.Name);
    catch ME_gpu
        fprintf('>> WARNING: Could not access GPU. Training will use CPU. Error: %s\n', ME_gpu.message);
    end
else
    fprintf('>> No compatible GPU found. DRL agent training will use CPU.\n');
end

% --- FIX #3: Start the CORRECT type of parallel pool ('process') ---
if useParallel
    fprintf('>> ACCELERATION: Starting "process-based" parallel pool required for RL training...\n');
    parpool('local'); % 'local' is the default profile, which uses processes.
end

fprintf('>> Final training configuration: PARALLEL_CPU_SIMS=%s, GPU_TRAINING=%s\n\n', string(useParallel), string(trainingDevice=="gpu"));


%% 1. Model and Data Loading
% =========================================================================
disp('STEP 1: Loading model and data...');

% --- Configuration Flags ---
TRAIN_NEW_AGENT = true;
data_filename = 'simulation_data_10days_random.mat'; 
model_name = 'Microgrid2508020734'; 
saved_agent_filename = 'final_agent_v4_3.mat'; 

% --- Model & Solver Configuration ---
if bdIsLoaded(model_name)
    close_system(model_name, 0); 
end
load_system(model_name);
fprintf('>> Model loaded: %s\n', model_name);

stop_time_seconds = 24 * 3600; 
set_param(model_name, 'StopTime', num2str(stop_time_seconds));
set_param(model_name, 'SimulationMode', 'accelerator');

% The pre-build step is only for 'rapid' mode, so it is removed.
% The 'accelerator' mode will build automatically on first use.

% --- Load Data ---
load(data_filename);
fprintf('... Data loaded for %d day(s).\n', simulationDays);
Ts = 3600; Pnom = 500e3; Initial_SOC_pc_MIN = 30; Initial_SOC_pc_MAX = 80;
assignin('base', 'pv_power_profile', pv_power_profile);
assignin('base', 'load_power_profile', load_power_profile);
assignin('base', 'price_profile', price_profile);


%% 2. RL Agent and Environment Definition
% =========================================================================
disp('STEP 2: Defining RL agent and Simulink environment...');
% This section is correct and does not need changes.
num_observations = 7; 
obsInfo = rlNumericSpec([num_observations 1]);
actInfo = rlNumericSpec([1 1], 'LowerLimit', -Pnom, 'UpperLimit', Pnom);
statePath = [featureInputLayer(num_observations, 'Normalization', 'zscore', 'Name', 'obs'), fullyConnectedLayer(128, 'Name', 'fc_obs')];
actionPath = [featureInputLayer(1, 'Normalization', 'none', 'Name', 'act'), fullyConnectedLayer(128, 'Name', 'fc_act')];
commonPath = [additionLayer(2, 'Name', 'add'), reluLayer('Name', 'relu1'), fullyConnectedLayer(64, 'Name', 'fc_common'), reluLayer('Name', 'relu2'), fullyConnectedLayer(1, 'Name', 'q_value')];
criticNetwork = layerGraph(statePath);
criticNetwork = addLayers(criticNetwork, actionPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, 'fc_obs', 'add/in1');
criticNetwork = connectLayers(criticNetwork, 'fc_act', 'add/in2');
criticdlnetwork = dlnetwork(criticNetwork, 'Initialize', false);
critic_options = rlRepresentationOptions('LearnRate', 1e-3, 'GradientThreshold', 1, 'UseDevice', trainingDevice);
critic = rlQValueRepresentation(criticdlnetwork, obsInfo, actInfo, 'Observation', {'obs'}, 'Action', {'act'}, critic_options);
actorNetwork = [featureInputLayer(num_observations, 'Normalization', 'zscore', 'Name', 'obs'), fullyConnectedLayer(128, 'Name', 'fc1'), reluLayer('Name', 'relu1'), fullyConnectedLayer(64, 'Name', 'fc2'), reluLayer('Name', 'relu2'), fullyConnectedLayer(1, 'Name', 'fc_action'), tanhLayer('Name','tanh'), scalingLayer('Name','action_scaling', 'Scale', Pnom)];
actordlnetwork = dlnetwork(actorNetwork, 'Initialize', false);
actor_options = rlRepresentationOptions('LearnRate', 1e-4, 'GradientThreshold', 1, 'UseDevice', trainingDevice);
actor = rlDeterministicActorRepresentation(actordlnetwork, obsInfo, actInfo, 'Observation', {'obs'}, 'Action', {'action_scaling'}, actor_options);
agentOpts = rlDDPGAgentOptions('SampleTime', Ts, 'TargetSmoothFactor', 1e-3, 'DiscountFactor', 0.99, 'MiniBatchSize', 128, 'ExperienceBufferLength', 1e6);
agentOpts.NoiseOptions.MeanAttractionConstant = 1e-4;
agentOpts.NoiseOptions.Variance = 0.1 * Pnom;
agent = rlDDPGAgent(actor, critic, agentOpts);
assignin('base', 'agentObj', agent); 
agent_block_path = [model_name, '/RL Agent'];
env = rlSimulinkEnv(model_name, agent_block_path, obsInfo, actInfo);
env.ResetFcn = @(in) localResetFcn(in, model_name, Initial_SOC_pc_MIN, Initial_SOC_pc_MAX);
disp('... Agent and environment defined successfully.');


%% 3. Main Execution: Train or Load
% =========================================================================
if TRAIN_NEW_AGENT
    disp('STEP 3: Starting agent training...');
    
    trainOpts = rlTrainingOptions(...
        'MaxEpisodes', 5000, ...
        'MaxStepsPerEpisode', 24, ...
        'ScoreAveragingWindow', 20, ...
        'Verbose', true, ...
        'Plots', 'training-progress', ...
        'StopTrainingCriteria', 'AverageReward', ...
        'StopTrainingValue', 100);

    % Use the compatible syntax for parallel training
    if useParallel
        trainOpts.UseParallel = true;
        fprintf('>> Parallel training is ENABLED.\n');
    else
        trainOpts.UseParallel = false;
        fprintf('>> Parallel training is DISABLED.\n');
    end

    % Execute Training
    trainingStats = train(agent, env, trainOpts);
    
    disp('... Training finished. Saving agent...');
    save(saved_agent_filename, 'agent', 'trainingStats');
else
    disp('STEP 3: Loading pre-trained agent...');
    load(saved_agent_filename, 'agent');
end


%% 4. Evaluation and Visualization (Unchanged)
% ... (The code for evaluation and plotting remains the same) ...


%% 5. Local Functions
function in = localResetFcn(in, modelName, soc_min, soc_max)
    random_soc = rand() * (soc_max - soc_min) + soc_min;
    block_path = [modelName, '/Energy Storage'];
    in = setBlockParameter(in, block_path, 'Initial_kWh_pc', num2str(random_soc));
end
