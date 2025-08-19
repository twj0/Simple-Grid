classdef MicrogridEnvironment < rl.env.MATLABEnvironment
    % MICROGRIDENVIRONMENT - A Reinforcement Learning Environment for Microgrids
    %
    % This class implements a microgrid environment in MATLAB, providing a
    % simplified, non-Simulink alternative for DRL experiments.
    
    properties
        % System State
        SOC = 0.5;          % State of Charge (0 to 1)
        SOH = 1.0;          % State of Health (0 to 1)
        TimeStep = 1;       % Current simulation time step (hour)
        
        % System Parameters
        BatteryCapacity = 100 * 1000 * 3600;  % Battery capacity in Watt-hours (100 kWh)
        BatteryPowerRating = 500 * 1000;      % Maximum battery power in Watts (500 kW)
        
        % Input Data Profiles
        PVData              % Timeseries object for PV power profile (kW)
        LoadData            % Timeseries object for Load power profile (kW)
        PriceData           % Timeseries object for Electricity price profile (CNY/kWh)
    end
    
    methods
        function this = MicrogridEnvironment(obs_info, action_info)
            % Constructor
            this = this@rl.env.MATLABEnvironment(obs_info, action_info);
            
            % Load data from the base workspace
            % Ensure that 'pv_power_profile', 'load_power_profile', and 'price_profile'
            % are loaded into the workspace before creating the environment.
            this.PVData = evalin('base', 'pv_power_profile');
            this.LoadData = evalin('base', 'load_power_profile');
            this.PriceData = evalin('base', 'price_profile');
        end
        
        function [obs, reward, is_done, info] = step(this, action)
            % Execute one time step within the environment
            
            % Get current external conditions
            current_hour = mod(this.TimeStep - 1, 24) + 1;
            current_day = floor((this.TimeStep - 1) / 24) + 1;
            
            pv_power = this.PVData.Data(min(current_hour, length(this.PVData.Data))) * 1000;  % Convert kW to W
            load_power = this.LoadData.Data(min(current_hour, length(this.LoadData.Data))) * 1000; % Convert kW to W
            price = this.PriceData.Data(min(current_hour, length(this.PriceData.Data))); % CNY/kWh
            
            % Constrain battery power action
            battery_power = max(-this.BatteryPowerRating, min(this.BatteryPowerRating, action)); % Action is in Watts
            
            % Update State of Charge (SOC)
            dt_hours = 1; % Time step is 1 hour
            efficiency = 0.95;
            if battery_power > 0 % Charging
                energy_change = battery_power * dt_hours * efficiency;
            else % Discharging
                energy_change = battery_power * dt_hours / efficiency;
            end
            
            new_soc = this.SOC + energy_change / this.BatteryCapacity;
            new_soc = max(0.1, min(0.9, new_soc)); % Enforce SOC limits (10% to 90%)
            
            % Update State of Health (SOH)
            % Simplified degradation model based on power throughput
            soh_degradation = abs(battery_power) / this.BatteryPowerRating * 0.0001;
            new_soh = max(0.5, this.SOH - soh_degradation); % Enforce SOH lower limit
            
            % Calculate grid power exchange
            grid_power = load_power - pv_power - battery_power; % W
            
            % Calculate reward components
            economic_cost = abs(grid_power) * price * dt_hours / 1000; % Cost in CNY
            soh_penalty = (1 - new_soh) * 100; % Penalize health degradation
            soc_penalty = 0;
            if new_soc < 0.2 || new_soc > 0.8 % Penalize extreme SOC values
                soc_penalty = 10;
            end
            
            reward = -(economic_cost + soh_penalty + soc_penalty); % Total reward is negative cost
            
            % Update internal state
            this.SOC = new_soc;
            this.SOH = new_soh;
            this.TimeStep = this.TimeStep + 1;
            
            % Formulate next observation
            obs = [pv_power/1000; load_power/1000; new_soc; new_soh; price; current_hour; current_day];
            
            % Check for termination condition
            is_done = (this.TimeStep > 24) || (new_soh < 0.6); % End episode after 24 hours or if SOH is too low
            
            % Return additional information
            info = struct('grid_power', grid_power, 'economic_cost', economic_cost);
        end
        
        function obs = reset(this)
            % Reset the environment to an initial state
            
            % Randomize initial state for better training generalization
            this.SOC = 0.3 + rand() * 0.5;  % Random SOC between 30% and 80%
            this.SOH = 1.0;                 % Reset SOH to full health
            this.TimeStep = 1;              % Reset time to the first step
            
            % Get initial observation
            pv_power = this.PVData.Data(1) * 1000;   % W
            load_power = this.LoadData.Data(1) * 1000; % W
            price = this.PriceData.Data(1);
            
            obs = [pv_power/1000; load_power/1000; this.SOC; this.SOH; price; 1; 1];
        end
    end
end
