%% February-July, 2020, Nigel Ward 
    
%% istyles/code/computeStyleParams.m

%% This code computes distributional statistics over the prosodic dimensions
%%   for the specified subset of Switchboard conversations, for both speakers in each,
%% and saves them to a file, for later analysis of interaction styles by deriveISspace.m

%% see ../papers/draft.tex for the aims of the study
%% see ../doc/istyles.tex for documentation of the overall workflow
%% see ../labnotes.txt for details on data selection

%% This assumes that the pitch has already been computed, using sph-to-splittrack-wav.sh
%%  and saved to sister directories called ../f0reaper
%% and that the stereo wav files exist, as created with sph-to-wavfiles.sh

%% The sigmas are computed on the same data used to generate the dimensions.
%%   with applynormrot('../../social.tl', '../../../midlevel/flowtest/pbook.fss', '.');
%% A thought: perhaps percentile-based bins would have been better

%% Since this will process >1000 files, thus hours of runtime,
%%  it needs to be restartable, so that's why it incrementally appends results to a file

%% addpath:  midlevel/src,  midlevel/src/voicebox, midlevel/flowtest, istyles/code

%% to test, from shortTests/, computeStyleParams('filelist.txt', 'ministats.csv');
%% to run, edit motherDirectory, and subDirList, then
%%      computeStyleParams('trainset.txt', 'trainsetStats.csv');

function computeStyleParams(toProcessListFile, statsFile)
  fsfile = 'pbook.fss';
  rsfile = 'rotationspec.mat';    % copied from book/pbook-run/, created by findDimensions
  sifile = 'sigmas.csv';          

  motherDirectory = 'f:/nigel/comparisons/en-swbd/';
  subDirList = {'disc1/wavfiles', 'disc2/wavfiles', 'disc3/wavfiles', 'disc4/wavfiles' };
  %%motherDirectory = '../';       %% for testing
  %%subDirList = {'shortTests'};   %% for testing

  nDimsToProcess = 12;  
  featurelist =  getfeaturespec(fsfile);
  load(rsfile);     % get coeff, nmeans, rotation_provenance, etc., 
  provenance = strcat('from computeStyleParams using ', rotation_provenance);
  prosDimSigmas = csvread(sifile);
  toProcess = csvread(toProcessListFile);

  for subDirCell = subDirList 
    subDir = subDirCell{1};
    fileStructs = dir([motherDirectory subDir '/' '*tr.wav']);
    for i = 1:length(fileStructs)
      wavfile = fileStructs(i).name;
      dialogNum = swbdFilename2dialogID(wavfile);
      if ~ismember(dialogNum, toProcess) 
	fprintf(' skipping %d since not in %s\n', dialogNum, toProcessListFile);
	continue
      end
      path = strcat(motherDirectory, subDir, '/', wavfile);
      for sideCell = {'l', 'r'}
	tic
	side = sideCell{1};
	trackspec = makeTrackspec(side, wavfile, strcat(motherDirectory, subDir, '/'));
	rotated = normrotoneAblations(trackspec, featurelist, nmeans, ...
					nstds, coeff, provenance, 'tmp/', 'tmp/'); %**
	rotated = rotated(:,1:nDimsToProcess);
	fprintf('size of rotated is %d %d\n', size(rotated));
	computeAndWriteStatsOnDistribs(rotated, prosDimSigmas, nDimsToProcess, ...
				       dialogNum, side, provenance, statsFile);

	toc
      end
    end
  end
end  


%% the new version, computing stats for 39 second clips of an audio file 
function computeAndWriteStatsOnDistribs(rotated, sigmas, nDimsToProcess, ...
					dialogNum, side, provenance, statsFile);
  clipSizeSec = 30; % seconds; formerly 32
  framesPerSec = 100; 
  clipSizeFr = clipSizeSec * framesPerSec;
  nclips = floor(length(rotated) / clipSizeFr);
  for clipNum = 1:nclips
    startFr = 1 + clipSizeFr * (clipNum - 1);
    endFr = startFr + clipSizeFr;
    clipBit = rotated(startFr:endFr,:);
    clipStats = computeStatsOnDistributions(clipBit, sigmas, nDimsToProcess);
    writeDistributionStats2(dialogNum, side, clipNum, clipStats, provenance, statsFile);
  end
end 

  
function stats = computeStatsOnDistributions(rotated, sigmas, nDimsToProcess)
  stats = [];
  for dim=1:nDimsToProcess
    newStats = computeDistributionStats(dim, rotated(:,dim), sigmas(dim));
    stats = [stats newStats];
  end
end

function names = dimDescriptions() 
  names = {'+ other has turn - focal has turn', ... 
	   '+ shared enthusiasm overlap - reluctance/silence/delay', ...
	   '+ turn yield - turn take', ...
	   '+ backchannelling - talking/BC cueing', ...
	   '+ topic continuation - topic closing', ...
	   '+ positive assessment - topic development', ...
	   '+ indifference - empathy bid', ...
	   '+ bipartite construction - fillers', ...
	   '+ particle assisted turn yield - p.a. turn take', ...
	   '+ fillers - late peaks', ...
	   '+ bookended narrow pitch - meta comment', ...
	   '+ receiving action cue - minor third cue' ...
	  };
end


%% for use as a testing stub
%% note that the mean for each dimension, on the training set, should be zero
function [stats] = computeMeans(rotated, sigmas, nDimsToProcess) 
  stats = mean(rotated);
  stds = std(rotated);
  names = dimDescriptions();
  for i = 1:nDimsToProcess
    name = names(i);
    fprintf('dim %2d: mean %5.2f, std %.2f (%s) \n', i, stats(i), stds(i), names{i});
  end
end


function stats = computeDistributionStats(dimNum, dimColumn, sigma)
  intervals = intervalsForCSP();          % endpoints of each bin: -10 to -2.4, etc.
  adjustedIntervals = intervals * sigma;  % normalize for this dimension's variance
  nIntervals = size(intervals,1);
  names = dimDescriptions();
  stats = zeros(1,nIntervals);
  nameCell = names(dimNum);  %% not tested
  %%fprintf('  dim %2d, mean is %.2f \n', dimNum, mean(dimColumn));
  for i = 1:nIntervals
    stats(i) = countFractionInRange(dimColumn, adjustedIntervals(i,1), adjustedIntervals(i,2));
  end
end


function frac = countFractionInRange(column, lowerBound, upperBound)
  frac = length(column(column>=lowerBound & column< upperBound)) /length(column);
  %%fprintf('frac between %4.1f and %4.1f is %.3f\n', lowerBound, upperBound, frac);
end

function id = swbdFilename2dialogID(filename)
  id = str2num(filename(4:7));   % integer from the 4-digit code
end


%% append a line of comma-separated values to the exiting file: each line is:
%%    dialogID, left/right, clipNum, stats fields
function writeDistributionStats2(dialogID, side, clipnum, stats, provenance, statsFile)
  fd = fopen(statsFile, 'a');
  if side == 'l' 
    infoString = sprintf('%4d, 0, %2d ',  dialogID, clipnum);
  else
    infoString = sprintf('%4d, 1, %2d ',  dialogID, clipnum);
  end
  statsString = '';
  %%fprintf('in writeDistributions, writing %d stats\n', length(stats));
  for i = 1:length(stats)
    statsString = [statsString sprintf(',%.5f', stats(i))];
  end
  %%historyString = sprintf('\"%s, %s,\"', provenance, datestr(clock));
  fullString = [infoString statsString '\n'];
  fprintf(fd, fullString);
  fclose(fd);
end

%% ----------------------------------------------------------------------------
%% below this point is code for the old versions, which computed
%% stats over entire audio files, rather than just fragmnts 

function computeAndWriteStatsOnDistribsOld(rotated, sigmas, nDimsToProcess, ...
					dialogNum, side, provenance, statsFile);
  %%these lines are for testing computeStatsOnDistributions on synthetic data
  %%testDistributions = distributionsForTesting(nDimsToProcess);
  %%stats = computeMeans(testDistributions, sigmas, nDimsToProcess);  
  %%stats = computeStatsOnDistributions(testDistributions, sigmas, nDimsToProcess);
  
  stats = computeStatsOnDistributions(rotated, sigmas, nDimsToProcess);
  writeDistributionStats(dialogNum, side, stats, provenance, statsFile);
end 

function writeDistributionStatsOld(dialogID, side, stats, provenance, statsFile)
  fd = fopen(statsFile, 'a');
  if side == 'l' 
    infoString = sprintf('%4d, 0, ',  dialogID);
  else
    infoString = sprintf('%4d, 1, ',  dialogID);
  end
  statsString = '';
  fprintf('in writeDistributions, length(stats) is %d\n', length(stats));
  for i = 1:length(stats)
    statsString = [statsString sprintf('%.5f,', stats(i))];
  end
  %%historyString = sprintf('\"%s, %s,\"', provenance, datestr(clock));
  fullString = [infoString statsString '\n'];
  fprintf(fd, fullString);
  fclose(fd);
end

%%----------------------------------------------------------------------------
%%  generate artificial data, structured like "rotated", to test computeStatsOnDistributions, 
function data = distributionsForTesting(nDimsToProcess)
  columnLength = 200;
  data = zeros(nDimsToProcess,columnLength);
  data(1,:) = 10 * rand(columnLength, 1) - 5;    % uniformly distributed from -5 to +5
  data(2,:) =  4 * rand(columnLength, 1) - 2;    % uniformly distributed from -2 to +2
  data(3,:) =  4 * rand(columnLength, 1) - 0;    % uniformly distributed from  0 to  4
  data(4,:) =  3 * rand(columnLength, 1) - 5;    % uniformly distributed from -5 to -2
  data(5,:) =  data(1,:) + data(2,:);      % slightly peaky distribution, centered at 0
end


