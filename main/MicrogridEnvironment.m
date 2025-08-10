classdef MicrogridEnvironment < rl.env.MATLABEnvironment
    % MICROGRIDENVIRONMENT - 微电网强化学习环境
    % 
    % 使用MATLAB类实现的微电网环境，避免Simulink依赖
    
    properties
        % 环境状态
        SOC = 0.5;          % 电池SOC
        SOH = 1.0;          % 电池SOH
        TimeStep = 1;       % 当前时间步
        
        % 系统参数
        BatteryCapacity = 100 * 1000 * 3600;  % 100 kWh in Wh
        BatteryPowerRating = 500 * 1000;      % 500 kW in W
        
        % 数据
        PVData
        LoadData
        PriceData
    end
    
    methods
        function this = MicrogridEnvironment(obs_info, action_info)
            % 构造函数
            this = this@rl.env.MATLABEnvironment(obs_info, action_info);
            
            % 加载数据
            this.PVData = evalin('base', 'pv_power_profile');
            this.LoadData = evalin('base', 'load_power_profile');
            this.PriceData = evalin('base', 'price_profile');
        end
        
        function [obs, reward, is_done, info] = step(this, action)
            % 环境步进
            
            % 获取当前时间的外部输入
            current_hour = mod(this.TimeStep - 1, 24) + 1;
            current_day = floor((this.TimeStep - 1) / 24) + 1;
            
            pv_power = this.PVData.Data(min(current_hour, length(this.PVData.Data))) * 1000;  % W
            load_power = this.LoadData.Data(min(current_hour, length(this.LoadData.Data))) * 1000;  % W
            price = this.PriceData.Data(min(current_hour, length(this.PriceData.Data)));
            
            % 电池动作处理
            battery_power = action;  % W
            battery_power = max(-this.BatteryPowerRating, min(this.BatteryPowerRating, battery_power));
            
            % SOC更新
            dt = 1;  % 1小时
            efficiency = 0.95;
            if battery_power > 0  % 充电
                energy_change = battery_power * dt * efficiency;
            else  % 放电
                energy_change = battery_power * dt / efficiency;
            end
            
            new_soc = this.SOC + energy_change / this.BatteryCapacity;
            new_soc = max(0.1, min(0.9, new_soc));
            
            % SOH更新
            soh_degradation = abs(battery_power) / this.BatteryPowerRating * 0.0001;
            new_soh = max(0.5, this.SOH - soh_degradation);
            
            % 电网功率
            grid_power = load_power - pv_power - battery_power;
            
            % 奖励计算
            economic_cost = abs(grid_power) * price * dt / 1000;
            soh_penalty = (1 - new_soh) * 100;
            soc_penalty = 0;
            if new_soc < 0.2 || new_soc > 0.8
                soc_penalty = 10;
            end
            
            reward = -(economic_cost + soh_penalty + soc_penalty);
            
            % 更新状态
            this.SOC = new_soc;
            this.SOH = new_soh;
            this.TimeStep = this.TimeStep + 1;
            
            % 构建观测
            obs = [pv_power/1000; load_power/1000; new_soc; new_soh; price; current_hour; current_day];
            
            % 终止条件
            is_done = (this.TimeStep > 24) || (new_soh < 0.6);
            
            % 信息
            info = struct('grid_power', grid_power, 'economic_cost', economic_cost);
        end
        
        function obs = reset(this)
            % 环境重置
            
            % 重置状态
            this.SOC = 0.3 + rand() * 0.5;  % 30%-80%
            this.SOH = 1.0;
            this.TimeStep = 1;
            
            % 构建初始观测
            pv_power = this.PVData.Data(1) * 1000;  % W
            load_power = this.LoadData.Data(1) * 1000;  % W
            price = this.PriceData.Data(1);
            
            obs = [pv_power/1000; load_power/1000; this.SOC; this.SOH; price; 1; 1];
        end
    end
end
