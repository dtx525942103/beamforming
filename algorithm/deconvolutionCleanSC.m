function Q = deconvolutionCleanSC(D, e, w, loopGain, maxIterations)
%deconvolutionCleanSC - deconvolves the intensity plot with the clean-sc algorithm
%as implemented in "CLEAN based on spatial source coherence", Pieter Sijtsma, 2007
%
%Q = deconvolutionCleanSC(D, e, w, loopGain)
%
%IN
%D             - PxP cross spectral matrix (CSM)
%e             - NxMxP steering vector/matrix 
%w             - 1xP weighting vector
%loopGain      - 1x1 safety factor, 0 < loopGain < 1
%maxIterations - Maximum number of iterations to create the clean map
%
%OUT
%Q - NxM devonvolved intensity plot
%
%Created by J?rgen Grythe, Squarehead Technology AS
%Last updated 2016-09-12


[nScanPointsY, nScanPointsX, nMics] = size(e);

%Make the weighting vector a column vector instead of row vector
if isrow(w)
    w = w';
end

%Maximum number of iterations to create the clean map
if ~exist('maxIterations', 'var')
    maxIterations = 100;
end

%Safety factor that determines how much to remove that correlates with
%strongest source, 0 removes nothing, 1 removes all
if ~exist('loopGain', 'var')
    loopGain = 0.9;
end

%Normalization factor to get correct dB scaling
normFactor = 1/(nMics^2-nMics);

%Initialise trimmed cross spectral matrix (CSM) by setting the diagonal to zero
D(logical(eye(nMics))) = 0;

%Initialise final clean image
Q = zeros(nScanPointsY, nScanPointsX);

%Initialise break criterion
sumOfCSM = sum(sum(abs(D)));
sumOfDegradedCSM = sumOfCSM;


for cleanMapIterations = 1:maxIterations
    
    % -------------------------------------------------------
    % 1. Calculate dirty map
    P = zeros(nScanPointsY, nScanPointsX);
    for scanningPointY = 1:nScanPointsY
        for scanningPointX = 1:nScanPointsX
            ee = reshape(e(scanningPointY, scanningPointX, :), nMics, 1);
            P(scanningPointY, scanningPointX) = normFactor*(w.*ee)'*D*(ee.*w);
        end
    end
    
    
    
    % -------------------------------------------------------
    % 2. Find peak value and its position in dirty map
    [maxPeakValue, maxPeakIndx] = max(P(:));
    [maxPeakValueYIndx, maxPeakValueXIndx] = ind2sub(size(P), maxPeakIndx);
    
    
    
    % -------------------------------------------------------
    % 3. Calculate the CSM induced by the peak source
    
    % Steering vector to location of peak source
    g = reshape(e(maxPeakValueYIndx, maxPeakValueXIndx, :), nMics, 1);
    g = g*sqrt(normFactor);
    
    %Get value of source component, initialise h as steering vector to
    %peak source
    h = g;
    for iterH = 1:50
        hOldValue = h;
        H = h*h';
        
        H(~logical(eye(nMics))) = 0;
        h = 1/sqrt(1+(w.*g)'*H*(g.*w))*(D*(g.*w)/maxPeakValue + H*(g.*w));
        if norm(h-hOldValue) < 1e-6
            break;
        end
    end
    
    
    
    % -------------------------------------------------------
    % 4. New updated map with clean beam from peak source location
    % Clean beam with specified width and max value of 1
    PmaxCleanBeam = zeros(nScanPointsY, nScanPointsX);
    PmaxCleanBeam(maxPeakValueYIndx, maxPeakValueXIndx) = 1;
    
    % Update clean map with clean beam from peak source location
    Q = Q + loopGain*maxPeakValue*PmaxCleanBeam;
    
    
    
    % -------------------------------------------------------
    % 5. Calculate degraded cross spectral matrix
    D = D - loopGain*maxPeakValue*(h*h');
    D(logical(eye(nMics))) = 0;
    
    % Stop the iteration if the degraded CSM contains more information than
    % in the previous iteration
    sumOfCSM = sum(sum(abs(D)));
    if sumOfCSM > sumOfDegradedCSM
        break;
    end
    sumOfDegradedCSM = sumOfCSM;
    
    
end

if cleanMapIterations == maxIterations
    disp(['Stopped after maximum iterations (' num2str(maxIterations) ')'])
else
    disp(['Converged after ' num2str(cleanMapIterations) ' iterations'])
end

% 6. Source plot is written as summation of clean beams and remaining dirty map
Q = Q + P;



end