function [env, obs_info, action_info] = create_30day_simulation_environment(simulation_config)
% CREATE_30DAY_SIMULATION_ENVIRONMENT - 创建30天物理仿真环境
% 
% 基于MicrogridEnvironment类，但优化为30天长期仿真
% 包含更真实的物理建模和长期效应

fprintf('创建30天物理仿真环境...\n');

%% 加载配置和数据
if nargin < 1
    simulation_config = model_config();
    simulation_config.simulation.simulation_days = 30;
end

% 确保30天数据存在
if ~load_workspace_data()
    fprintf('生成30天仿真数据...\n');
    [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(simulation_config);
    assignin('base', 'pv_power_profile', pv_profile);
    assignin('base', 'load_power_profile', load_profile);
    assignin('base', 'price_profile', price_profile);
end

%% 定义观测和动作空间
obs_info = rlNumericSpec([7 1]);
obs_info.Name = 'Microgrid State';
obs_info.LowerLimit = [0; 0; 0.1; 0.5; 0; 1; 1];
obs_info.UpperLimit = [1000; 1000; 0.9; 1; 2; 24; 365];

action_info = rlNumericSpec([1 1]);
action_info.Name = 'Battery Power Command';
action_info.LowerLimit = -500000;  % -500 kW
action_info.UpperLimit = 500000;   % +500 kW

%% 创建30天仿真环境
env = Microgrid30DayEnvironment(obs_info, action_info, simulation_config);

fprintf('? 30天物理仿真环境创建成功\n');

end


