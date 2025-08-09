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
    
    % Save the simulation output for plotting
    disp('>> Saving evaluation results to evaluation_results.mat...');
    save('evaluation_results.mat', 'simOut');

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
disp('STEP 5: Processing simulation results and generating plots...');

% Check if simulation output is available
if exist('simOut', 'var') && ~isempty(simOut)
    try
        % Process simulation results
        simulation_results = processSimulationResults(simOut, model_name);

        % Generate plots using the modular plotting system
        generateDRLPlots(simulation_results, saved_agent_filename);

        % Display results summary
        displayResultsSummary(simulation_results);

        disp('>> Visualization complete. Check the plots folder for generated charts.');

    catch ME_plot
        fprintf('Warning: Plotting failed: %s\n', ME_plot.message);
        fprintf('Simulation output is available but could not be processed for plotting.\n');

        % Provide diagnostic information
        if isstruct(simOut)
            fields = fieldnames(simOut);
            fprintf('Available simOut fields: %s\n', strjoin(fields, ', '));
        else
            fprintf('simOut type: %s\n', class(simOut));
        end
    end
else
    fprintf('Warning: Simulation output is not available or has an unexpected type.\n');
    fprintf('This may occur if the evaluation simulation failed or was skipped.\n');

    % Try to load from saved file
    if exist('evaluation_results.mat', 'file')
        try
            fprintf('>> Attempting to load simulation results from evaluation_results.mat...\n');
            eval_data = load('evaluation_results.mat');
            if isfield(eval_data, 'simOut')
                simulation_results = processSimulationResults(eval_data.simOut, model_name);
                generateDRLPlots(simulation_results, saved_agent_filename);
                displayResultsSummary(simulation_results);
                disp('>> Successfully generated plots from saved evaluation results.');
            else
                fprintf('Warning: No simOut found in evaluation_results.mat\n');
            end
        catch ME_load
            fprintf('Warning: Could not load or process saved evaluation results: %s\n', ME_load.message);
        end
    end
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

function simulation_results = processSimulationResults(simOut, model_name)
    % Process simulation output into a standardized format for plotting

    fprintf('>> Processing simulation results...\n');

    % Initialize results structure
    simulation_results = struct();
    simulation_results.type = 'drl_experiment';
    simulation_results.model_name = model_name;
    simulation_results.timestamp = datetime('now');

    try
        % Extract time vector
        if isfield(simOut, 'tout')
            time_vector = simOut.tout;
        elseif isfield(simOut, 'time')
            time_vector = simOut.time;
        else
            % Try to get time from logged signals
            if isfield(simOut, 'logsout') && ~isempty(simOut.logsout)
                logsout = simOut.logsout;
                if isa(logsout, 'Simulink.SimulationData.Dataset')
                    % Get time from first signal
                    if logsout.numElements > 0
                        first_element = logsout.getElement(1);
                        time_vector = first_element.Values.Time;
                    else
                        error('No logged signals found in simulation output');
                    end
                else
                    error('Unexpected logsout format');
                end
            else
                error('No time vector found in simulation output');
            end
        end

        simulation_results.time = time_vector;
        simulation_results.time_days = time_vector / (24 * 3600);

        % Extract logged signals
        simulation_results.signals = extractDRLSignals(simOut);

        % Calculate performance metrics
        simulation_results.metrics = calculateDRLMetrics(simulation_results.signals, time_vector);

        fprintf('   Successfully processed %d data points over %.2f days\n', ...
                length(time_vector), time_vector(end)/(24*3600));

    catch ME
        fprintf('   Warning: Error processing simulation results: %s\n', ME.message);

        % Create minimal structure with available data
        simulation_results.time = [];
        simulation_results.signals = struct();
        simulation_results.metrics = struct();
        simulation_results.error = ME.message;
    end
end

function signals = extractDRLSignals(simOut)
    % Extract key signals from DRL simulation output

    signals = struct();

    try
        % Get logged signals
        if isfield(simOut, 'logsout') && ~isempty(simOut.logsout)
            logsout = simOut.logsout;
        else
            fprintf('   Warning: No logsout found in simulation output\n');
            return;
        end

        % Common signal names to look for
        signal_names = {
            {'P_pv', 'PV_Power', 'pv_power_profile', 'PV'}, 'P_pv';
            {'P_load', 'Load_Power', 'load_power_profile', 'Load'}, 'P_load';
            {'P_batt', 'Battery_Power', 'Batt_Power', 'P_battery'}, 'P_batt';
            {'P_grid', 'Grid_Power', 'P_net', 'Net_Power'}, 'P_grid';
            {'SOC', 'Battery_SOC', 'SOC_Battery', 'State_of_Charge'}, 'SOC';
            {'SOH', 'Battery_SOH', 'SOH_Battery', 'State_of_Health'}, 'SOH';
            {'price', 'Price', 'price_profile', 'Electricity_Price'}, 'price';
            {'action', 'RL_Action', 'Agent_Action', 'Control_Action'}, 'action'
        };

        % Extract signals based on type
        if isa(logsout, 'Simulink.SimulationData.Dataset')
            % Dataset format
            for i = 1:logsout.numElements
                element = logsout.getElement(i);
                signal_name = element.Name;

                % Map to standard name
                standard_name = mapSignalName(signal_name, signal_names);
                if ~isempty(standard_name)
                    signals.(standard_name) = element.Values.Data;
                end
            end
        else
            % Try other formats
            field_names = fieldnames(logsout);
            for i = 1:length(field_names)
                signal_name = field_names{i};
                standard_name = mapSignalName(signal_name, signal_names);
                if ~isempty(standard_name)
                    signal_data = logsout.(signal_name);
                    if isstruct(signal_data) && isfield(signal_data, 'Data')
                        signals.(standard_name) = signal_data.Data;
                    else
                        signals.(standard_name) = signal_data;
                    end
                end
            end
        end

        fprintf('   Extracted %d signals from simulation output\n', length(fieldnames(signals)));

    catch ME
        fprintf('   Warning: Error extracting signals: %s\n', ME.message);
    end
end

function standard_name = mapSignalName(signal_name, signal_names)
    % Map signal name to standard name

    standard_name = '';

    for i = 1:size(signal_names, 1)
        possible_names = signal_names{i, 1};
        target_name = signal_names{i, 2};

        if any(strcmpi(signal_name, possible_names))
            standard_name = target_name;
            break;
        end
    end
end

function metrics = calculateDRLMetrics(signals, time_vector)
    % Calculate performance metrics for DRL experiment

    metrics = struct();

    if isempty(signals) || isempty(time_vector)
        return;
    end

    try
        % Time metrics
        time_hours = time_vector / 3600;
        metrics.duration_hours = time_hours(end);
        metrics.duration_days = metrics.duration_hours / 24;

        % Energy calculations (convert W to kW and integrate)
        if isfield(signals, 'P_pv') && ~isempty(signals.P_pv)
            P_pv_kW = signals.P_pv / 1000;
            metrics.pv_energy_kwh = trapz(time_hours, P_pv_kW);
        end

        if isfield(signals, 'P_load') && ~isempty(signals.P_load)
            P_load_kW = signals.P_load / 1000;
            metrics.load_energy_kwh = trapz(time_hours, P_load_kW);
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
            metrics.net_grid_energy = trapz(time_hours, P_grid_kW);
        end

        % SOC metrics
        if isfield(signals, 'SOC') && ~isempty(signals.SOC)
            metrics.soc_min = min(signals.SOC);
            metrics.soc_max = max(signals.SOC);
            metrics.soc_avg = mean(signals.SOC);
            metrics.soc_final = signals.SOC(end);
            metrics.soc_initial = signals.SOC(1);
        end

        % SOH metrics
        if isfield(signals, 'SOH') && ~isempty(signals.SOH)
            metrics.soh_initial = signals.SOH(1);
            metrics.soh_final = signals.SOH(end);
            metrics.soh_degradation = (metrics.soh_initial - metrics.soh_final) * 100;
        end

        % Economic metrics
        if isfield(signals, 'price') && isfield(signals, 'P_grid') && ...
           ~isempty(signals.price) && ~isempty(signals.P_grid)
            P_grid_kW = signals.P_grid / 1000;
            metrics.electricity_cost = trapz(time_hours, P_grid_kW .* signals.price);
            metrics.avg_price = mean(signals.price);
        end

        % DRL-specific metrics
        if isfield(signals, 'action') && ~isempty(signals.action)
            metrics.action_mean = mean(signals.action);
            metrics.action_std = std(signals.action);
            metrics.action_range = [min(signals.action), max(signals.action)];
        end

    catch ME
        fprintf('   Warning: Error calculating metrics: %s\n', ME.message);
    end
end

function generateDRLPlots(simulation_results, agent_filename)
    % Generate plots for DRL experiment using modular plotting system

    fprintf('>> Generating DRL experiment plots...\n');

    try
        % Check if modular plotting system is available
        if exist('modular_plotting_system.m', 'file') ~= 2
            fprintf('   Warning: modular_plotting_system.m not found, using basic plotting\n');
            generateBasicDRLPlots(simulation_results, agent_filename);
            return;
        end

        % Create output directory
        [~, agent_name, ~] = fileparts(agent_filename);
        output_dir = sprintf('drl_plots_%s_%s', agent_name, ...
                           string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));

        % Configure plotting
        plot_config = struct();
        plot_config.theme = 'publication';
        plot_config.format = 'png';
        plot_config.resolution = 300;
        plot_config.save_plots = true;
        plot_config.show_plots = false;
        plot_config.verbose = true;

        % Generate comprehensive plots
        plot_types = {'power_balance', 'soc_price', 'battery_performance', 'economic_analysis'};

        % Add DRL-specific action plot if action data is available
        if isfield(simulation_results.signals, 'action')
            plot_types{end+1} = 'drl_actions';
        end

        % Call modular plotting system
        modular_plotting_system('data_struct', simulation_results, ...
                               'plot_types', plot_types, ...
                               'output_dir', output_dir, ...
                               'config', plot_config);

        % Generate DRL-specific action plot
        if isfield(simulation_results.signals, 'action')
            generateDRLActionPlot(simulation_results, output_dir);
        end

        fprintf('   DRL plots saved to: %s\n', output_dir);

    catch ME
        fprintf('   Warning: Modular plotting failed: %s\n', ME.message);
        fprintf('   Falling back to basic plotting...\n');
        generateBasicDRLPlots(simulation_results, agent_filename);
    end
end

function generateDRLActionPlot(simulation_results, output_dir)
    % Generate DRL-specific action plot

    if ~isfield(simulation_results.signals, 'action') || isempty(simulation_results.signals.action)
        return;
    end

    try
        fig = figure('Name', 'DRL Agent Actions', 'NumberTitle', 'off', ...
                    'Position', [100 100 1200 600]);

        time_hours = simulation_results.time / 3600;
        actions = simulation_results.signals.action / 1000; % Convert to kW

        % Plot actions
        subplot(2, 1, 1);
        plot(time_hours, actions, 'b-', 'LineWidth', 1.5);
        xlabel('Time (hours)');
        ylabel('Battery Power Command (kW)');
        title('DRL Agent Actions Over Time');
        grid on;

        % Add zero line
        yline(0, 'k--', 'Alpha', 0.5);

        % Plot action histogram
        subplot(2, 1, 2);
        histogram(actions, 50, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'none');
        xlabel('Battery Power Command (kW)');
        ylabel('Frequency');
        title('Distribution of DRL Agent Actions');
        grid on;

        % Add statistics
        action_mean = mean(actions);
        action_std = std(actions);
        text(0.02, 0.98, sprintf('Mean: %.2f kW\nStd: %.2f kW', action_mean, action_std), ...
             'Units', 'normalized', 'VerticalAlignment', 'top', ...
             'BackgroundColor', 'white', 'EdgeColor', 'black');

        % Save plot
        plot_file = fullfile(output_dir, 'drl_agent_actions.png');
        print(fig, plot_file, '-dpng', '-r300');
        close(fig);

    catch ME
        fprintf('   Warning: Could not generate DRL action plot: %s\n', ME.message);
    end
end

function generateBasicDRLPlots(simulation_results, agent_filename)
    % Generate basic plots when modular plotting system is not available

    fprintf('   Generating basic DRL plots...\n');

    if isempty(simulation_results.signals)
        fprintf('   Warning: No signal data available for plotting\n');
        return;
    end

    try
        % Create output directory
        [~, agent_name, ~] = fileparts(agent_filename);
        output_dir = sprintf('basic_drl_plots_%s', agent_name);
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end

        signals = simulation_results.signals;
        time_hours = simulation_results.time / 3600;

        % Power balance plot
        if isfield(signals, 'P_pv') || isfield(signals, 'P_load')
            fig1 = figure('Name', 'Power Balance', 'NumberTitle', 'off');
            hold on;

            if isfield(signals, 'P_pv') && ~isempty(signals.P_pv)
                plot(time_hours, signals.P_pv/1000, 'g-', 'LineWidth', 1.5, 'DisplayName', 'PV Power');
            end
            if isfield(signals, 'P_load') && ~isempty(signals.P_load)
                plot(time_hours, signals.P_load/1000, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Load Power');
            end
            if isfield(signals, 'P_batt') && ~isempty(signals.P_batt)
                plot(time_hours, signals.P_batt/1000, 'm-', 'LineWidth', 1.5, 'DisplayName', 'Battery Power');
            end

            xlabel('Time (hours)');
            ylabel('Power (kW)');
            title('System Power Balance');
            legend('show');
            grid on;

            saveas(fig1, fullfile(output_dir, 'power_balance.png'));
            close(fig1);
        end

        % SOC plot
        if isfield(signals, 'SOC') && ~isempty(signals.SOC)
            fig2 = figure('Name', 'Battery SOC', 'NumberTitle', 'off');
            plot(time_hours, signals.SOC, 'b-', 'LineWidth', 1.5);
            xlabel('Time (hours)');
            ylabel('SOC (%)');
            title('Battery State of Charge');
            grid on;
            ylim([0 100]);

            saveas(fig2, fullfile(output_dir, 'battery_soc.png'));
            close(fig2);
        end

        % DRL actions plot
        if isfield(signals, 'action') && ~isempty(signals.action)
            fig3 = figure('Name', 'DRL Actions', 'NumberTitle', 'off');
            plot(time_hours, signals.action/1000, 'r-', 'LineWidth', 1.5);
            xlabel('Time (hours)');
            ylabel('Action (kW)');
            title('DRL Agent Actions');
            grid on;
            yline(0, 'k--', 'Alpha', 0.5);

            saveas(fig3, fullfile(output_dir, 'drl_actions.png'));
            close(fig3);
        end

        fprintf('   Basic plots saved to: %s\n', output_dir);

    catch ME
        fprintf('   Warning: Basic plotting failed: %s\n', ME.message);
    end
end

function displayResultsSummary(simulation_results)
    % Display summary of simulation results

    fprintf('>> Simulation Results Summary:\n');
    fprintf('   ========================================\n');

    if isfield(simulation_results, 'metrics') && ~isempty(simulation_results.metrics)
        metrics = simulation_results.metrics;

        % Duration
        if isfield(metrics, 'duration_hours')
            fprintf('   Duration: %.2f hours (%.2f days)\n', ...
                    metrics.duration_hours, metrics.duration_days);
        end

        % Energy metrics
        if isfield(metrics, 'pv_energy_kwh')
            fprintf('   PV Generation: %.2f kWh\n', metrics.pv_energy_kwh);
        end
        if isfield(metrics, 'load_energy_kwh')
            fprintf('   Load Consumption: %.2f kWh\n', metrics.load_energy_kwh);
        end
        if isfield(metrics, 'net_grid_energy')
            fprintf('   Net Grid Exchange: %.2f kWh\n', metrics.net_grid_energy);
        end

        % Battery metrics
        if isfield(metrics, 'soc_final')
            fprintf('   Final SOC: %.1f%% (Initial: %.1f%%)\n', ...
                    metrics.soc_final, metrics.soc_initial);
        end
        if isfield(metrics, 'soh_degradation')
            fprintf('   SOH Degradation: %.4f%%\n', metrics.soh_degradation);
        end

        % Economic metrics
        if isfield(metrics, 'electricity_cost')
            fprintf('   Electricity Cost: $%.2f\n', metrics.electricity_cost);
        end

        % DRL metrics
        if isfield(metrics, 'action_mean')
            fprintf('   Average Action: %.2f kW (Std: %.2f kW)\n', ...
                    metrics.action_mean/1000, metrics.action_std/1000);
        end

    else
        fprintf('   Warning: No metrics available\n');
    end

    fprintf('   ========================================\n');
end
