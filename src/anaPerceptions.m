%% istyles/src/anaPerceptions.m
%% Analyze Perceptions of Interation Styles 
%% Compare perceptions of a human subject with the model's predictions
%% Jonathan E. Avila, UTEP, August 2020, edits by Nigel Ward 

%% In QuestionPro, select the survey, then Analytics then Manage Data,
%%  then Export, then on Raw Data Export, adjust the settings:
%   Output File Format = "CSV - Comma Separated Values (.csv)"
%   Single Header Row = TRUE
%     Display Answer Codes/Index = TRUE
%     Display Answer Values = false
%   Display Question Codes Instead OfText = TRUE
%   Show Question Not Displayed = false 
%   Exclude_content_urls = false
%   Include_geo_code_additional_info = false
%   ((obsolete under Data Filters: start_date = null,  end_date = null
%      response_status = "Completed"))
%% then Download, to create the file
%%    then click on the created csv file to actually download it
%%   give it an appropriate name, like testStimSet4-Aug31.csv

%% the paths are relative to istyles/src, the location of this file
%% invoke from that directory, with "run anaPerceptions.m"

STIMULI = 16;
DIMENSIONS = 8;
SCALE_STEPS = 7;
SCALE_CENTER = 4; 
    
%% human subjects' judgments, as exported from QuestionPro; omitting the .csv extension
judgmFilename = '../experiment/pilot/RawData--7537745-08-31-2020-T185956';
judgmFilename = '../experiment/pilot/testStimSet1-May10d'
judgmFilename = '../experiment/pilot/nw-not-real-may11'

%% deriveISspace() writes predictions-for-mturk-stimui.csv,
%% and from this I pick out by hand the lines for set1
predictionsFilename = '../testIStyles/preds-for-mturk-testset-set1.csv'

%% how each survey scale is derived from the dimensions
scalesToDimsFilename = '../experiment/scales-to-dims-v5.txt';

scalesToDimsTable = readtable(scalesToDimsFilename),
predictionsTable = readtable(predictionsFilename, 'RowNamesColumn', 1)
systemPredictions = predictionsTable{:,1:DIMENSIONS}

judgmTable = readtable(judgmFilename, 'RowNamesColumn', 1, 'VariableNamesLine', 4) %was 3

%% Get a cell array of strings like x33_Vlc14_Generalizing_makingContrasts_
%% where V1c14 refers to "variant 1 clip 14" 
%% and Generalizing-makingContrasts refers to the dimension solicited
judgmVariableNames = judgmTable.Properties.VariableNames;
judgmResponseIDs = judgmTable.Properties.RowNames;
judgmTableWorkerIdIndex = match(judgmVariableNames, 'Worker_id$', 1);
ageOfLearningEnglishIndex = match(judgmVariableNames, 'Age', 1);

%% assemble allResponses and allWorkerIDsCells, 
nworkers = length(judgmResponseIDs);
disp(nworkers)

allResponses = zeros(STIMULI, DIMENSIONS, nworkers); 
nValidWorkers = 0;
for i=1:nworkers
  responseID = judgmResponseIDs(i);
  workerIDcell = judgmTable{responseID, judgmTableWorkerIdIndex};
  thisWorkerID = workerIDcell{1};
  allWorkerIDsCells{i} = thisWorkerID;

  ageOfLearningEnglish = judgmTable{responseID, ageOfLearningEnglishIndex};
  fprintf('== assembling judgment set %d (worker %s): ', i, thisWorkerID), 

  rawUserResponses = extractRawResponses(judgmTable, judgmVariableNames, ...
					 responseID, STIMULI, DIMENSIONS);
  userResponses = reorganizeResponses(rawUserResponses, scalesToDimsTable, ...
				      DIMENSIONS);
  if submissionNotUsable(ageOfLearningEnglish, userResponses)
    fprintf('Not valid.\n');
    continue
  end

  nValidWorkers = nValidWorkers + 1; 
  allResponses(:,:,nValidWorkers) = userResponses;
  validWorkerIDs{nValidWorkers} = thisWorkerID;
end  % iteration over workers

allResponses = allResponses(:,:,1:nValidWorkers);  % exclude invalids

allResponses = excludeLowAgreementJudges(allResponses);
fprintf('of %d total workers, computing correlations for %d\n', nworkers, nValidWorkers);


meanResponses = mean(allResponses, 3);
fprintf('=== AVERAGES ... human match to system extremes  ===');
agreementOnExtremes(meanResponses, systemPredictions, DIMENSIONS);
fprintf('=== AVERAGES ... system match to human extremes  ===');
agreementOnExtremes(systemPredictions, meanResponses, DIMENSIONS);

for i=1:nValidWorkers
  fprintf('========= computing corr for predictions with judgments %d (worker %s) ========= \n', ...
	  i, validWorkerIDs{i}), workerIDcell = validWorkerIDs(i);
  variousCorrelations(allResponses(:,:,i), systemPredictions, ...
			      judgmResponseIDs(i), workerIDcell{1}, DIMENSIONS);
  agreementOnExtremes(allResponses(:,:,i), systemPredictions, DIMENSIONS);
end
fprintf('========= now comparing the two first workers ========= \n');
variousCorrelations(allResponses(:,:,1), allResponses(:,:,2), ...
			      judgmResponseIDs(i), workerIDcell{1}, DIMENSIONS);
fprintf('========= now comparing workers 2 and 3 ========= \n');
variousCorrelations(allResponses(:,:,2), allResponses(:,:,3), ...
			      judgmResponseIDs(i), workerIDcell{1}, DIMENSIONS);
%% end main 




function agreementOnExtremes(judgeRatings, systemPredictions, DIMENSIONS)
  judgeRatings
  for dim = 1:DIMENSIONS
    [maxVal, maxIx] = max(systemPredictions(:,dim));
    [minVal, minIx] = min(systemPredictions(:,dim));
    judgmentOfMin = judgeRatings(minIx, dim);
    judgmentOfMax = judgeRatings(maxIx, dim);
    fprintf('for dimension %d, human %4.1f and %4.1f, system %5.1f and %5.1f', ...
	    dim, judgmentOfMin, judgmentOfMax, minVal, maxVal);
    if judgmentOfMax > judgmentOfMin
      fprintf(' agreement %.2f \n', judgmentOfMax - judgmentOfMin);
    elseif judgmentOfMax == judgmentOfMin
      fprintf(' no opinion \n');
    else 
      fprintf(' counterindicated %.2f \n', judgmentOfMax - judgmentOfMin);
    end
  end 
end 
    


%% populate rawUserResponses (16x8 double) with responses from judgmTable
function responses = extractRawResponses(judgmTable, judgmVariableNames, ...
					 responseID, STIMULI, DIMENSIONS);
  responses = zeros(STIMULI, DIMENSIONS);
  for stimulus = 1:STIMULI
    expression = sprintf('c%d_(?!.*comments)', stimulus);
    stimulusColIndices = match(judgmVariableNames, expression, DIMENSIONS);
    stimulusResponses = judgmTable{responseID,stimulusColIndices};
    responses(stimulus,:) = stimulusResponses;
  end
end


function filtered = excludeLowAgreementJudges(allResponses);
  filtered = allResponses;   %***********need to implement this
end


%% Note that workers who were unable to pass the stereo check
%% or the attention check were already excluded in QuestionPro.
function invalid = submissionNotUsable(ageOfLearningEnglish, rawResponses)
  invalid = false;
  nResponses = size(rawResponses, 1) * size(rawResponses, 2);
  if sum(isnan(rawResponses)) > 0
    fprintf('Worker did not complete all screeens. ');
    invalid = true;
  end
  if ageOfLearningEnglish > 1
    fprintf('Worker did not learn English before age 12. ');
    invalid = true;
  end
  if length(rawResponses(rawResponses==0)) > .80 * nResponses
    fprintf('Worker skipped over 80%% of the ratings. ');
    invalid = true;
  end
  judgedScreens = hasSomeNonFours(rawResponses);   % column vector 
  if sum (1 - judgedScreens) >= 2 
    fprintf('Worker left all values at default for two or more stimuli. ');
    invalid = true;
  end
end
		 

function judgedScreens = hasSomeNonFours(rawResponses)
  nonDefaultSelections = sum(abs(rawResponses), 2);
  judgedScreens = nonDefaultSelections > 0;  % per screen
end


function variousCorrelations(judgments1, judgments2, responseID, workerID, ndims)
  computeAndPrintCorrelations(judgments1, judgments2, responseID, workerID, ndims);
  return
  %% now the half-line correlations,
  %%   where everything on the other side of zero is mapped to zero
  %% although these were never actually very informative
  j1pos = judgments1;
  j2pos = judgments2;
  j1pos(j1pos<0) = 0;
  j2pos(j2pos<0) = 0;
  fprintf('positive side\n')
  computeAndPrintCorrelations(j1pos, j2pos, responseID, workerID, ndims);

  j1neg = judgments1;
  j2neg = judgments2;
  j1neg(j1neg>0) = 0;
  j2neg(j2neg>0) = 0;
  fprintf('negative side\n')
  computeAndPrintCorrelations(j1neg, j2neg, responseID, workerID, ndims);
end


function computeAndPrintCorrelations(judgments1, judgments2, ...
				     responseID, workerID, ndims)
  doScatterplot(judgments1, judgments2, workerID, ndims);

  correlationType = 'Spearman';   % no reason to think it's linear, so use ranks 
  [rho, pval] = corr(judgments1, judgments2, 'Type', correlationType);
  rhoDiag = diag(rho);
  pvalDiag = diag(pval);

  fprintf('responseID= %s, workerID= ''%s'', correlationType= ''%s''\n', ...
	  string(responseID), workerID, correlationType);
  for dim = 1:ndims
    fprintf('\t\tdim%d:  rho= %6.3f   pval=%5.2f\n', dim, rhoDiag(dim), pvalDiag(dim));
  end
  fprintf('             average rho: %.2f\n', mean(rhoDiag));
end


function doScatterplot(userResponses, systemPredictions, workerID, ndims);
  hold off
  for dim = 1:ndims
    pause(1);
    scatter(userResponses(:,dim), systemPredictions(:,dim));
    lsline;  % least squares line 
    xlim([-3.5 3.5]);
    ylim([-9 +9]);
    infostring = sprintf('worker %s, dimension %d', workerID, dim);
    text(0.5,5, infostring);
  end
end 


function final = reorganizeResponses(userResponses, scalesToDimsTable, ndims)
  %% center responses at zero
  zeroCentered = userResponses - 4;   
  %% flip dimensions that have negative direction
  directions = scalesToDimsTable{:,'directionOfDimension'};
  colsToFlip = find(directions < 0);
  flipped=zeroCentered;
  flipped(:,colsToFlip) = - zeroCentered(:,colsToFlip);
  %% reorder dimensions accorting to scalesToDimsTable
  mapping = scalesToDimsTable{:,'correspondingDimension'};
  final=flipped;
  final(:,mapping') = final(:,:);
end


function matchingIndices = match(cellArray, expression, nExpected)
  startIndices = regexp(cellArray, expression);
  matchingIndices = ~cellfun(@isempty, startIndices);
  if ~ismember(1, matchingIndices) 
    error('failed to find any match for expression "%s"\n', expression);
  end
  if sum(matchingIndices) ~= nExpected
    error('for expression "%s", found %d matches, but expected %d "\n',  ...
	  expression, sum(matchingIndices), nExpected);
  end 
end
