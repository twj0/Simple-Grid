classdef ResearchMicrogridEnvironment < rl.env.MATLABEnvironment
    % RESEARCHMICROGRIDENVIRONMENT - Advanced Microgrid Environment for Research
    %
    % This environment is designed for detailed research and includes:
    % - 30-day simulation horizon for long-term analysis.
    % - Advanced battery degradation models (cycle and calendar aging).
    % - Sophisticated, multi-component reward function.
    % - Detailed state and action logging for in-depth analysis.
    % - Configurable via a structured `config` object.
    
    properties
        % System State
        SOC = 0.5;              % State of Charge (0 to 1)
        SOH = 1.0;              % State of Health (0 to 1)
        TimeStep = 1;           % Current simulation time step (hour)
        
        % System Parameters
        BatteryCapacity         % Battery capacity in Watt-hours (Wh)
        BatteryPowerRating      % Maximum battery power in Watts (W)
        BatteryEfficiency       % Round-trip efficiency of the battery
        SOCLimits               % SOC operational limits [min, max]
        
        % Input Data & Configuration
        Data                    % Struct containing 30-day simulation data (pv_power, load_power, price)
        SystemParams            % Struct with detailed system parameters
        Config                  % Struct with simulation and agent configuration
        
        % Performance Metrics
        TotalEnergyTraded = 0;  % Total energy traded with the grid (kWh)
        TotalCost = 0;          % Cumulative operational cost (CNY)
        CycleCount = 0;         % Equivalent full cycle count for the battery
        
        % Logging for Analysis
        StateHistory = [];      % History of all states over the episode
        ActionHistory = [];     % History of all actions taken
        RewardHistory = [];     % History of all rewards received
    end
    
    methods
        function this = ResearchMicrogridEnvironment(obs_info, action_info, data, system_params, config)
            % Constructor for the research environment
            this = this@rl.env.MATLABEnvironment(obs_info, action_info);
            
            % Assign input data and configuration structures
            this.Data = data;
            this.SystemParams = system_params;
            this.Config = config;
            
            % Initialize system parameters from the provided structs
            this.BatteryCapacity = system_params.battery_capacity_kwh * 1000 * 3600; % Convert kWh to Wh
            this.BatteryPowerRating = system_params.battery_power_kw * 1000; % Convert kW to W
            this.BatteryEfficiency = system_params.battery_efficiency;
            this.SOCLimits = system_params.soc_limits;
            
            % Set initial state
            this.SOC = system_params.initial_soc;
            this.SOH = system_params.soh_initial;
        end
        
        function [obs, reward, is_done, info] = step(this, action)
            % Execute one time step with advanced modeling
            
            % Get current external conditions from the 30-day data profile
            if this.TimeStep <= length(this.Data.pv_power)
                pv_power = this.Data.pv_power(this.TimeStep) * 1000; % Convert kW to W
                load_power = this.Data.load_power(this.TimeStep) * 1000; % Convert kW to W
                price = this.Data.price(this.TimeStep); % CNY/kWh
            else
                % If simulation exceeds data length, hold the last data point
                pv_power = this.Data.pv_power(end) * 1000;
                load_power = this.Data.load_power(end) * 1000;
                price = this.Data.price(end);
            end
            
            % Handle action, which may be a cell array
            if iscell(action)
                battery_power = double(action{1}); % Extract numeric value from cell
            else
                battery_power = double(action);
            end
            battery_power = max(-this.BatteryPowerRating, min(this.BatteryPowerRating, battery_power));
            
            % Update State of Charge (SOC)
            dt = this.Config.time_step_hours; % Time step in hours
            if battery_power > 0 % Charging
                energy_change = battery_power * dt * this.BatteryEfficiency;
            else % Discharging
                energy_change = battery_power * dt / this.BatteryEfficiency;
            end
            
            new_soc = this.SOC + energy_change / this.BatteryCapacity;
            new_soc = max(this.SOCLimits(1), min(this.SOCLimits(2), new_soc));
            
            % Advanced State of Health (SOH) Degradation Model
            % This model includes both cycle and calendar aging.
            cycle_depth = abs(new_soc - this.SOC);
            
            % Temperature Stress (simplified model)
            hour_of_day = mod(this.TimeStep - 1, 24) + 1;
            ambient_temp = 25 + 10 * sin(2*pi*(hour_of_day-12)/24); % Simple daily temperature sine wave
            temp_stress = 1 + max(0, (ambient_temp - 25) * 0.01); % Stress increases above 25C
            
            % Cycle Aging
            cycle_aging = 2e-6 * cycle_depth * temp_stress;
            
            % Calendar Aging
            calendar_aging = 1e-7 * dt; % Constant degradation over time
            
            % Total Aging
            total_aging = cycle_aging + calendar_aging;
            new_soh = max(0.5, this.SOH - total_aging); % Enforce SOH lower limit
            
            % Update Cycle Count
            if cycle_depth > 0.01 % Register a cycle if depth is significant
                this.CycleCount = this.CycleCount + cycle_depth;
            end
            
            % Calculate Grid Power Exchange
            grid_power = load_power - pv_power - battery_power;
            
            % Multi-component Reward Function
            % 1. Economic Cost (primary objective)
            if grid_power > 0 % Buying from grid
                economic_cost = grid_power * price * dt / 1000; % Cost in CNY
            else % Selling to grid
                economic_cost = grid_power * price * 0.8 * dt / 1000; % Assume selling price is 80% of buying price
            end
            
            % 2. Battery Degradation Cost
            battery_degradation_cost = total_aging * this.BatteryCapacity / 1000 * 0.5; % Cost per kWh of capacity loss
            
            % 3. SOC Penalty (to encourage staying in the optimal range)
            soc_penalty = 0;
            if new_soc < 0.2 || new_soc > 0.8
                soc_penalty = 50 * abs(new_soc - 0.5); % Penalize deviation from center
            end
            
            % 4. Power Smoothing Reward (to incentivize grid stability)
            power_smoothing_reward = 0;
            if abs(grid_power) < 0.1 * load_power
                power_smoothing_reward = 10; % Reward for low grid interaction
            end
            
            % 5. Long-term Stability Reward
            stability_reward = 0;
            if this.TimeStep > 24 % Only apply after the first day
                if new_soc > 0.3 && new_soc < 0.7 && new_soh > 0.9
                    stability_reward = 5; % Reward for maintaining a healthy state
                end
            end
            
            % Total Reward (combining all components)
            reward = -(economic_cost + battery_degradation_cost + soc_penalty) ...
                     + power_smoothing_reward + stability_reward;
            
            % Update State and Metrics
            this.SOC = new_soc;
            this.SOH = new_soh;
            this.TimeStep = this.TimeStep + 1;
            this.TotalEnergyTraded = this.TotalEnergyTraded + abs(grid_power) * dt / 1000;
            this.TotalCost = this.TotalCost + economic_cost;
            
            % Log State, Action, and Reward for Analysis
            current_state = [pv_power/1000; load_power/1000; new_soc; new_soh; price;
                           mod(this.TimeStep-1, 24)+1; ceil(this.TimeStep/24)];
            this.StateHistory = [this.StateHistory, current_state];
            this.ActionHistory = [this.ActionHistory, battery_power/1000];
            this.RewardHistory = [this.RewardHistory, reward];
            
            % Formulate Next Observation
            hour_of_day = mod(this.TimeStep - 1, 24) + 1;
            day_of_simulation = ceil(this.TimeStep / 24);
            
            obs = [double(pv_power/1000); double(load_power/1000); double(new_soc);
                   double(new_soh); double(price); double(hour_of_day); double(day_of_simulation)];
            
            % Check for Termination Condition
            max_steps = this.Config.simulation_days * 24;
            is_done = (this.TimeStep > max_steps) || (new_soh < 0.6);
            
            % Return Detailed Information for Analysis
            info = struct(...
                'grid_power_kw', double(grid_power/1000), ...
                'economic_cost', double(economic_cost), ...
                'battery_degradation_cost', double(battery_degradation_cost), ...
                'soc_penalty', double(soc_penalty), ...
                'power_smoothing_reward', double(power_smoothing_reward), ...
                'stability_reward', double(stability_reward), ...
                'cycle_count', double(this.CycleCount), ...
                'total_energy_traded', double(this.TotalEnergyTraded), ...
                'total_cost', double(this.TotalCost), ...
                'ambient_temp', double(ambient_temp), ...
                'temp_stress', double(temp_stress), ...
                'cycle_aging', double(cycle_aging), ...
                'calendar_aging', double(calendar_aging));
        end
        
        function obs = reset(this)
            % Reset the environment to a new initial state
            
            % Set random seed for reproducibility, adding timestep to vary sequence
            rng(this.Config.random_seed + this.TimeStep);
            
            % Initialize SOC with slight randomization around the configured initial value
            this.SOC = this.SystemParams.initial_soc + 0.1 * (rand() - 0.5); % Add +/- 5% random variation
            this.SOC = max(this.SOCLimits(1), min(this.SOCLimits(2), this.SOC));
            
            this.SOH = this.SystemParams.soh_initial;
            this.TimeStep = 1;
            
            % Reset performance metrics
            this.TotalEnergyTraded = 0;
            this.TotalCost = 0;
            this.CycleCount = 0;
            
            % Clear logging histories
            this.StateHistory = [];
            this.ActionHistory = [];
            this.RewardHistory = [];
            
            % Get initial observation from data
            if ~isempty(this.Data.pv_power)
                pv_power = this.Data.pv_power(1) * 1000; % W
                load_power = this.Data.load_power(1) * 1000; % W
                price = this.Data.price(1); % CNY/kWh
            else
                % Provide default values if data is missing
                pv_power = 0;
                load_power = 200000; % Default to 200kW
                price = 0.7; % Default to 0.7 CNY/kWh
            end
            
            obs = [double(pv_power/1000); double(load_power/1000); double(this.SOC);
                   double(this.SOH); double(price); double(1); double(1)];
        end
        
        function summary = getEnvironmentSummary(this)
            % Generate a summary of the environment's performance (for analysis)
            
            summary = struct();
            summary.total_steps = this.TimeStep - 1;
            summary.simulation_days = summary.total_steps / 24;
            summary.final_soc = this.SOC;
            summary.final_soh = this.SOH;
            summary.soh_degradation = this.SystemParams.soh_initial - this.SOH;
            summary.total_energy_traded_kwh = this.TotalEnergyTraded;
            summary.total_cost_cny = this.TotalCost;
            summary.equivalent_cycles = this.CycleCount;
            
            if ~isempty(this.RewardHistory)
                summary.total_reward = sum(this.RewardHistory);
                summary.average_reward = mean(this.RewardHistory);
                summary.reward_std_dev = std(this.RewardHistory);
            end
            
            if ~isempty(this.StateHistory)
                summary.soc_mean = mean(this.StateHistory(3, :));
                summary.soc_std_dev = std(this.StateHistory(3, :));
                summary.soc_min = min(this.StateHistory(3, :));
                summary.soc_max = max(this.StateHistory(3, :));
            end
        end
        
        function exportData(this, filename)
            % Export all environment data to a .mat file for later analysis
            
            if nargin < 2
                timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
                filename = sprintf('research_environment_data_%s.mat', timestamp);
            end
            
            % Consolidate all data into a single struct for export
            export_data = struct();
            export_data.config = this.Config;
            export_data.system_params = this.SystemParams;
            export_data.state_history = this.StateHistory;
            export_data.action_history = this.ActionHistory;
            export_data.reward_history = this.RewardHistory;
            export_data.summary = this.getEnvironmentSummary();
            export_data.data_source = this.Data;
            
            save(filename, 'export_data');
            fprintf('INFO: Environment data successfully exported to: %s\n', filename);
        end
    end
end
