function [env, obs_info, action_info] = create_simple_matlab_environment()
% CREATE_SIMPLE_MATLAB_ENVIRONMENT - 创建简化的MATLAB环境
% 
% 使用简单的MATLAB函数实现微电网环境，避免Simulink依赖

fprintf('创建简化的MATLAB环境...\n');

%% 加载配置和数据
model_cfg = model_config();

if ~load_workspace_data()
    fprintf('生成新的工作空间数据...\n');
    [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(model_cfg);
    assignin('base', 'pv_profile', pv_profile);
    assignin('base', 'load_profile', load_profile);
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

%% 创建环境
env = MicrogridEnvironment(obs_info, action_info);

fprintf('? 简化MATLAB环境创建成功\n');

end
