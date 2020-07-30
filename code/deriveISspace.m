%% February - July, 2020, Nigel Ward 
%% From interaction style parameter values for hundreds of audio tracks,
%%  build/apply the space of interaction styles 

%% PcbStatsFile is the prosodic-constructions-binned file generated by joinData.sh 
%% freshlyNormalize if true means to compute and write normalization stats and PCA coeff
%%    if false means to use existing normalization stats and PCA coeff
%% IsNormRotStatsFile is the file to write the above, or to read it from 

%% Run this inside istyles/stats, e.g.
%%   deriveISspace('stats/trainStats.csv', true, 'trainIsNormRot.mat')
%%   deriveISspace('stats/PcbTestStats.csv', false, 'trainIsNormRot.mat')

%% if freshlyNormalize is true, then 

function deriveISspace(PcbStatsFile, freshlyNormalize, ISNormRotStatsFile, outputDir)

  basedir = 'c:/nigel/istyles/';
  %%statsFile = [basedir 'shortTests/ministats.csv'];
  statsFile = PcbStatsFile;  % [basedir 'stats/trainStats.csv'];
  outDir = [basedir outputDir, '/'];

  data = readmatrix(statsFile);   % one row per audio track
  sourceInfo = data(:,1:NSourceInfoFields()); 
  sstats = data(:,1+NSourceInfoFields():end);   % the statistics for each side 
  fprintf('found data for %d clips, %d features, with %d NaNs\n', ...
  	  size(sstats), sum(sum(isnan(sstats))) );
  featNames = assembleLabels();   % feature names 

  %[sstats, sourceInfo, featNames] = pruneJunk(sstats, sourceInfo, featNames);
  %%[sstats, sourceInfo] = pruneExcessives(sstats, sourceInfo, featNames);
  fprintf('Reporting results over %d clips\n', size(sstats, 1));

  cmatrix = corrcoef(sstats);
  fprintf(' found %d NaNs in the correlations\n', sum(sum(isnan(cmatrix))));
  writeCorrelations(cmatrix, featNames, 'outDir', 'correlations.txt');

  if freshlyNormalize
    fmean = mean(sstats);
    fstd = std(sstats);
    normalized = (sstats - fmean) ./ fstd;
    [coeff, score, latent] = pca(normalized);
    provenance = ['deriveISspace ' PcbStatsFile ' ' datestr(clock)] 
    save(ISNormRotStatsFile, 'fmean', 'fstd', 'coeff', 'provenance');
    variExplained(latent);
  else
    load(ISNormRotStatsFile);
    fprintf('size(sstats) is %d %d\n', size(sstats));
    fprintf('size(fmean) is %d %d\n', size(fmean));
    fprintf('size(fstd) is %d %d\n', size(fstd));
    normalizedf = (sstats - fmean) ./ fstd;
    score = normalizedf * coeff;
  end
  
  %%warnReExcessives(score, sstats, sourceInfo, featNames);
  score = score(:,1:16);    %%trim down to save space

  loadingsHeader = sprintf('Interaction Style Dimension Loadings, generated %s', ...
			   datestr(clock));
  writeLoadings(coeff, featNames, loadingsHeader, outDir);
  writeLoadingsTable(coeff, featNames, loadingsHeader, outDir);

  writeISexemplars(score, sourceInfo);
  writeScores(score, sourceInfo, outDir);   
  
  metad = assembleMetadata(basedir, sourceInfo);
  
  examineMaleFemale(score, metad);
  examineAB(score, metad);
  %%  wordFreqAnalysis(score, metad);  % takes 3 hours

  %% examineAge(score, metad);  % a trifle slow 

  soxfd = fopen([outDir 'sox-commands.sh'], 'w');    % to later execute with bash
  findClipsNearOrigin(score, sourceInfo, metad, soxfd);  
  %%  writeSomeClosePairs(score, sourceInfo);  % a trifle slow 
  examinePredictability(score, metad);
  pickClipsForExamination(score, sourceInfo, metad, soxfd);
  pickClipsForHumanSubjects(score, sourceInfo, metad);

  %% compareWithSubsets(coeff, normalized);  % a trifle verbose
  %% computeTopicAverages(score, metad);
  fclose(soxfd);
end


function computeTopicAverages(score, metad)
  lastTopic =  max(metad(:,8));
  dimOfInterest = 3;
  for topic = 301:lastTopic
    indicesForTopic = metad(:,8) == topic;
    scoresForTopic = score(indicesForTopic,:);
    if size(scoresForTopic,1) > 50   % meaning at least 3 conversations
      dim1avg = mean(scoresForTopic(:,dimOfInterest));
      fprintf('for topic %d, average over %4d fragments on  dim %d is %5.2f\n', ...
	      topic, size(scoresForTopic,dimOfInterest), dimOfInterest, dim1avg);
    end
  end
end



function [sstats, sourceInfo, featNames] = pruneJunk(sstats, sourceInfo, featNames)
  %%fprintf('size of sstats is %d x %d, with %d NaNs\n', ...
  %%	  size(sstats), sum(sum(isnan(sstats))) );
  %% Formerly had a bug where with many zero-rich lines on
  %% prosody-derived features, so detect and remove such lines.
  nonZeroRows = sum(sstats(:,1+NSourceInfoFields:end), 2) > 0;
  sstats = sstats(nonZeroRows,:);
  sourceInfo = sourceInfo(nonZeroRows,:);

  %% Formerly some prosodic dimensions had less variation that expected, so
  %% the outlier-region features were constantly zero, so exclude them
  nonZeroColumns = sum(sstats, 1) > 0;
  for i = 1:length(featNames)
    if sum(sstats(:,i)) == 0
      fprintf('always zero for: %s\n', labelString(i, featNames));
    end
  end
  sstats = sstats(:, nonZeroColumns);

  %% fprintf('size of twice-pruned sstats is %d x %d\n', size(sstats));
  featNames = featNames(:, nonZeroColumns);
end 


%% write, also display some statistics and some samples as a sanity check
function writeScores(score, sourceInfo, outDir)
  maxTracksToShow = 5;  
  nclips = size(sourceInfo,1);
  tracksToShow = min(nclips, maxTracksToShow);
  dimsToShow = 8;
  means = mean(score);
  stds = std(score);
  fprintf('  dim      %4d %4d %4d %4d   %4d %4d %4d %4d  \n', 1:dimsToShow);
  fprintf('  mean      %4.1f %4.1f %4.1f %4.1f   %4.1f %4.1f %4.1f %4.1f  \n', ...
	  means(1:dimsToShow));
  fprintf('  stdevs    %4.1f %4.1f %4.1f %4.1f   %4.1f %4.1f %4.1f %4.1f  \n', ...
	  stds(1:dimsToShow));
  fprintf('      dim scores for a few sample clips\n');
  for track = 1:tracksToShow
    fprintf('%s : %4.1f %4.1f %4.1f %4.1f   %4.1f %4.1f %4.1f %4.1f  \n', ...
	    sourceString(track, sourceInfo), score(track, 1:dimsToShow))
  end
  sfd = fopen([outDir 'scores.txt'], 'w');
  fprintf(sfd, 'scores %s', datestr(clock));
  for track = 1:nclips
    fprintf(sfd,'%s : %4.1f %4.1f %4.1f %4.1f   %4.1f %4.1f %4.1f %4.1f  \n', ...
	    sourceString(track, sourceInfo), score(track, 1:dimsToShow));
  end
  fclose(sfd);
end


function variExplained(latent)
  nToShow = 12;
  fprintf('dim                    %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d %4d\n', ...
	  1:nToShow)
  ve = latent ./ sum(latent);
  fprintf('Variance Explained:    %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f\n', ...
	  ve(1:nToShow));
  cve = cumsum(latent) ./ sum(latent);
  fprintf('Cummulative Explained: %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f\n', ...
	  cve(1:nToShow ));
end


%% write a file with sample examplars for each dimension, for inspection
function writeISexemplars(score, sourceInfo)
  fprintf('writing exemplars ... ');
  dimsToShow = 10; 
  exemplarsToWrite = 100;
  de = fopen('dimExemplars.txt', 'w');
  fprintf(de, 'Interaction Style Dimension %s\n', datestr(clock));
  for dim = 1:dimsToShow
    dimSlice = score(:, dim);
    nsides = length(dimSlice);
    [vals, sortIndices] = sort(dimSlice);
    fprintf(de, '\n for dim%2d pos:\n', dim);
    for i=0:exemplarsToWrite
      fprintf(de, '%s  %.1f\n', ...
	      sourceString(sortIndices(nsides-i), sourceInfo), vals(nsides-i));
    end
    fprintf(de, '          neg:\n', dim);
    for i=1:exemplarsToWrite
      fprintf(de, '%s  %.1f\n', sourceString(sortIndices(i), sourceInfo), vals(i));
    end
  end
  fprintf(de, '\n');
  fclose(de);
  fprintf('... done \n');
end


%% return a human-readable string 
function trackString = sourceString(trackNum, sourceInfo)
  fileName = sourceInfo(trackNum, 1);
  trackCode = trackLetter(sourceInfo(trackNum, 2));
  clipStr   = clipString(sourceInfo(trackNum, 3));
  trackString = sprintf('  %d-%s-%s', fileName, trackCode, clipStr);   
end


function str = clipString(clipnum)
  startSeconds = 30 * (clipnum - 1);
  endSeconds = 30 * clipnum;
  str = sprintf('%1d:%02d-%1d:%02d', ...
		floor(startSeconds/60), rem(startSeconds,60), ...
		floor(endSeconds/60), rem(endSeconds,60) );
end


function track = trackLetter(channelNum)
  if channelNum == 0
    track = 'l';
  else
    track = 'r';
  end
end

  
function findClipsNearOrigin(score, sourceInfo, metad, soxfd)
  Eight = 8;     % dimensions I trust
  Twelve = 12;   % a few more, for comparison

  distancesFromZero =  sqrt(sum(score(:,1:Eight) .* score(:,1:Eight),2));
  fprintf('\n Closest 5 tracks to the origin, computed over 8 dimensions');
  [vals, sortIndices] = sort(distancesFromZero);
  for i=1:5
    fprintf('\n        %s', sourceString(sortIndices(i), sourceInfo));
    clipnum = metad(sortIndices(i), 4);
    startSeconds = 30 * (clipnum - 1);
    wavFileName = metad(sortIndices(i), 2);
    fprintf(soxfd, 'sox %s anchor%d.wav trim 0:%d 0:30 fade 0 -1 0.01\n', ...
	    wavFilePath(wavFileName), i, startSeconds);
  end

  [maxDistance, ix] = max(distancesFromZero);
  fprintf('\nThe track farthest from the origin by 8 is %s', ...
	  sourceString(ix, sourceInfo));

  distancesFromZero12 =  sqrt(sum(score(:,1:Twelve) .* score(:,1:Twelve),2));
  [minDistance, ix] = min(distancesFromZero12);
  fprintf('\nThe track closest to the origin by 12 is %s\n\n',  ... 
	  sourceString(ix, sourceInfo));
end 


%% slow 
function writeSomeClosePairs(score, sourceInfo)
  distancesHeader12 = sprintf('--- distances etc using %d dimensions---', Twelve);
  writeSomeClosePairsBis(score(:,1:Twelve), sourceInfo, distancesHeader12);
  distancesHeader8  = sprintf('--- distances etc using %d dimensions---', Eight);
  writeSomeClosePairsBis(score(:,1:Eight),  sourceInfo, distancesHeader8);
end


function writeSomeClosePairsBis(score, sourceInfo, header)  
  fprintf('\n%s', header);
  nsides = size(score, 1);
  nfeatures = size(score, 2);
  notMinFlag = max(9999, 1 + max(score(:)));
  distances = notMinFlag * ones (nsides, nsides);
  for i = 1:nsides
    for j = 1:nsides
      if i ~= j
	distances(i,j) = euclidean(score(i,:), score(j,:));
      end
    end
  end
  fprintf('   average distance between two pairs: %.2f\n', mean(mean(distances)));
  minDistance = min(distances(:));
  fprintf('   minimum distance between two pairs: %.2f\n', minDistance);
  [minrow, mincol] = find(distances==minDistance);
  length(minrow);
  for i = 1:length(minrow)
    fprintf('most similar sides are  %s  and  %s  \n', ...
	    sourceString(minrow(i), sourceInfo), sourceString(mincol(i), sourceInfo));
  end
  %% now find another 
  distances(minrow, mincol) = notMinFlag;

  minDistance = min(distances(:));
  fprintf('   second minimum distance between two pairs: %.2f\n', min(min(distances)));
  [minrow, mincol] = find(distances==minDistance);
  for i = 1:length(minrow)
    fprintf('second most similar sides are  %s  and  %s  \n', ...
	    sourceString(minrow(i), sourceInfo), sourceString(mincol(i), sourceInfo));
  end
  %% now find another that's not the two sides of the same conversation
  for i = 1:2:nsides
    distances(i,i+1) = notMinFlag;
    distances(i+1,i) = notMinFlag;
  end
  minDistance = min(distances(:));
  fprintf('    minimum distance between two non-related pairs: %.2f\n', minDistance);
  [minrow, mincol] = find(distances==minDistance);
  for i = 1:length(minrow)
    fprintf('these most similar sides are  %s  and  %s  \n', ...
	    sourceString(minrow(i), sourceInfo), sourceString(mincol(i), sourceInfo));
  end
end


function distance = euclidean(vec1, vec2)
  deltas = abs(vec1 - vec2);
  distance = sqrt(sum(deltas .* deltas));
end


%% return only sides that are within the threshold number of
%%   standard deviations on all dimensions
function [pruSstats, pruSourceInfo] = pruneExcessives(sstats, sourceInfo, featNames)
  for feat = 1: size(sstats, 2)
    histogram(sstats(:,feat))
    title(labelString(feat, featNames));
    pause(2);
  end

  fprintf('pruneExcessives\n');
  threshold = 25;   %  need to set sensibly!!!
  %%tmp = mean(score) + threshold * std(score);
  sstatsStdDevs = std(sstats);
  excessiveStatMatrix = sstats > abs(mean(sstats) + threshold * sstatsStdDevs);
  %% a boolean column vector with 1 for no-good sides
  excessives = sum(excessiveStatMatrix, 2) > 0;  
  for side = 1:size(sstats,1)
    if excessives(side) 
     %%fprintf('%s is excessive: exceeds %.1f stds on stats: \n          ', ...
%	      sourceString(side, sourceInfo), threshold);
      for feat = 1:size(sstats, 2)
	if excessiveStatMatrix(side, feat)
	  %% assume the mean is not significantly off zero
	  fprintf(' %d %s (%s) (%.2f, %.2f std devs, mean is %.4f, std is %.2f)  \n', ...
		  feat, sourceString(side, sourceInfo), ...
		  labelString(feat, featNames), sstats(side,feat), ...
		  sstats(side,feat) / std(sstats(:,feat)), ...
		  mean(sstats(:,feat)), std(sstats(:,feat)) );
	end
      end
    end
  end
  fprintf('pruning %d sides since excessive on some statistic\n', sum(excessives));
  pruSstats = sstats(excessives==0,:);
  pruSourceInfo = sourceInfo(excessives==0,:);
end


%% flag sides that exceed the threshold number of stds on some istyles dimensions 
function warnReExcessives(score, sstats, sourceInfo, featNames)
  Eight = 8;
  threshold = 15;   % arbitrary
  %%tmp = mean(score) + threshold * std(score);
  excessiveDimMatrix = abs(score) > mean(score) + threshold * std(score);
  excessiveDimMatrix = excessiveDimMatrix(:,1:Eight);
  %% a boolean column vector with 1 for no-good sides
  excessives = sum(excessiveDimMatrix, 2) > 0;  
  for side = 1:length(score)
    if excessives(side) 
      fprintf('Warning: %s is excessive: exceeds %.1f stds on dimensions: \n          ', ...
	      sourceString(side, sourceInfo), threshold);
      for dim = 1:Eight
	if excessiveDimMatrix(side, dim)
	  fprintf(' %d (%.2f, %.2f std devs)  ', ...
		  dim, score(side,dim), score(side,dim) / std(score(:,dim)));
	end
      end
      fprintf('\n');
    end
  end
end



%% for the experiments, apply this to tracks NOT in the training set 
%% each line of the predictions will contain
%% mturk-set1-06.wav, dim1score, dim2score, dim3score, ..., dim8score,
%%    , clip source, dimension chosen for, high/low, percentile
%% note that the anchors are generated above, in findClipsNearOrigin
function pickClipsForHumanSubjects(score, sourceInfo, metad)

  mturkfd = fopen('sox-for-mturk', 'w');
  clipPredsFd = fopen('predictions-for-mturk', 'w'); 

  for stimulusSet = 1:3
    fprintf('writing stimulusSet %d\n', stimulusSet);
    permutation = randperm(16);
    for dim=1:8
      for pole = [0 1]
	percentile = 1 + 98 * pole;  % 1 or 99
	dither = (stimulusSet - 2) * .1;
	exactPercentile = percentile + dither;
	stimFileName = sprintf('stimulus-%d-%2d.wav', ...
			       stimulusSet,  permutation(2*dim + pole));
%	xxx pick clip closest to exactPercentile
	fprintf(mturkfd, 'sox %s %s trim xxxx\n', xxx, stimFileName, yyy);
	fprintf(clipPredsFd, '%s, ', stimFileName);
%	fprintf(clipPredsFd, '%.3f, ', score-for-this-clip
      end
    end
  end
  fclose(mturkfd);
  fclose(clipPredsFd);
end


function pickClipsForExamination(score, sourceInfo, metad, soxfd)
  Eight = 8; 
  for dim = 1:Eight
    fprintf(soxfd, '# For dim %d: \n', dim);
    for percentileTarget = [.05     .10  .20  .50  .9   1.0 1.3 1.5 1.7 2.0 3.0 5.0  50   ...
			     99.95  99.9 99.8 99.5 99.1 99 98.7 98.5 98.3 98  97  95]
      writePercentileExemplar(score, sourceInfo, metad, dim, percentileTarget, soxfd);
    end
  end
end


function writePercentileExemplar(score, sourceInfo, metad, dim, percentileTarget, soxfd)
  Eight = 8; 
  target = prctile(score(:,dim), percentileTarget);
  matchDistance = abs(score(:,dim) - target);
  [val, ix] = min(matchDistance);
  fprintf(soxfd, '#  %s is closest to target  %5.1f (%.3f percentile), \n', ...
	  sourceString(ix, sourceInfo), target, percentileTarget);
  fprintf(soxfd, '#\t\t  dimvals: %4.1f %4.1f %4.1f %4.1f   %4.1f %4.1f %4.1f %4.1f  \n', ...
	  score(ix, 1:Eight));
  clipnum = metad(ix, 4);
  startSeconds = 30 * (clipnum - 1);
  wavFileName = metad(ix,2);
  fprintf(soxfd, 'sox %s exemplarDim%dPctle%0.2f.wav trim 0:%d 0:30 fade 0 -1 0.01\n', ...
	  wavFilePath(wavFileName), dim, percentileTarget, startSeconds);

end 



function path = wavFilePath(wavFileName)
  path = sprintf('/cygdrive/f/nigel/comparisons/en-swbd/disc?/wavfiles/sw0%4d.wav', ...
		 wavFileName);
end
			       


%% for subsets of different sizes,
%%   for each dim of coeff (loadings on each dim)
%%   report the cosine distance to the closest dimension in the subsetCoeff
%%     that is, the PCA loadings for the dimensions obtained with the subset
function compareWithSubsets(coeff, normalized)
  fprintf('Computing match to final dimensions as a function of time\n');
  fprintf('... see the plot for visualization\n');

  nsides = size(normalized, 1);
  nslices = 25;
  for numberOfSlices = 1:nslices
    percentage = 1.0/nslices * numberOfSlices;
    subset = normalized(1:round(percentage*nsides),:);
    subset = (subset - mean(subset)) ./ std(subset);   %% this helps a little
    [subsetCoeff, score, latent] = pca(subset);  
    for wholeSetDim=1:8
      %% fprintf('for whole set dim %d, cosines with subset dims:\n', wholeSetDim);
      cosines = zeros(1,8);
      for subsetDim=1:round(0.5 * size(subsetCoeff,2))
	%% don't even consider those in the lower half
	%% should report dim in subsetCoeff with highest cosine
	cosines(subsetDim) = absCosine(coeff(wholeSetDim,:), ...
				       subsetCoeff(subsetDim,:));
      end
      [m,d] = max(cosines);
      %%  fprintf(' %.2f at subsetDim %d \n', m,d);
      bestCosine(numberOfSlices, wholeSetDim) = m;
    end
  end

  clf('reset'); % clear figure 
  plot(bestCosine(:,1), '-+k');
  hold on 
  plot(bestCosine(:,2), '--og');
  plot(bestCosine(:,3), ':*r');
  plot(bestCosine(:,4), '-.xb');
  legend('dim 1', 'dim 2', 'dim 3', 'dim 4');
  axis([0 nslices 0 1]);
end


function ac = absCosine(vec1, vec2)
  ac = abs(dot(vec1, vec2) / (sqrt(dot(vec1, vec1)) * sqrt(dot(vec2, vec2))));
end


%% how do males and females differ?
%%   on what dimensions do they differ? and is it significant?
function examineMaleFemale(score, metad)
  GenderField = 6;
  femaleSides = ismember(metad(:,GenderField), 1);
  femaleDimvals = score(femaleSides,1:8);
  maleDimvals = score(~femaleSides,1:8);
  fprintf('\nGender comparison: for %d male sides and %d female sides\n', ...
	  length(maleDimvals), length(femaleDimvals));
  
  fprintf('  male means      %4.1f %4.1f %4.1f %4.1f   %4.1f %4.1f %4.1f %4.1f  \n', mean(maleDimvals));
  fprintf('  female means    %4.1f %4.1f %4.1f %4.1f   %4.1f %4.1f %4.1f %4.1f  \n', mean(femaleDimvals));

  %% to do t-tests,  since Matlab only does matchedpairs, export and do in excel 
  fprintf('\n')
end


function examineAB(score, metad)
  abField = 3;
  aSides = metad(:,abField)==1;
  bSides = metad(:,abField)==0;
  aDimvals = score(aSides,1:8);
  bDimvals = score(bSides,1:8);
  fprintf('Side comparison: for %d A sides and %d B sides\n', ...
	  length(aDimvals), length(bDimvals));
  fprintf('  A means    %4.1f %4.1f %4.1f %4.1f   %4.1f %4.1f %4.1f %4.1f  \n', mean(aDimvals));
  fprintf('  B means    %4.1f %4.1f %4.1f %4.1f   %4.1f %4.1f %4.1f %4.1f  \n', mean(bDimvals));
%  fprintf('  p values ');
%  for dim = 1:8
%    [h,p] = ttest(aDimvals(:,dim), bDimvals(:,dim));
%    fprintf(' %.3f', p);
%    end 
%  fprintf('\n');
end


function examineAge(score, metad)
  BirthYearField = 7;
  clf('reset'); % clear figure 
  for dim=1:8
    scatter(metad(:,BirthYearField), score(:,dim));
    correlation = corrcoef(metad(:,BirthYearField), score(:,dim)); 
    fprintf('birth-score correlation for dim %d is %.2f\n', ...
	    dim, correlation(1,2));
    pause(1);
  end
end


%% metad parallels sstats and score, where each row has 
%% 1=key, 2=filenum, 3=side, 4=clipNum, 5=speakerId, 6=isFemale, 7=birthyear, 8=topicID
function metad = assembleMetadata(basedir, sourceInfo)
  nsides = length(sourceInfo);
  metad = zeros(nsides, 8);
  metad(:,1) = 10 * sourceInfo(:,1) + sourceInfo(:,2);  % keys
  metad(:,2:4) = sourceInfo(:,:);

  fromLDC = readmatrix([basedir 'stats/metadata.txt']); % created by prepMetadata.sh
  toJoin = zeros(length(fromLDC), 7);
  toJoin(:,1) = 10 * fromLDC(:,1) + fromLDC(:,2);  % keys
  toJoin(:,2:7) = fromLDC;

  for i = 1:nsides
    idx = ismember(toJoin(:,1), metad(i,1));
    metad(i,5:8) = toJoin(idx,4:7);
  end
end 
		

%% compute mse of predictions of various kinds 
function examinePredictability(score, metad)
  score = score(:,1:8);
  evaluatePredictingMean(score);
  evaluatePredictingGenderMean(score, metad);
%  evaluatePredictingSideMean(score, metad);
  evaluatePredictingYoungOldMeans(score,metad);
%  evaluatePredictingSpeakerMeans(score,metad);  %% slow
%  evaluatePredictingPartnersOfSamePartnerMeans(score, metad); %% slow
end


function evaluatePredictions(truth, predictions, predictorName)
  errors = truth - predictions;
  mseVals = mean(errors .* errors);
  overallMse = mean(mseVals);
  fprintf('       mse when %s is %.3f\n        ', predictorName, overallMse);
  fprintf('       %.2f %.2f %.2f %.2f   %.2f %.2f %.2f %.2f\n', mseVals);
  end 


function evaluatePredictingMean(score)
  means = mean(score);
  nsides = length(score);
  predictions = repmat(means, nsides, 1);
  evaluatePredictions(score, predictions, 'predicting mean');
end 


function evaluatePredictingGenderMean(score, metad)
  GenderField = 6; 
  nsides = length(score);
  mfpreds = zeros(nsides, 8);
  femaleSides = ismember(metad(:,GenderField), 1);
  maleSides = ismember(metad(:,GenderField), 0);
  
  femaleDimvals = score(femaleSides,:);
  maleDimvals = score(~femaleSides,:);
  femaleMeans = mean(femaleDimvals);
  maleMeans = mean(maleDimvals);
  for i = 1:nsides
    if metad(i, GenderField) == 1
      mfpreds(i,:) = femaleMeans;
    else
      mfpreds(i,:) = maleMeans;
    end
  end
  evaluatePredictions(score, mfpreds, 'predicting gender mean');    
end
  

function evaluatePredictingYoungOldMeans(score, metad)
  BirthYearField = 7;
  nsides = length(score);
  agePreds = zeros(nsides, 8);
  meanBirthyear = mean(metad(:,BirthYearField));
  oldSides = metad(:,BirthYearField) < meanBirthyear;
  youngSides = metad(:,BirthYearField) >= meanBirthyear;
  
  oldmeans = mean(score(oldSides,:));
  youngmeans = mean(score(youngSides,:));
  for i = 1:nsides
    if metad(i,BirthYearField) > meanBirthyear
      agePreds(i,:) = youngmeans;
    else
      agePreds(i,:) = oldmeans;
    end
  end
  evaluatePredictions(score, agePreds, 'predicting young/old means');    
end

function other = otherSide(currentSide)
    if mod(currentSide,2) == 1
      other = currentSide + 1;
    else
      other = currentSide - 1;
    end
end


function evaluatePredictingSpeakerMeans(score, metad)
  minOthersNeeded = 20;   % minimum other sides from a speaker to do comparison
  dialogIdField = 2;
  speakerField = 5;

  nsides = length(score);
  spreds = zeros(nsides, 8);
  mpreds = repmat(mean(score), nsides, 1);
  spVar = zeros(nsides, 1);

  isComparable = zeros(nsides,1);
  for i = 1:nsides
    speaker = metad(i,speakerField);
    sidesWithThisSpeaker = metad(:,speakerField) == speaker;
    sidesWithThisSpeaker(i) = 0;
    %% exclude other clips from the same conversation
    sidesWithThisSpeaker(metad(:,dialogIdField) == metad(i,dialogIdField)) == 0;

    nOtherSides = sum(sidesWithThisSpeaker);
    %%fprintf('found %2d other sides with speaker %d\n', nOtherSides, speaker);
    if nOtherSides >= minOthersNeeded   % can edit to be == to investigate further
      isComparable(i) = 1;
      speakerMean = mean(score(sidesWithThisSpeaker,:));
      spreds(i,:) = speakerMean;
      spVar(i) = speakerVariation(speaker, sidesWithThisSpeaker, score);
    else
      spreds(i,:) = mean(score);
    end
  end
  
  fprintf(' matched comparison on the %d sides for which each has at least %d other calls by this speaker:\n', sum(isComparable), minOthersNeeded);
  evaluatePredictions(score(isComparable==1,:), spreds(isComparable==1,:), ...
		      'predicting speaker mean');
  evaluatePredictions(score(isComparable==1,:), mpreds(isComparable==1,:), ...
		      'predicting mean');    

  [maxval, maxix] = max(spVar);
  fprintf('the least consistent speaker is %d with mean std %.2f\n', ...
	  metad(maxix, speakerField), maxval);
  spVar(spVar == 0) = max(spVar);
  [minval, minix] = min(spVar); 
  fprintf('the most consistent speaker is %d with mean std %.2f\n', ...
	  metad(minix, speakerField), minval);  
  fprintf('!! but check that she was active in more than 1 or 2 sides!\n');
  
  %% at this point could go on to report the general style of this consistent person
  %% or get statistics on whether maleness or age correlates with lack of adaptability
end


function evaluatePredictingPartnersOfSamePartnerMeans(score, metad)
  minOthersNeeded = 20;   % minimum other sides from a speaker to do comparison
  speakerField = 5;
  nsides = length(score);
  opreds = zeros(nsides, 8);
  mpreds = repmat(mean(score), nsides, 1);
  isComparable = zeros(nsides,1);
  for currentSide = 1:nsides
    currentSpeaker = metad(currentSide, speakerField);
    interlocutorSide = otherSide(currentSide);
    interlocutor = metad(interlocutorSide,speakerField);
    %%fprintf('for side %d, file %d, interlocutorSide is %d and interlocutor is %d\n', ...
    %%  currentSide, metad(currentSide, 2), interlocutorSide, interlocutor);
    sidesWithInterloc = metad(:,speakerField) == interlocutor;
    nOtherSides = sum(sidesWithInterloc);
    %%fprintf('found %2d other sides with interloc %d\n', nOtherSides, interlocutor);
    if nOtherSides >= minOthersNeeded   % can edit to be == to investigate further
      sidesWithInterlocOfInteroc = zeros(nsides,1);
      isComparable(currentSide) = 1;
      %% !!!! slow !!!! 
      for i = 1:nsides
	sidesWithInterlocOfInterloc(i) = sidesWithInterloc(otherSide(i));
      end      
      %%fprintf('using %2d interloc-of-interloc sides for reference %d\n', ...
      %%  sum(sidesWithInterlocOfInterloc));
      speakerMean = mean(score(sidesWithInterlocOfInterloc==1,:));
      opreds(currentSide,:) = speakerMean;
    end
  end
  sidesWithInterlocOfInterloc(metad(:,speakerField) == currentSpeaker) == 0;
  fprintf(' matched comparison on the %d sides for which each has at least %d other calls by the other speaker:\n', sum(isComparable), minOthersNeeded);
  evaluatePredictions(score(isComparable==1,:), opreds(isComparable==1,:), 'predicting mean of partners of partner');
  evaluatePredictions(score(isComparable==1,:), mpreds(isComparable==1,:), 'predicting mean');    
end


function meanStd = speakerVariation(speaker, sidesWithSpeaker, score)
  score(sidesWithSpeaker==1,:);
  meanStd = mean(std(score(sidesWithSpeaker==1,:)));
  %% fprintf('for speaker %d, mean std is %.2f \n', speaker, meanStd);
end


function n = NSourceInfoFields()
  n = 3;  % file ID, track number, clip number
end


function str = labelString(i, featNames)
  labelCell = featNames(i);
  str = labelCell{1};
end


function writeLoadingsTable(coeff, featuresCellArray, header, outdir)
  pdimNames = {'self has turn', 'other has turn'; ... 
	       'silence', 'overlap'; ...
	       'turn take', 'turn yield'; ...
	       'backchannel cueing', 'backchannelling'; ...
	       'topic closing', 'topic continuation'; ...
	       'topic development', 'positive assessment'; ...
	       'empathy bid', 'indifference'; ...
	       'turn-hold fillers', 'bipartite construction'; ...
	       'long turn take', 'long turn yield'; ...
	       'late peaks', 'turn-initial fillers'; ...
	       'meta comment', 'bookended narrow pitch'; ...
	       'minor third cue' 'receiving action cue'; ...
	      };

  numberToWrite = min(length(coeff),12);
  intervals = intervalsForCSP();

  lfd = fopen([outdir 'loadingsTables.txt'], 'w');
  fprintf(lfd, '%s\n', header);

  for dim = 1:numberToWrite
    fprintf(lfd, '\nIS Dimension %d   ', dim);
    for i = 1:length(intervals)
      fprintf(lfd, "%.1f~%.1f ", intervals(i,1), intervals(i,2));
    end
    fprintf(lfd, '\n');
    for featType = 0:(length(coeff) / 7) - 1 
      lowNameCell = pdimNames(featType + 1, 1);
      highNameCell = pdimNames(featType + 1, 2);
      fprintf(lfd, '\n%17s ', lowNameCell{1});
      fprintf(lfd, '%5.2f %5.2f %5.2f  %5.2f  %5.2f %5.2f %5.2f ', ...
	      coeff(featType * 7 + 1 : featType * 7 + 7, dim));
      fprintf(lfd, ' %s\n', highNameCell{1});
    end
  end
  fclose(lfd);
end



%% to analyze turn-taking styles only, can interpolate these lines in
%% the main function just above normalization
%  turnTakingRelated = [1 2 3 4 9 12];
%  turnTakingRelatedMask = [1 1 1 1 1 1 1    1 1 1 1 1 1 1  1 1 1 1 1 1 1 ...
%  			     1 1 1 1 1 1 1  0 0 0 0 0 0 0  0 0 0 0 0 0 0 ...
%			     0 0 0 0 0 0 0  0 0 0 0 0 0 0  1 1 1 1 1 1 1 ...
%			     0 0 0 0 0 0 0  0 0 0 0 0 0 0  1 1 1 1 1 1 1];
%  %%TEMPORARY, TO GET DIMENSIONS RELATING ONLY TO TURN-TAKING
%  sstats = sstats(:, turnTakingRelatedMask==1);
%  featNames = featNames(turnTakingRelatedMask==1);
