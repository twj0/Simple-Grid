function [env, obs_info, action_info] = create_simple_matlab_environment()
% CREATE_SIMPLE_MATLAB_ENVIRONMENT - �����򻯵�MATLAB����
% 
% ʹ�ü򵥵�MATLAB����ʵ��΢��������������Simulink����

fprintf('�����򻯵�MATLAB����...\n');

%% �������ú�����
model_cfg = model_config();

if ~load_workspace_data()
    fprintf('�����µĹ����ռ�����...\n');
    [pv_profile, load_profile, price_profile] = generate_microgrid_profiles(model_cfg);
    assignin('base', 'pv_profile', pv_profile);
    assignin('base', 'load_profile', load_profile);
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

%% ��������
env = MicrogridEnvironment(obs_info, action_info);

fprintf('? ��MATLAB���������ɹ�\n');

end
