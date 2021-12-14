function [command_Outlet, EEG_Inlet] = LSL_Init(params)
%% LSL_Init initializes the relevant LSL classes and functions needed to 
% create an EEG inlet and Command outlet. 

fprintf('Loading the Lab Streaming Layer library...');
lib = lsl_loadlib();
% Initialize the command outlet marker stream
fprintf('Opening Output Stream...');
info = lsl_streaminfo(lib,'MarkerStream','Markers',1,0,'cf_string','asafMIuniqueID123123');
command_Outlet = lsl_outlet(info);
% Initialize the EEG inlet stream (from DSI2LSL/openBCI on different system)
fprintf('Resolving an EEG Stream...');
result = {};
lslTimer = tic;
while isempty(result) && toc(lslTimer) < params.resolveTime % FIXME add some stopping condition
    result = lsl_resolve_byprop(lib,'type','EEG'); 
end
fprintf('Success resolving!');
EEG_Inlet = lsl_inlet(result{1});

end