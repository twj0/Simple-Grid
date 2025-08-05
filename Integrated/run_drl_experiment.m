% =========================================================================
%                  run_drl_experiment_v3.0.m
% -------------------------------------------------------------------------
% Description:
%   This script implements the main DRL training process for microgrid energy management
%   - v3.0 Update: Loads pre-generated simulation data from .mat files
%     including realistic random input data (PV, Load, Price)
%   - Compatible with Actor/Critic network configurations in R2024a/R2025a
%   - Supports GPU acceleration for faster training
%
%   The input data can be generated using generate_simulation_data.m
% =========================================================================

clear; clc; close all;

% Force MATLAB to use software (CPU) rendering to avoid potential GPU driver issues
opengl('software');
fprintf('>> Graphics renderer set to SOFTWARE (CPU) to ensure stability.\n\n');

%% 1. Control Panel
% -------------------------------------------------------------------------
disp('========================================');
disp('   DRL Microgrid Experiment Runner v3.0 ');
disp('========================================');


% Training configuration flags
TRAIN_NEW_AGENT = true;
data_filename = 'simulation_data_10days_random.mat'; 
model_name = 'Microgrid2508020734';
saved_agent_filename = 'final_trained_agent_random.mat'; 

% Force close and reload the model to ensure we have the latest version from disk
if bdIsLoaded(model_name)
    close_system(model_name, 0); % Close without saving
    fprintf('>> Closed any existing, in-memory instance of the model.\n');
end
try
    load_system(model_name);
    fprintf('>> Model loaded freshly from disk: %s\n', model_name);
catch ME
    error('Failed to load model %s: %s', model_name, ME.message);
end

% Determine training device (GPU or CPU)
trainingDevice = "cpu"; 
if ~isempty(ver('parallel')) && gpuDeviceCount > 0
    trainingDevice = "gpu";
    fprintf('>> GPU Detected! Training will be accelerated using: %s\n', gpuDevice(1).Name);
else
    fprintf('>> No compatible GPU found or Parallel Computing Toolbox is missing. Training will use CPU.\n');
end

%% 2. Load Environment Data from File
% -------------------------------------------------------------------------
disp(['STEP 1: Loading simulation data from "', data_filename, '"...']);
try
    % Check what variables are available in the data file
    data_vars = whos('-file', data_filename);
    var_names = {data_vars.name};

    % Load the simulation data file
    load(data_filename);

    % Check for solver configuration in the data file
    if ismember('solver_type', var_names) && ismember('solver_name', var_names)
        fprintf('... Data loaded with solver configuration: %s (%s)\n', solver_type, solver_name);
    else
        % Use default solver configuration if not specified in data file
        solver_type = 'fixed';
        solver_name = 'ode1';
        fprintf('... Data loaded (legacy format), using default solver: %s (%s)\n', solver_type, solver_name);
    end

    fprintf('... Data loaded successfully for %d day(s).\n', simulationDays);
catch ME
    fprintf('ERROR: Failed to load data file "%s".\n', data_filename);
    fprintf('Please run "generate_simulation_data.m" first to create the data file.\n');
    rethrow(ME);
end

% Set simulation parameters
Ts = Ts; % Sample time from loaded data
Tf = simulationDays * 24 * 3600; % Final simulation time in seconds

% Set the solver configuration for the simulation.
% As per the analysis, a variable-step solver is better suited for this physical model
% to handle potential stiff dynamics during large power transients.
% ode23tb is a good choice for moderately stiff problems.
fprintf('>> Using variable-step solver ode23tb as recommended for physical system simulation.\n');
set_param(model_name, 'SolverType', 'Variable-step');
set_param(model_name, 'Solver', 'ode23tb');
% The 'FixedStep' parameter is not used for variable-step solvers.

% Set model stop time to 24 hours for training episodes
stop_time_seconds = 24 * 3600; % 24-hour simulation
set_param(model_name, 'StopTime', num2str(stop_time_seconds));
fprintf('>> Model StopTime set to: %d seconds (24.0 hours)\n', stop_time_seconds);

% The model is now expected to be pre-configured correctly by the
% fix_simulink_sample_times.m script. The following manual synchronization
% is no longer needed and has been removed to prevent configuration conflicts.
fprintf('>> Assuming model sample times are correctly pre-configured.\n');

fprintf('>> Model configured: Ts=%d, StopTime=%d\n', Ts, 24*Ts);

% Battery and system parameters definition
PnomkW = 500; % Nominal power in kW
Pnom = PnomkW * 1e3; % Convert to Watts
kWh_Rated = 100; % Battery capacity in kWh
C_rated_Ah = kWh_Rated * 1000 / 5000; % Convert to Amp-hours assuming 5000V nominal
Efficiency = 96; % Battery efficiency percentage
Initial_SOC_pc = 80; % Initial state of charge percentage
Initial_SOC_pc_MIN = 30; % Minimum initial SOC for randomization
Initial_SOC_pc_MAX = 80; % Maximum initial SOC for randomization
COST_PER_AH_LOSS = 0.25; % Cost penalty for battery degradation
SOC_UPPER_LIMIT = 95.0; % Upper SOC operating limit
SOC_LOWER_LIMIT = 15.0; % Lower SOC operating limit
SOH_FAILURE_THRESHOLD = 0.8; % State of health failure threshold

% Display training mode
if TRAIN_NEW_AGENT
    fprintf('>> MODE: TRAINING a new agent for %d day(s) on [%s].\n\n', simulationDays, upper(trainingDevice));
else
    fprintf('>> MODE: EVALUATING pre-trained agent for %d day(s): %s\n\n', simulationDays, saved_agent_filename);
end

%% 3. RL Agent and Environment Definition
% -------------------------------------------------------------------------
disp('STEP 2: Defining RL agent and Simulink environment...');

% --- Define Observation and Action Specifications ---
% Based on project notes, the observation dimension is 7.
num_observations = 7;
fprintf('>> Using fixed observation dimension: %d\n', num_observations);
obsInfo = rlNumericSpec([num_observations 1], 'Name', 'Microgrid State');
actInfo = rlNumericSpec([1 1], 'LowerLimit', -Pnom, 'UpperLimit', Pnom, 'Name', 'Battery Power Command');

% --- Create R2025a v3.3 Compatible Critic Network ---
% State processing path
statePath = [featureInputLayer(num_observations, 'Normalization', 'zscore', 'Name', 'obs'), ...
             fullyConnectedLayer(128, 'Name', 'fc_obs')];
% Action processing path
actionPath = [featureInputLayer(1, 'Normalization', 'none', 'Name', 'act'), ...
              fullyConnectedLayer(128, 'Name', 'fc_act')];
% Common processing path after concatenation
commonPath = [additionLayer(2, 'Name', 'add'), ...
              reluLayer('Name', 'relu1'), ...
              fullyConnectedLayer(64, 'Name', 'fc_common'), ...
              reluLayer('Name', 'relu2'), ...
              fullyConnectedLayer(1, 'Name', 'q_value')];

% Build the critic network architecture
criticNetwork = layerGraph(statePath);
criticNetwork = addLayers(criticNetwork, actionPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, 'fc_obs', 'add/in1');
criticNetwork = connectLayers(criticNetwork, 'fc_act', 'add/in2');
criticdlnetwork = dlnetwork(criticNetwork, 'Initialize', false);

% Configure Critic representation options for R2025a compatibility
critic_options = rlRepresentationOptions(...
    'LearnRate', 1e-3, ...
    'GradientThreshold', 1);

% Create the critic representation
critic = rlQValueRepresentation(criticdlnetwork, obsInfo, actInfo, ...
    'Observation', {'obs'}, ...
    'Action', {'act'}, ...
    critic_options);

% --- Create R2025a v3.3 Compatible Actor Network ---
actorNetwork = [featureInputLayer(num_observations, 'Normalization', 'zscore', 'Name', 'obs'), ...
                fullyConnectedLayer(128, 'Name', 'fc1'), ...
                reluLayer('Name', 'relu1'), ...
                fullyConnectedLayer(64, 'Name', 'fc2'), ...
                reluLayer('Name', 'relu2'), ...
                fullyConnectedLayer(1, 'Name', 'fc_action'), ...
                tanhLayer('Name','tanh'), ...
                scalingLayer('Name','action_scaling', 'Scale', Pnom)];
actordlnetwork = dlnetwork(actorNetwork, 'Initialize', false);

% Configure Actor representation options
actor_options = rlRepresentationOptions(...
    'LearnRate', 1e-4, ...
    'GradientThreshold', 1);

% Create the actor representation
actor = rlDeterministicActorRepresentation(actordlnetwork, obsInfo, actInfo, ...
    'Observation', {'obs'}, ...
    'Action', {'action_scaling'}, ...
    actor_options);

% --- Configure DDPG Agent with proper noise settings ---
agentOpts = rlDDPGAgentOptions('SampleTime', Ts, ...
                               'TargetSmoothFactor', 1e-3, ...
                               'DiscountFactor', 0.99, ...
                               'MiniBatchSize', 128, ...
                               'ExperienceBufferLength', 1e6);

% Configure Ornstein-Uhlenbeck noise process for R2025a compatibility
% The MeanAttractionConstant must be scaled for the large sample time (Ts=3600)
% to ensure the noise process is stable: abs(1 - MeanAttractionConstant*Ts) <= 1
agentOpts.NoiseOptions.MeanAttractionConstant = 1e-4; % Scaled from 0.15 for stability
agentOpts.NoiseOptions.Variance = 0.1 * Pnom;
agentOpts.NoiseOptions.VarianceDecayRate = 0.995;
agentOpts.NoiseOptions.VarianceMin = 0.01 * Pnom;

% Create the DDPG agent
agent = rlDDPGAgent(actor, critic, agentOpts);

% Assign agent to base workspace for Simulink access
assignin('base', 'agentObj', agent);  
fprintf('>> Agent assigned to base workspace as "agentObj"\n');

% Assign data profiles to base workspace for Simulink model access
assignin('base', 'pv_power_profile', pv_power_profile);
assignin('base', 'load_power_profile', load_power_profile);
assignin('base', 'price_profile', price_profile);
fprintf('>> All data profiles assigned to base workspace\n');

% Fix Mux block configuration issues
fprintf('>> Checking and fixing Mux block configuration...\n');
try
    % Find the Mux block connected to the RL Agent's observation port
    agent_block_path = [model_name, '/RL Agent'];
    agent_ph = get_param(agent_block_path, 'PortHandles');
    obs_line = get_param(agent_ph.Inport(1), 'Line');
    
    if obs_line ~= -1
        src_block_handle = get_param(obs_line, 'SrcBlockHandle');
        src_block_type = get_param(src_block_handle, 'BlockType');
        src_block_path = getfullname(src_block_handle);

        if strcmp(src_block_type, 'Mux')
            fprintf('   Found Mux block connected to RL Agent: %s\n', src_block_path);
            
            % --- AGGRESSIVE FIX ---
            % The error indicates a dimension mismatch despite the 'Inputs' parameter being '7'.
            % This forces the configuration to be explicitly set.
            fprintf('   Applying aggressive fix to Mux block...\n');
            set_param(src_block_path, 'Inputs', '7');
            set_param(src_block_path, 'DisplayOption', 'signals');
            
            % The Mux block's sample time is inherited from its inputs. Setting it directly is not possible.
            % The correct solution is to ensure all signals feeding into the Mux have the correct, discrete sample time (Ts).
            % This is best done by placing a Rate Transition block on each input line to the Mux.
            fprintf('     ...Forced ''Inputs'' to ''7'' and ''DisplayOption'' to ''signals''.\n');
            fprintf('     ... Mux sample time is inherited. Ensure ALL INPUTS to the Mux have sample time Ts.\n');
            fprintf('     ... Consider using Rate Transition blocks on each input to the Mux.\n');
        else
            fprintf('   Warning: RL Agent observation is not directly connected to a Mux block. Source is: %s\n', src_block_type);
        end
    else
        fprintf('   Warning: RL Agent observation port is not connected.\n');
    end
    
    fprintf('   Mux configuration check completed.\n');

catch ME
    fprintf('   Warning: Could not fix Mux blocks automatically: %s\n', ME.message);
end

% --- Create Simulink environment interface ---
agent_block_path = [model_name, '/RL Agent'];
env = rlSimulinkEnv(model_name, agent_block_path, obsInfo, actInfo);
env.ResetFcn = @(in) localResetFcn(in, model_name, Initial_SOC_pc_MIN, Initial_SOC_pc_MAX);

% --- Validate Environment ---
fprintf('>> Validating environment...\n');
try
    validateEnvironment(env);
    fprintf('   Environment validation successful.\n');
catch ME
    fprintf('   ERROR: Environment validation failed: %s\n', ME.message);
    fprintf('   This may indicate a problem with the model or agent configuration.\n');
    rethrow(ME);
end

disp('... Agent and environment defined.');

%% 4. Main Execution: Train or Load
% -------------------------------------------------------------------------
if TRAIN_NEW_AGENT
    disp('STEP 3: Starting agent training...');
    
    % Ensure model stop time is sufficient for training episodes
    current_stop_time = str2double(get_param(model_name, 'StopTime'));
    required_stop_time = 2 * 3600; % 2 hours minimum

    if current_stop_time < required_stop_time
        set_param(model_name, 'StopTime', num2str(required_stop_time));
        fprintf('>> Fixed StopTime: %d -> %d seconds\n', current_stop_time, required_stop_time);
    end

    % Configure training options for a long overnight run
    trainOpts = rlTrainingOptions(...
        'MaxEpisodes', 500, ...
        'MaxStepsPerEpisode', 24, ...  % Each episode simulates a full day (24 * 3600 / Ts)
        'ScoreAveragingWindow', 10, ...
        'Verbose', true, ...
        'Plots', 'training-progress', ...
        'StopTrainingCriteria', 'AverageReward', ... % Use average reward as stopping criteria for robustness
        'StopTrainingValue', -500, ...  % Set target average reward value
        'SaveAgentCriteria', 'EpisodeReward',...
        'SaveAgentValue', -1000, ... % Save agents with reward above -1000
        'SaveAgentDirectory', 'saved_agents');

    fprintf('>> Starting training with %d episodes, max %d steps per episode\n', ...
            trainOpts.MaxEpisodes, trainOpts.MaxStepsPerEpisode);

    % Pre-training diagnostics
    fprintf('>> Pre-training checks...\n');
    try
        % Test model compilation
        fprintf('   Testing model compilation...\n');
        eval([model_name '([], [], [], ''compile'')']);
        fprintf('     Model compiles OK\n');
        eval([model_name '([], [], [], ''term'')']);

        % Test environment reset
        fprintf('   Testing environment reset...\n');
        test_obs = reset(env);
        fprintf('     Environment reset OK, obs size: %s\n', mat2str(size(test_obs)));

    catch ME_check
        fprintf('   Pre-training check failed: %s\n', ME_check.message);
    end

    fprintf('>> Starting actual training...\n');
    try
        trainingStats = train(agent, env, trainOpts);
    catch ME_train
        fprintf('Training failed: %s\n', ME_train.message);

        % Diagnose Mux blocks for troubleshooting
        fprintf('Diagnosing Mux blocks:\n');
        try
            mux_blocks = find_system(model_name, 'BlockType', 'Mux');
            for i = 1:length(mux_blocks)
                block_path = mux_blocks{i};
                inputs_param = get_param(block_path, 'Inputs');
                fprintf('  %s: inputs=%s\n', strrep(block_path, [model_name '/'], ''), inputs_param);
            end
        catch
            fprintf('  Could not diagnose Mux blocks\n');
        end

        rethrow(ME_train);
    end

    disp('... Training finished. Saving agent...');
    save(saved_agent_filename, 'agent');

    % Display training summary
    if ~isempty(trainingStats.EpisodeSteps)
        final_steps = trainingStats.EpisodeSteps(end);
        final_reward = trainingStats.EpisodeReward(end);
        fprintf('>> Final episode: %d steps, reward: %.2f\n', final_steps, final_reward);

        if final_steps > 0
            fprintf('SUCCESS: Training completed with non-zero steps!\n');
        else
            fprintf('WARNING: Final episode still has 0 steps\n');
        end
    end

else
    disp('STEP 3: Loading pre-trained agent...');
    try
        load(saved_agent_filename, 'agent');
        disp('... Agent loaded successfully.');
    catch ME
        error('Could not load agent file: %s. Please train an agent first by setting TRAIN_NEW_AGENT = true.', ME.message);
    end
end

%% 5. Performance Evaluation
disp('STEP 4: Evaluating agent performance...');
try
    % Configure simulation input for evaluation
    simIn = Simulink.SimulationInput(model_name);
    simIn = simIn.setModelParameter('StopTime', num2str(24 * 3600)); 
    simIn = simIn.setModelParameter('ReturnWorkspaceOutputs', 'on');

    % Run evaluation simulation
    simOut = sim(simIn);
    disp('... Simulation for evaluation complete.');

    % Display training statistics if available
    if exist('trainingStats', 'var') && ~isempty(trainingStats.EpisodeSteps)
        avg_steps = mean(trainingStats.EpisodeSteps(trainingStats.EpisodeSteps > 0));
        avg_reward = mean(trainingStats.EpisodeReward(trainingStats.EpisodeSteps > 0));
        fprintf('>> Training Summary:\n');
        fprintf('   Average steps per episode: %.1f\n', avg_steps);
        fprintf('   Average reward per episode: %.2f\n', avg_reward);
    end

catch ME
    fprintf('Warning: Evaluation simulation failed: %s\n', ME.message);
    disp('This is not critical - the agent training was the main objective.');
end

%% 6. Data Extraction & Visualization
disp('STEP 5: Extracting data and generating plots...');

try
    % Add robustness check for simOut type as suggested
    if exist('simOut', 'var') && isa(simOut, 'Simulink.Simulation.Output')
        fprintf('   Simulation output is a valid Simulink.Simulation.Output object.\n');
        
        % Extract data using the .get() method
        logsout = simOut.get('logsout');
        tout = simOut.get('tout');
        days = tout / (3600 * 24);

        if ~isempty(logsout) && logsout.numElements > 0
            fprintf('   Logged signals available with %d elements.\n', logsout.numElements);
            try
                % Extract power and state data from simulation logs
                P_pv_sim = logsout.get('P_pv').Values.Data / 1000; % Convert to kW
                P_load_sim = logsout.get('P_load').Values.Data / 1000; % Convert to kW
                P_batt_sim = logsout.get('P_batt').Values.Data / 1000; % Convert to kW
                SOC_sim = logsout.get('Battery_SOC').Values.Data; % State of charge
                SOH_sim = logsout.get('SOH').Values.Data; % State of health
                Price_sim = logsout.get('price').Values.Data; % Electricity price
                P_grid_sim = P_load_sim - P_pv_sim - P_batt_sim; % Calculate grid power
                fprintf('   Data extraction successful.\n');
            catch ME_extract
                fprintf('   Warning: Could not extract all logged signals: %s\n', ME_extract.message);
                fprintf('   This might happen if signal logging is not configured correctly in the model.\n');
            end
        else
            fprintf('   Warning: Logged signals (logsout) are empty.\n');
        end
    else
        fprintf('   Warning: Simulation output is not available or has an unexpected type.\n');
        fprintf('   Skipping visualization.\n');
    end
catch ME
    fprintf('   Error during data extraction: %s\n', ME.message);
    fprintf('   Skipping visualization.\n');
end

% Generate plots only if data is available
if exist('P_pv_sim', 'var') && exist('days', 'var')
    fprintf('   Generating performance plots...\n');

    figure('Name', 'DRL Microgrid Control Performance', 'NumberTitle', 'off', 'Position', [100 100 1200 800]);

    % Power balance subplot
    subplot(3, 1, 1);
    plot(days, P_pv_sim, 'g-'); hold on;
    plot(days, P_load_sim, 'b-');
    plot(days, P_grid_sim, 'r--');
    plot(days, P_batt_sim, 'm-.', 'LineWidth', 1.5);
    hold off;
    title('System Power Balance');
    xlabel('Time (days)');
    ylabel('Power (kW)');
    legend('PV', 'Load', 'Grid', 'Battery', 'Location', 'best');
    grid on;
    xlim([0 days(end)]);

    % SOC and price subplot
    subplot(3, 1, 2);
    yyaxis left;
    plot(days, SOC_sim, 'b-');
    ylabel('SOC (%)');
    ylim([0 100]);
    hold on;
    yyaxis right;
    area(days, Price_sim, 'FaceColor', [1 0.8 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
    plot(days, Price_sim, 'r--');
    ylabel('Price ($/kWh)');
    hold off;
    title('SOC vs. Price');
    xlabel('Time (days)');
    legend('SOC', 'Price', 'Location', 'best');
    grid on;
    xlim([0 days(end)]);

    % SOH degradation subplot
    subplot(3, 1, 3);
    plot(days, SOH_sim * 100, 'k-');
    title('SOH Degradation');
    xlabel('Time (days)');
    ylabel('SOH (%)');
    grid on;
    xlim([0 days(end)]);
    
    % Calculate degradation and set appropriate y-axis limits
    initial_soh = SOH_sim(1) * 100;
    final_soh = SOH_sim(end) * 100;
    ylim_buffer = (initial_soh - final_soh) * 0.1;
    if ylim_buffer == 0; ylim_buffer = 0.001; end;
    ylim([final_soh - ylim_buffer, initial_soh + ylim_buffer]);
    legend(sprintf('Degradation over %d day(s): %.4f %%', simulationDays, initial_soh - final_soh), 'Location', 'best');

    fprintf('   Plotting complete.\n');
else
    fprintf('   Skipping plots - simulation data not available\n');
end

disp('... Experiment finished.');
disp('========================================');

%% 7. Local Functions
function in = localResetFcn(in, modelName, soc_min, soc_max)
    % Local reset function for randomizing initial battery SOC
    % This function is called at the beginning of each training episode
    % to provide variety in initial conditions
    
    % Generate random initial SOC within specified bounds
    random_soc = rand() * (soc_max - soc_min) + soc_min;
    
    % Set the initial SOC parameter in the energy storage block
    block_path = [modelName, '/Energy Storage'];
    in = setBlockParameter(in, block_path, 'Initial_kWh_pc', num2str(random_soc));
end
