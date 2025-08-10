classdef Microgrid30DayEnvironment < rl.env.MATLABEnvironment
    % MICROGRID30DAYENVIRONMENT - 30天物理世界微电网仿真环境
    % 
    % 特性:
    % - 30天完整物理仿真
    % - 真实的电池退化模型
    % - 季节性和天气变化
    % - 长期经济优化
    
    properties
        % 环境状态
        SOC = 0.5;          % 电池SOC
        SOH = 1.0;          % 电池SOH
        TimeStep = 1;       % 当前时间步
        DayOfYear = 1;      % 年中的天数
        
        % 系统参数 (基于Integrated文件夹的成功配置)
        BatteryCapacity = 100 * 1000 * 3600;  % 100 kWh in Wh
        BatteryPowerRating = 500 * 1000;      % 500 kW in W
        BatteryEfficiency = 0.96;             % 96% 效率
        
        % 长期退化参数
        SOHDegradationRate = 1e-6;            % 每次循环的SOH退化率
        CycleCounting = 0;                    % 循环计数
        TemperatureEffect = 1.0;              % 温度影响因子
        
        % 经济参数
        CostPerAhLoss = 0.25;                 % 电池退化成本
        GridConnectionCost = 0.05;            % 电网连接成本
        
        % 数据
        PVData
        LoadData
        PriceData
        SimulationConfig
        
        % 长期统计
        TotalEnergyTraded = 0;                % 总交易能量
        TotalCost = 0;                        % 总成本
        MaxSOCReached = 0.5;                  % 达到的最大SOC
        MinSOCReached = 0.5;                  % 达到的最小SOC
    end
    
    methods
        function this = Microgrid30DayEnvironment(obs_info, action_info, simulation_config)
            % 构造函数
            this = this@rl.env.MATLABEnvironment(obs_info, action_info);
            
            % 保存配置
            this.SimulationConfig = simulation_config;
            
            % 加载30天数据
            this.PVData = evalin('base', 'pv_power_profile');
            this.LoadData = evalin('base', 'load_power_profile');
            this.PriceData = evalin('base', 'price_profile');
            
            % 验证数据长度
            expected_length = simulation_config.simulation.simulation_days * 24;
            if length(this.PVData.Data) < expected_length
                warning('数据长度不足30天，将循环使用现有数据');
            end
        end
        
        function [obs, reward, is_done, info] = step(this, action)
            % 环境步进 - 30天物理仿真版本
            
            % 获取当前时间的外部输入
            current_hour = mod(this.TimeStep - 1, 24) + 1;
            current_day = floor((this.TimeStep - 1) / 24) + 1;
            this.DayOfYear = mod(current_day - 1, 365) + 1;
            
            % 获取数据（循环使用如果数据不足）
            data_index = mod(this.TimeStep - 1, length(this.PVData.Data)) + 1;
            pv_power = this.PVData.Data(data_index) * 1000;  % W
            load_power = this.LoadData.Data(data_index) * 1000;  % W
            price = this.PriceData.Data(data_index);
            
            % 季节性调整
            seasonal_factor = this.getSeasonalFactor(this.DayOfYear);
            pv_power = pv_power * seasonal_factor.pv;
            load_power = load_power * seasonal_factor.load;
            
            % 电池动作处理
            battery_power = action;  % W
            battery_power = max(-this.BatteryPowerRating, min(this.BatteryPowerRating, battery_power));
            
            % SOC更新（考虑效率）
            dt = 1;  % 1小时
            if battery_power > 0  % 充电
                energy_change = battery_power * dt * this.BatteryEfficiency;
            else  % 放电
                energy_change = battery_power * dt / this.BatteryEfficiency;
            end
            
            new_soc = this.SOC + energy_change / this.BatteryCapacity;
            new_soc = max(0.1, min(0.9, new_soc));
            
            % 更新统计
            this.MaxSOCReached = max(this.MaxSOCReached, new_soc);
            this.MinSOCReached = min(this.MinSOCReached, new_soc);
            
            % SOH更新（长期退化模型）
            % 基于循环深度和温度的退化
            cycle_depth = abs(new_soc - this.SOC);
            temperature_stress = this.getTemperatureStress(current_day);
            
            soh_degradation = this.SOHDegradationRate * cycle_depth * temperature_stress;
            new_soh = max(0.5, this.SOH - soh_degradation);
            
            % 循环计数
            if cycle_depth > 0.01  % 只有显著的SOC变化才计数
                this.CycleCounting = this.CycleCounting + cycle_depth;
            end
            
            % 电网功率计算
            grid_power = load_power - pv_power - battery_power;
            
            % 长期奖励函数设计
            % 1. 经济成本
            economic_cost = abs(grid_power) * price * dt / 1000;  % 电费成本
            
            % 2. 电池退化成本（长期考虑）
            battery_degradation_cost = soh_degradation * this.BatteryCapacity / 1000 * this.CostPerAhLoss;
            
            % 3. 电网连接成本
            grid_connection_cost = abs(grid_power) * this.GridConnectionCost * dt / 1000;
            
            % 4. SOC管理奖励（鼓励保持合理SOC）
            soc_management_reward = 0;
            if new_soc > 0.2 && new_soc < 0.8
                soc_management_reward = 5; % 奖励保持在合理范围
            end
            
            % 5. 长期稳定性奖励
            stability_reward = 0;
            if this.TimeStep > 24  % 一天后开始计算
                soc_variance = (new_soc - 0.5)^2;
                stability_reward = -soc_variance * 10; % 惩罚SOC波动过大
            end
            
            % 6. 能源自给自足奖励
            self_sufficiency_reward = 0;
            if abs(grid_power) < 0.1 * load_power  % 电网功率小于负载的10%
                self_sufficiency_reward = 10;
            end
            
            % 总奖励
            reward = -(economic_cost + battery_degradation_cost + grid_connection_cost) ...
                     + soc_management_reward + stability_reward + self_sufficiency_reward;
            
            % 更新状态
            this.SOC = new_soc;
            this.SOH = new_soh;
            this.TimeStep = this.TimeStep + 1;
            this.TotalEnergyTraded = this.TotalEnergyTraded + abs(grid_power) * dt / 1000;
            this.TotalCost = this.TotalCost + economic_cost;
            
            % 构建观测
            obs = [pv_power/1000; load_power/1000; new_soc; new_soh; price; current_hour; current_day];
            
            % 终止条件（30天或SOH过低）
            is_done = (this.TimeStep > 24 * 30) || (new_soh < 0.6);
            
            % 详细信息
            info = struct(...
                'grid_power', grid_power, ...
                'economic_cost', economic_cost, ...
                'battery_degradation_cost', battery_degradation_cost, ...
                'soc_management_reward', soc_management_reward, ...
                'stability_reward', stability_reward, ...
                'self_sufficiency_reward', self_sufficiency_reward, ...
                'cycle_counting', this.CycleCounting, ...
                'total_energy_traded', this.TotalEnergyTraded, ...
                'total_cost', this.TotalCost);
        end
        
        function obs = reset(this)
            % 环境重置
            
            % 重置状态（随机化初始条件）
            this.SOC = 0.3 + rand() * 0.5;  % 30%-80%
            this.SOH = 0.95 + rand() * 0.05; % 95%-100%
            this.TimeStep = 1;
            this.DayOfYear = randi(365); % 随机起始日期
            
            % 重置统计
            this.CycleCounting = 0;
            this.TotalEnergyTraded = 0;
            this.TotalCost = 0;
            this.MaxSOCReached = this.SOC;
            this.MinSOCReached = this.SOC;
            
            % 构建初始观测
            data_index = 1;
            pv_power = this.PVData.Data(data_index) * 1000;  % W
            load_power = this.LoadData.Data(data_index) * 1000;  % W
            price = this.PriceData.Data(data_index);
            
            obs = [pv_power/1000; load_power/1000; this.SOC; this.SOH; price; 1; 1];
        end
        
        function seasonal_factor = getSeasonalFactor(~, day_of_year)
            % 获取季节性调整因子
            
            % PV季节性变化（夏季高，冬季低）
            pv_seasonal = 0.8 + 0.4 * sin(2*pi*(day_of_year-80)/365);
            
            % 负载季节性变化（夏季和冬季高，春秋低）
            load_seasonal = 0.9 + 0.2 * abs(sin(2*pi*(day_of_year-80)/365));
            
            seasonal_factor = struct('pv', pv_seasonal, 'load', load_seasonal);
        end
        
        function temp_stress = getTemperatureStress(~, day_of_year)
            % 获取温度应力因子（影响电池退化）
            
            % 简化的温度模型：夏季高温增加退化
            base_temp = 25; % 基准温度 °C
            temp_variation = 15 * sin(2*pi*(day_of_year-80)/365); % ±15°C变化
            current_temp = base_temp + temp_variation;
            
            % 温度应力：高温增加退化
            if current_temp > 30
                temp_stress = 1 + (current_temp - 30) * 0.05;
            else
                temp_stress = 1;
            end
        end
    end
end
