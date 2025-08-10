function [env, obs_info, action_info] = create_30day_simulation_environment(simulation_config)
% CREATE_30DAY_SIMULATION_ENVIRONMENT - ����30��������滷��
% 
% ����MicrogridEnvironment�࣬���Ż�Ϊ30�쳤�ڷ���
% ��������ʵ������ģ�ͳ���ЧӦ

fprintf('����30��������滷��...\n');

%% �������ú�����
if nargin < 1
    simulation_config = model_config();
    simulation_config.simulation.simulation_days = 30;
end

% ȷ��30�����ݴ���
if ~load_workspace_data()
    fprintf('����30���������...\n');
    [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(simulation_config);
    assignin('base', 'pv_power_profile', pv_profile);
    assignin('base', 'load_power_profile', load_profile);
    assignin('base', 'price_profile', price_profile);
end

%% ����۲�Ͷ����ռ�
obs_info = rlNumericSpec([7 1]);
obs_info.Name = 'Microgrid State';
obs_info.LowerLimit = [0; 0; 0.1; 0.5; 0; 1; 1];
obs_info.UpperLimit = [1000; 1000; 0.9; 1; 2; 24; 365];

action_info = rlNumericSpec([1 1]);
action_info.Name = 'Battery Power Command';
action_info.LowerLimit = -500000;  % -500 kW
action_info.UpperLimit = 500000;   % +500 kW

%% ����30����滷��
env = Microgrid30DayEnvironment(obs_info, action_info, simulation_config);

fprintf('? 30��������滷�������ɹ�\n');

end


