function [] = OFDM_RX(rxWaveform,rmc,rssi)
try
    set(gcf,'Units','centimeters','position',[1 2 49 24]); % Set the postion of GUI
    %% RX-Raw Plot
    subplot(2,4,1),plot(rxWaveform,'.');title('RX-Raw');
    axis square;
    Raw_window_scale = 0.07;
    axis([-Raw_window_scale,Raw_window_scale,-Raw_window_scale,Raw_window_scale]);
    drawnow;
    %% Welch Power Spectral Density Plot
    [Spectrum_waveform,Welch_Spectrum_frequency] = pwelch(rxWaveform,[],[],[],rmc.SamplingRate,'centered','power');
    subplot(2,4,2),plot(Welch_Spectrum_frequency,pow2db(Spectrum_waveform));
    title(['Welch Power Spectral Density',' , RSSI = ',num2str(rssi)]);
    drawnow;
    %% Derived parameters
    samplesPerFrame = 10e-3*rmc.SamplingRate; % 153600 samples, LTE frames period is 10 ms
    %% Channel estimation configuration structure
    cec.PilotAverage = 'UserDefined';  % Type of pilot symbol averaging
    cec.FreqWindow = 9;                % Frequency window size in REs
    cec.TimeWindow = 9;                % Time window size in REs
    cec.InterpType = 'Cubic';          % 2D interpolation type
    cec.InterpWindow = 'Centered';     % Interpolation window type
    cec.InterpWinSize = 3;             % Interpolation window size
    %% Receiver processing
    enb = rmc; % Set default LTE parameters
    
    % Perform frequency offset correction for known cell ID
    frequencyOffset = lteFrequencyOffset(enb,rxWaveform);
    rxWaveform = lteFrequencyCorrect(enb,rxWaveform,frequencyOffset);
    fprintf('\nCorrected a frequency offset of %i Hz.\n',frequencyOffset)

    % Perform the blind cell search to obtain cell identity and timing offset Use 'PostFFT' SSS detection method to improve speed
    cellSearch.SSSDetection = 'PostFFT'; cellSearch.MaxCellCount = 1;
    NCellID = lteCellSearch(enb,rxWaveform,cellSearch);
    fprintf('Detected a cell identity of %i.\n', NCellID);
%     enb.NCellID = NCellID; % From lteCellSearch

    [frameOffset,corr] = lteDLFrameOffset(enb,rxWaveform);
    
%     subplot(2,4,3),plot(abs(rxWaveform));
%     hold on;
%     subplot(2,4,3),plot(1:length(rxWaveform),[zeros(frameOffset,1);0.18;zeros(length(rxWaveform)-frameOffset-1,1)])
%     hold off;
%     axis square;
%     drawnow;
% 
%     subplot(2,4,4),plot(corr);
%     hold on;
%     subplot(2,4,4),plot(1:length(rxWaveform),[zeros(frameOffset,1);0.18;zeros(length(rxWaveform)-frameOffset-1,1)]);
%     hold off;
%     axis square;
%     title('Packet Detection');
%     drawnow;
    
    % Sync the captured samples to the start of an LTE frame, and trim off any samples that are part of an incomplete frame.
    rxWaveform2 = rxWaveform(frameOffset+1:frameOffset+153600); % [307200x1] -> [153600x1]
    tailSamples = mod(length(rxWaveform2),samplesPerFrame);
    rxWaveform3 = rxWaveform2(1:end-tailSamples,:);
    enb.NSubframe = 0;
    fprintf('Corrected a timing offset of %i samples.\n',frameOffset)

    % OFDM demodulation
    rxGrid = lteOFDMDemodulate(enb,rxWaveform3);

    % Perform channel estimation for 4 CellRefP as currently we do not know the CellRefP for the eNodeB.
    [hest,nest] = lteDLChannelEstimate(enb,cec,rxGrid);

    sfDims = lteResourceGridSize(enb);
    Lsf = sfDims(2); % OFDM symbols per subframe
    LFrame = 10*Lsf; % OFDM symbols per frame
    numFullFrames = length(rxWaveform3)/samplesPerFrame;

    rxDataFrame = zeros(sum(enb.PDSCH.TrBlkSizes(:)),numFullFrames);
    recFrames = zeros(numFullFrames,1);
    rxSymbols = []; txSymbols = [];

    %% For each frame decode the MIB, PDSCH and DL-SCH
    for frame = 0:(numFullFrames-1)
        fprintf('\nPerforming DL-SCH Decode for frame %i of %i in burst:\n',frame+1,numFullFrames)

        % Extract subframe #0 from each frame of the received resource grid and channel estimate.
        enb.NSubframe = 0;
        rxsf = rxGrid(:,frame*LFrame+(1:Lsf),:);
        hestsf = hest(:,frame*LFrame+(1:Lsf),:,:);

        % PBCH demodulation. Extract resource elements (REs) corresponding to the PBCH from the received grid and channel estimate grid for demodulation.
        enb.CellRefP = 1;
        pbchIndices = ltePBCHIndices(enb); 
        [pbchRx,pbchHest] = lteExtractResources(pbchIndices,rxsf,hestsf);
        [~,~,nfmod4,mib,CellRefP] = ltePBCHDecode(enb,pbchRx,pbchHest,nest);

        % If PBCH decoding successful CellRefP~=0 then update info
        if ~CellRefP
            fprintf('No PBCH detected for frame.\n');
            continue;
        end
        enb.CellRefP = CellRefP; % From ltePBCHDecode

        % Decode the MIB to get current frame number
        enb = lteMIB(mib,enb);

        % Incorporate the nfmod4 value output from the function ltePBCHDecode, as the NFrame value established from the MIB is the system frame number modulo 4.
        enb.NFrame = enb.NFrame+nfmod4;
        fprintf('Successful MIB Decode.\n')
        fprintf('Frame number: %d.\n',enb.NFrame);

        % The eNodeB transmission bandwidth may be greater than the captured bandwidth, so limit the bandwidth for processing
        enb.NDLRB = min(rmc.NDLRB,enb.NDLRB);

        % Store received frame number
        recFrames(frame+1) = enb.NFrame;
        
        % Process subframes within frame (ignoring subframe 5)
        for sf = 0:9
            if sf~=5 % Ignore subframe 5
                % Extract subframe
                enb.NSubframe = sf;
                rxsf = rxGrid(:,frame*LFrame+sf*Lsf+(1:Lsf),:);

                % Perform channel estimation with the correct number of CellRefP
                [hestsf,nestsf] = lteDLChannelEstimate(enb,cec,rxsf);

                % PCFICH demodulation. Extract REs corresponding to the PCFICH from the received grid and channel estimate for demodulation.
                pcfichIndices = ltePCFICHIndices(enb);
                [pcfichRx,pcfichHest] = lteExtractResources(pcfichIndices,rxsf,hestsf);
                cfiBits = ltePCFICHDecode(enb,pcfichRx,pcfichHest,nestsf);

                % CFI decoding
                enb.CFI = lteCFIDecode(cfiBits);

                % Get PDSCH indices
                [pdschIndices,pdschIndicesInfo] = ltePDSCHIndices(enb, enb.PDSCH, enb.PDSCH.PRBSet); 
                [pdschRx, pdschHest] = lteExtractResources(pdschIndices, rxsf, hestsf);

                % Perform deprecoding, layer demapping, demodulation and descrambling on the received data using the estimate of the channel
                [rxEncodedBits, rxEncodedSymb] = ltePDSCHDecode(enb,enb.PDSCH,pdschRx,pdschHest,nestsf);

                % Append decoded symbol to stream
                rxSymbols = [rxSymbols; rxEncodedSymb{:}];

                % Transport block sizes
                outLen = enb.PDSCH.TrBlkSizes(enb.NSubframe+1);  

                % Decode DownLink Shared Channel (DL-SCH)
                [decbits{sf+1}, blkcrc(sf+1)] = lteDLSCHDecode(enb,enb.PDSCH,outLen,rxEncodedBits);

                % Recode transmitted PDSCH symbols for EVM calculation Encode transmitted DLSCH 
                txRecode = lteDLSCH(enb,enb.PDSCH,pdschIndicesInfo.G,decbits{sf+1});
                %   Modulate transmitted PDSCH
                txRemod = ltePDSCH(enb, enb.PDSCH, txRecode);
                %   Decode transmitted PDSCH
                [~,refSymbols] = ltePDSCHDecode(enb, enb.PDSCH, txRemod);
                %   Add encoded symbol to stream
                txSymbols = [txSymbols; refSymbols{:}];
                
                % Current constellation
                subplot(2,4,5),plot(rxEncodedSymb{:},'.');
                axis square;
                axis([-1.5 1.5 -1.5 1.5]);
                title('Constellation');
                drawnow;
            end
        end

        % Reassemble decoded bits
        fprintf('Retrieving decoded transport block data.\n');
        rxdata = [];
        for i = 1:length(decbits)
            if i~=6 % Ignore subframe 5
                rxdata = [rxdata; decbits{i}{:}];
            end
        end
        % Store data from receive frame
        rxDataFrame(:,frame+1) = rxdata;
    end % Frame Loop
    %% Result Qualification and Display
    % Determine index of first transmitted frame (lowest received frame number)
    [~,frameIdx] = min(recFrames);

    fprintf('\nRecombining received data blocks:\n');

    decodedRxDataStream = zeros(length(rxDataFrame(:)),1);
    frameLen = size(rxDataFrame,1);
    % Recombine received data blocks (in correct order) into continuous stream
    for n=1:numFullFrames
        currFrame = mod(frameIdx-1,numFullFrames)+1; % Get current frame index 
        decodedRxDataStream((n-1)*frameLen+1:n*frameLen) = rxDataFrame(:,currFrame);
        frameIdx = frameIdx+1; % Increment frame index
    end
    % Recreate image from received data
    fprintf('\nConstructing image from received data.\n');
    str = reshape(sprintf('%d',decodedRxDataStream(1:249696)), 8, []).'; % trData length : 249696
    decdata = uint8(bin2dec(str));
    receivedImage = reshape(decdata,[102,102,3]); % imsize : [102,102,3]
    % Plot received image
    subplot(2,4,6),imshow(receivedImage);
    title('Received Image');
    axis square;
    drawnow;
end % try Loop
end % OFD M_RX Loop