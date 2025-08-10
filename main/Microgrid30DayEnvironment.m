classdef Microgrid30DayEnvironment < rl.env.MATLABEnvironment
    % MICROGRID30DAYENVIRONMENT - 30����������΢�������滷��
    % 
    % ����:
    % - 30�������������
    % - ��ʵ�ĵ���˻�ģ��
    % - �����Ժ������仯
    % - ���ھ����Ż�
    
    properties
        % ����״̬
        SOC = 0.5;          % ���SOC
        SOH = 1.0;          % ���SOH
        TimeStep = 1;       % ��ǰʱ�䲽
        DayOfYear = 1;      % ���е�����
        
        % ϵͳ���� (����Integrated�ļ��еĳɹ�����)
        BatteryCapacity = 100 * 1000 * 3600;  % 100 kWh in Wh
        BatteryPowerRating = 500 * 1000;      % 500 kW in W
        BatteryEfficiency = 0.96;             % 96% Ч��
        
        % �����˻�����
        SOHDegradationRate = 1e-6;            % ÿ��ѭ����SOH�˻���
        CycleCounting = 0;                    % ѭ������
        TemperatureEffect = 1.0;              % �¶�Ӱ������
        
        % ���ò���
        CostPerAhLoss = 0.25;                 % ����˻��ɱ�
        GridConnectionCost = 0.05;            % �������ӳɱ�
        
        % ����
        PVData
        LoadData
        PriceData
        SimulationConfig
        
        % ����ͳ��
        TotalEnergyTraded = 0;                % �ܽ�������
        TotalCost = 0;                        % �ܳɱ�
        MaxSOCReached = 0.5;                  % �ﵽ�����SOC
        MinSOCReached = 0.5;                  % �ﵽ����СSOC
    end
    
    methods
        function this = Microgrid30DayEnvironment(obs_info, action_info, simulation_config)
            % ���캯��
            this = this@rl.env.MATLABEnvironment(obs_info, action_info);
            
            % ��������
            this.SimulationConfig = simulation_config;
            
            % ����30������
            this.PVData = evalin('base', 'pv_power_profile');
            this.LoadData = evalin('base', 'load_power_profile');
            this.PriceData = evalin('base', 'price_profile');
            
            % ��֤���ݳ���
            expected_length = simulation_config.simulation.simulation_days * 24;
            if length(this.PVData.Data) < expected_length
                warning('���ݳ��Ȳ���30�죬��ѭ��ʹ����������');
            end
        end
        
        function [obs, reward, is_done, info] = step(this, action)
            % �������� - 30���������汾
            
            % ��ȡ��ǰʱ����ⲿ����
            current_hour = mod(this.TimeStep - 1, 24) + 1;
            current_day = floor((this.TimeStep - 1) / 24) + 1;
            this.DayOfYear = mod(current_day - 1, 365) + 1;
            
            % ��ȡ���ݣ�ѭ��ʹ��������ݲ��㣩
            data_index = mod(this.TimeStep - 1, length(this.PVData.Data)) + 1;
            pv_power = this.PVData.Data(data_index) * 1000;  % W
            load_power = this.LoadData.Data(data_index) * 1000;  % W
            price = this.PriceData.Data(data_index);
            
            % �����Ե���
            seasonal_factor = this.getSeasonalFactor(this.DayOfYear);
            pv_power = pv_power * seasonal_factor.pv;
            load_power = load_power * seasonal_factor.load;
            
            % ��ض�������
            battery_power = action;  % W
            battery_power = max(-this.BatteryPowerRating, min(this.BatteryPowerRating, battery_power));
            
            % SOC���£�����Ч�ʣ�
            dt = 1;  % 1Сʱ
            if battery_power > 0  % ���
                energy_change = battery_power * dt * this.BatteryEfficiency;
            else  % �ŵ�
                energy_change = battery_power * dt / this.BatteryEfficiency;
            end
            
            new_soc = this.SOC + energy_change / this.BatteryCapacity;
            new_soc = max(0.1, min(0.9, new_soc));
            
            % ����ͳ��
            this.MaxSOCReached = max(this.MaxSOCReached, new_soc);
            this.MinSOCReached = min(this.MinSOCReached, new_soc);
            
            % SOH���£������˻�ģ�ͣ�
            % ����ѭ����Ⱥ��¶ȵ��˻�
            cycle_depth = abs(new_soc - this.SOC);
            temperature_stress = this.getTemperatureStress(current_day);
            
            soh_degradation = this.SOHDegradationRate * cycle_depth * temperature_stress;
            new_soh = max(0.5, this.SOH - soh_degradation);
            
            % ѭ������
            if cycle_depth > 0.01  % ֻ��������SOC�仯�ż���
                this.CycleCounting = this.CycleCounting + cycle_depth;
            end
            
            % �������ʼ���
            grid_power = load_power - pv_power - battery_power;
            
            % ���ڽ����������
            % 1. ���óɱ�
            economic_cost = abs(grid_power) * price * dt / 1000;  % ��ѳɱ�
            
            % 2. ����˻��ɱ������ڿ��ǣ�
            battery_degradation_cost = soh_degradation * this.BatteryCapacity / 1000 * this.CostPerAhLoss;
            
            % 3. �������ӳɱ�
            grid_connection_cost = abs(grid_power) * this.GridConnectionCost * dt / 1000;
            
            % 4. SOC���������������ֺ���SOC��
            soc_management_reward = 0;
            if new_soc > 0.2 && new_soc < 0.8
                soc_management_reward = 5; % ���������ں���Χ
            end
            
            % 5. �����ȶ��Խ���
            stability_reward = 0;
            if this.TimeStep > 24  % һ���ʼ����
                soc_variance = (new_soc - 0.5)^2;
                stability_reward = -soc_variance * 10; % �ͷ�SOC��������
            end
            
            % 6. ��Դ�Ը����㽱��
            self_sufficiency_reward = 0;
            if abs(grid_power) < 0.1 * load_power  % ��������С�ڸ��ص�10%
                self_sufficiency_reward = 10;
            end
            
            % �ܽ���
            reward = -(economic_cost + battery_degradation_cost + grid_connection_cost) ...
                     + soc_management_reward + stability_reward + self_sufficiency_reward;
            
            % ����״̬
            this.SOC = new_soc;
            this.SOH = new_soh;
            this.TimeStep = this.TimeStep + 1;
            this.TotalEnergyTraded = this.TotalEnergyTraded + abs(grid_power) * dt / 1000;
            this.TotalCost = this.TotalCost + economic_cost;
            
            % �����۲�
            obs = [pv_power/1000; load_power/1000; new_soc; new_soh; price; current_hour; current_day];
            
            % ��ֹ������30���SOH���ͣ�
            is_done = (this.TimeStep > 24 * 30) || (new_soh < 0.6);
            
            % ��ϸ��Ϣ
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
            % ��������
            
            % ����״̬���������ʼ������
            this.SOC = 0.3 + rand() * 0.5;  % 30%-80%
            this.SOH = 0.95 + rand() * 0.05; % 95%-100%
            this.TimeStep = 1;
            this.DayOfYear = randi(365); % �����ʼ����
            
            % ����ͳ��
            this.CycleCounting = 0;
            this.TotalEnergyTraded = 0;
            this.TotalCost = 0;
            this.MaxSOCReached = this.SOC;
            this.MinSOCReached = this.SOC;
            
            % ������ʼ�۲�
            data_index = 1;
            pv_power = this.PVData.Data(data_index) * 1000;  % W
            load_power = this.LoadData.Data(data_index) * 1000;  % W
            price = this.PriceData.Data(data_index);
            
            obs = [pv_power/1000; load_power/1000; this.SOC; this.SOH; price; 1; 1];
        end
        
        function seasonal_factor = getSeasonalFactor(~, day_of_year)
            % ��ȡ�����Ե�������
            
            % PV�����Ա仯���ļ��ߣ������ͣ�
            pv_seasonal = 0.8 + 0.4 * sin(2*pi*(day_of_year-80)/365);
            
            % ���ؼ����Ա仯���ļ��Ͷ����ߣ�����ͣ�
            load_seasonal = 0.9 + 0.2 * abs(sin(2*pi*(day_of_year-80)/365));
            
            seasonal_factor = struct('pv', pv_seasonal, 'load', load_seasonal);
        end
        
        function temp_stress = getTemperatureStress(~, day_of_year)
            % ��ȡ�¶�Ӧ�����ӣ�Ӱ�����˻���
            
            % �򻯵��¶�ģ�ͣ��ļ����������˻�
            base_temp = 25; % ��׼�¶� ��C
            temp_variation = 15 * sin(2*pi*(day_of_year-80)/365); % ��15��C�仯
            current_temp = base_temp + temp_variation;
            
            % �¶�Ӧ�������������˻�
            if current_temp > 30
                temp_stress = 1 + (current_temp - 30) * 0.05;
            else
                temp_stress = 1;
            end
        end
    end
end
