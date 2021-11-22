function taskdata = imensa_0
%% default setting
testmode = false;
savedir = fullfile(pwd, 'data');
addpath(genpath(pwd));

%% SETUP: global
global theWindow W H; % window property
global white red orange blue bgcolor; % color
global fontsize window_rect wordT cqT ; % rating scale

%% SETUP: Screen


if testmode
    window_rect = [0 0 1280 800]; % in the test mode, use a little smaller screen
else
    screens = Screen('Screens');
    window_num = screens(end);
    Screen('Preference', 'SkipSyncTests', 1);
    window_info = Screen('Resolution', window_num);
    window_rect = [0 0 window_info.width window_info.height]; %0 0 1920 1080
end

W = window_rect(3); %width of screen
H = window_rect(4); %height of screen
textH = H/2.3;

fontsize = 30;

bgcolor = 100;
white = 255;
red = [189 0 38];
blue = [0 85 169];
orange = [255 164 0];

wordT = 3;     % duration for showing target words
cqT = 8;        % duration for question of concentration

    %% START: Screen
    theWindow = Screen('OpenWindow', window_num, bgcolor, window_rect); % start the screen
%     Screen('Preference','TextEncodingLocale','ko_KR.UTF-8');
%     Screen('TextFont', theWindow, font);
    Screen('TextSize', theWindow, fontsize);
    HideCursor;
    

%% TASK START

try
    %% PROMPT SETUP:
    ready_prompt = double('scanning starts (s).');
    run_end_prompt = double('run is ended');
        
    %% WAITING FOR INPUT FROM THE SCANNER
    while (1)
        [~,~,keyCode] = KbCheck;
        
        if keyCode(KbName('s'))==1
            break
        elseif keyCode(KbName('q'))==1
            abort_experiment('manual');
        end
        
        Screen(theWindow, 'FillRect', bgcolor, window_rect);
        DrawFormattedText(theWindow, ready_prompt,'center', textH, white);
        Screen('Flip', theWindow);
    end
    
    %% FOR DISDAQ 10 SECONDS
    
    % gap between 's' key push and the first stimuli (disdaqs: data.disdaq_sec)
    taskdata.runscan_starttime = GetSecs; % run start timestamp
    Screen(theWindow, 'FillRect', bgcolor, window_rect);
    DrawFormattedText(theWindow, double('getting started...'), 'center', 'center', white, [], [], [], 1.2);
    Screen('Flip', theWindow);
    waitsec_fromstarttime(taskdata.runscan_starttime, 4);
    
    % Blank
    Screen(theWindow,'FillRect',bgcolor, window_rect);
    Screen('Flip', theWindow);
    
    
    %% MAIN TASK 1. SHOW 2 WORDS, WORD PROMPT
    ts{1} = {'abcd','efg'};
    
    for ts_i = 1:numel(ts)   % repeat for 40 trials
        taskdata.dat{ts_i}.trial_starttime = GetSecs; % trial start timestamp
        display_target_word(ts{ts_i}); % sub-function, display two generated words
        waitsec_fromstarttime(taskdata.dat{ts_i}.trial_starttime, wordT); % for 15s
         
        % Blank for ISI
        taskdata.dat{ts_i}.isi_starttime = GetSecs;  % ISI start timestamp
        Screen(theWindow,'FillRect',bgcolor, window_rect);
        Screen('Flip', theWindow);
        waitsec_fromstarttime(taskdata.dat{ts_i}.trial_starttime, wordT+3);
        
        % Concentration Qustion
        taskdata.dat{ts_i}.concent_starttime = GetSecs;  % rating start timestamp
        [taskdata.dat{ts_i}.concentration, taskdata.dat{ts_i}.concent_time, ...
            taskdata.dat{ts_i}.concent_trajectory] = concent_rating(taskdata.dat{ts_i}.concent_starttime); % sub-function
    end
    
    %% RUN END MESSAGE
    taskdata.run_end = GetSecs;  % rating start timestamp
    Screen('TextSize', theWindow, fontsize);    
    Screen(theWindow,'FillRect',bgcolor, window_rect);
    DrawFormattedText(theWindow, run_end_prompt, 'center', 'center', white, [], [], [], 1.5);
    Screen('Flip', theWindow);
        
    waitsec_fromstarttime(taskdata.run_end, 3);

    ShowCursor; %unhide mouse
    Screen('CloseAll'); %relinquish screen control 
    
catch err
    % ERROR 
    disp(err);
    for i = 1:numel(err.stack)
        disp(err.stack(i));
    end
    abort_experiment('error');  
end

end


%% == SUBFUNCTIONS ==============================================


function abort_experiment(varargin)

% ABORT the experiment
%
% abort_experiment(varargin)

str = 'Experiment aborted.';

for i = 1:length(varargin)
    if ischar(varargin{i})
        switch varargin{i}
            % functional commands
            case {'error'}
                str = 'Experiment aborted by error.';
            case {'manual'}
                str = 'Experiment aborted by the experimenter.';
        end
    end
end

ShowCursor; %unhide mouse
Screen('CloseAll'); %relinquish screen control
disp(str); %present this text in command window

end


%% ========================== SUB-FUNCTIONS ===============================

function display_target_word(words)

global W H white theWindow window_rect bgcolor fontsize

fontsz = [fontsize*45/30 fontsize*65/30];
% Calcurate the W & H of two generated words
Screen('TextSize', theWindow, fontsz(1));
[response_W(1), response_H(1)] = Screen(theWindow, 'DrawText', double(words{1}), 0, 0);

Screen('TextSize', theWindow, fontsz(2));
[response_W(2), response_H(2)] = Screen(theWindow, 'DrawText', double(words{2}), 0, 0);

interval = 150;  % between two words
% coordinates of the words 
x(1) = W/2 - interval - response_W(1) - response_W(2)/2;
x(2) = W/2 - response_W(2)/2;

y(1) = H/2 - response_H(1);
y(2) = H/2 - response_H(2);

Screen(theWindow,'FillRect',bgcolor, window_rect);

Screen('TextSize', theWindow, fontsz(1)); % previous word, fontsize = 45
DrawFormattedText(theWindow, double(words{1}), x(1), y(1), white-80, [], [], [], 1.5);

Screen('TextSize', theWindow, fontsz(2)); % present word, fontsize = 65
DrawFormattedText(theWindow, double(words{2}), x(2), y(2), white, [], [], [], 1.5);

Screen('Flip', theWindow);

end

function [concentration, trajectory_time, trajectory] = concent_rating(starttime)

global W H orange bgcolor window_rect theWindow red fontsize white cqT
intro_prompt1 = double('???');
intro_prompt2 = double('?');
title={'Not at all','-', 'Absolutely'};

SetMouse(W/2, H/2);

trajectory = [];
trajectory_time = [];
xy = [W/3 W*2/3 W/3 W/3 W*2/3 W*2/3;
      H/2 H/2 H/2-7 H/2+7 H/2-7 H/2+7];

j = 0;

while(1)
    j = j + 1;
    [mx, my, button] = GetMouse(theWindow);
    
    x = mx;
    y = H/2;
    if x < W/3, x = W/3;
    elseif x > W*2/3, x = W*2/3;
    end
    
    Screen('TextSize', theWindow, fontsize);
    Screen(theWindow,'FillRect',bgcolor, window_rect);
    Screen('DrawLines',theWindow, xy, 5, 255);
    DrawFormattedText(theWindow, intro_prompt1,'center', H/4, white);
    DrawFormattedText(theWindow, intro_prompt2,'center', H/4+40, white);
    % Draw scale letter
    DrawFormattedText(theWindow, double(title{1}),'center', 'center', white, ...
                [],[],[],[],[], [xy(1,1)-70, xy(2,1), xy(1,1)+20, xy(2,1)+60]);
    DrawFormattedText(theWindow, double(title{2}),'center', 'center', white, ...
                [],[],[],[],[], [W/2-15, xy(2,1), W/2+20, xy(2,1)+60]);
    DrawFormattedText(theWindow, double(title{3}),'center', 'center', white, ...
                [],[],[],[],[], [xy(1,2)+45, xy(2,1), xy(1,2)+20, xy(2,1)+60]);

    Screen('DrawDots', theWindow, [x y], 10, orange, [0, 0], 1); % draw orange dot on the cursor
    Screen('Flip', theWindow);
        
    trajectory(j,:) = [(x-W/2)/(W/3)];    % trajectory of location of cursor
    trajectory_time(j) = GetSecs - starttime; % trajectory of time

    if trajectory_time(end) >= cqT  % maximum time of rating is 5s
        button(1) = true;
    end
    
    if button(1)  % After click, the color of cursor dot changes.
        Screen(theWindow,'FillRect',bgcolor, window_rect);
        Screen('DrawLines',theWindow, xy, 5, 255);
        DrawFormattedText(theWindow, intro_prompt1,'center', H/4, white);
        DrawFormattedText(theWindow, intro_prompt2,'center', H/4+40, white);
        % Draw scale letter
        DrawFormattedText(theWindow, double(title{1}),'center', 'center', white, ...
            [],[],[],[],[], [xy(1,1)-70, xy(2,1), xy(1,1)+20, xy(2,1)+60]);
        DrawFormattedText(theWindow, double(title{2}),'center', 'center', white, ...
            [],[],[],[],[], [W/2-15, xy(2,1), W/2+20, xy(2,1)+60]);
        DrawFormattedText(theWindow, double(title{3}),'center', 'center', white, ...
            [],[],[],[],[], [xy(1,2)+45, xy(2,1), xy(1,2)+20, xy(2,1)+60]);
        Screen('DrawDots', theWindow, [x;y], 10, red, [0 0], 1);
        Screen('Flip', theWindow);
        
        concentration = (x-W/3)/(W/3);  % 0~1
        
        WaitSecs(0.5);   
        break;
    end    
end
end