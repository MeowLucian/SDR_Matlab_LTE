clear;close all;clc;j=1i;
Global_Parameters;
%% TX signal load
load('Picture_all.mat');
%% Button setting
figure('Name','TX','NumberTitle','off');
button = uicontrol; % Generate GUI button
set(button,'String','Stop !','Position',[1050 15 100 60]); % Add "Stop !" text
%% TRX Main
state = 1; % status Start
Ready_Time = 3;
Run_time_number = 1;
index = 1;
%% New Add
txWaveform = zeros(153600,1);
[s,input] = iio_Hardware_setting('192.168.3.6',txWaveform,CenterFrequency,rmc); % TX
[s2,input2] = iio_Hardware_setting('192.168.3.7',0,CenterFrequency,rmc); % RX

while(state==1)
    try
        if index > 10
            index = 1;
        end
        txWaveform = Picture_all(index).txdata;
        input{1} = real(txWaveform);
        input{2} = imag(txWaveform);
        output = cell(1, s.out_ch_no + length(s.iio_dev_cfg.mon_ch)); % TX
        output2 = cell(1, s2.out_ch_no + length(s2.iio_dev_cfg.mon_ch)); % RX
        output = stepImpl(s, input); % TX
        output2 = stepImpl(s2, input2); % RX
        rssi = output{s2.getOutChannel('RX1_RSSI')};
        
        if Run_time_number > Ready_Time
            rxWaveform = double(output2{1}+j*output2{2})*(2^-15);
            OFDM_RX(rxWaveform,rmc,rssi);
        end

        if Run_time_number <= Ready_Time  % Ready
            disp('Ready');
        end
        Run_time_number = Run_time_number + 1;

        % ----- Button Behavior -----%
        set(button,'Callback','setstate0'); % Set the reaction of pushing button
        index = index + 1;
    
    catch
        ErrorMessage = lasterr;
        fprintf('Error Message : \n');
        disp(ErrorMessage);
        fprintf(2,'Error occurred & Stop Hardware\n');
        
        % Error handling
        % release(rx_object);
        % state=0;

    end % try Loop
end % While Loop

s.releaseImpl();
s2.releaseImpl();
close all;
disp('Software Complete');