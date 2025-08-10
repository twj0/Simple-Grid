classdef MicrogridEnvironment < rl.env.MATLABEnvironment
    % MICROGRIDENVIRONMENT - ΢����ǿ��ѧϰ����
    % 
    % ʹ��MATLAB��ʵ�ֵ�΢��������������Simulink����
    
    properties
        % ����״̬
        SOC = 0.5;          % ���SOC
        SOH = 1.0;          % ���SOH
        TimeStep = 1;       % ��ǰʱ�䲽
        
        % ϵͳ����
        BatteryCapacity = 100 * 1000 * 3600;  % 100 kWh in Wh
        BatteryPowerRating = 500 * 1000;      % 500 kW in W
        
        % ����
        PVData
        LoadData
        PriceData
    end
    
    methods
        function this = MicrogridEnvironment(obs_info, action_info)
            % ���캯��
            this = this@rl.env.MATLABEnvironment(obs_info, action_info);
            
            % ��������
            this.PVData = evalin('base', 'pv_power_profile');
            this.LoadData = evalin('base', 'load_power_profile');
            this.PriceData = evalin('base', 'price_profile');
        end
        
        function [obs, reward, is_done, info] = step(this, action)
            % ��������
            
            % ��ȡ��ǰʱ����ⲿ����
            current_hour = mod(this.TimeStep - 1, 24) + 1;
            current_day = floor((this.TimeStep - 1) / 24) + 1;
            
            pv_power = this.PVData.Data(min(current_hour, length(this.PVData.Data))) * 1000;  % W
            load_power = this.LoadData.Data(min(current_hour, length(this.LoadData.Data))) * 1000;  % W
            price = this.PriceData.Data(min(current_hour, length(this.PriceData.Data)));
            
            % ��ض�������
            battery_power = action;  % W
            battery_power = max(-this.BatteryPowerRating, min(this.BatteryPowerRating, battery_power));
            
            % SOC����
            dt = 1;  % 1Сʱ
            efficiency = 0.95;
            if battery_power > 0  % ���
                energy_change = battery_power * dt * efficiency;
            else  % �ŵ�
                energy_change = battery_power * dt / efficiency;
            end
            
            new_soc = this.SOC + energy_change / this.BatteryCapacity;
            new_soc = max(0.1, min(0.9, new_soc));
            
            % SOH����
            soh_degradation = abs(battery_power) / this.BatteryPowerRating * 0.0001;
            new_soh = max(0.5, this.SOH - soh_degradation);
            
            % ��������
            grid_power = load_power - pv_power - battery_power;
            
            % ��������
            economic_cost = abs(grid_power) * price * dt / 1000;
            soh_penalty = (1 - new_soh) * 100;
            soc_penalty = 0;
            if new_soc < 0.2 || new_soc > 0.8
                soc_penalty = 10;
            end
            
            reward = -(economic_cost + soh_penalty + soc_penalty);
            
            % ����״̬
            this.SOC = new_soc;
            this.SOH = new_soh;
            this.TimeStep = this.TimeStep + 1;
            
            % �����۲�
            obs = [pv_power/1000; load_power/1000; new_soc; new_soh; price; current_hour; current_day];
            
            % ��ֹ����
            is_done = (this.TimeStep > 24) || (new_soh < 0.6);
            
            % ��Ϣ
            info = struct('grid_power', grid_power, 'economic_cost', economic_cost);
        end
        
        function obs = reset(this)
            % ��������
            
            % ����״̬
            this.SOC = 0.3 + rand() * 0.5;  % 30%-80%
            this.SOH = 1.0;
            this.TimeStep = 1;
            
            % ������ʼ�۲�
            pv_power = this.PVData.Data(1) * 1000;  % W
            load_power = this.LoadData.Data(1) * 1000;  % W
            price = this.PriceData.Data(1);
            
            obs = [pv_power/1000; load_power/1000; this.SOC; this.SOH; price; 1; 1];
        end
    end
end
