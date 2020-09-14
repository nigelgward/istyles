%% anaPerceptions.m
%% Analyze Perceptions of Interation Styles 
%% Compare perceptions of a human subject with the model's predictions
%% Jonathan E. Avila, UTEP, August 2020, edits by Nigel Ward 

%% In QuestionPro, select the survey, then Analytics then Export 
%% then Raw Data Export, then  settings:
%   output_file_format = "CSV - Comma Separated Values (.csv)"
%   single_header_row = true
%   display_answer_codes_index = true
%   display_answer_values = false
%   display_question_codes_instead_of_text = true
%   exclude_content_urls = false
%   include_geo_code_additional_info = false
%   under Data Filters
%      start_date = null
%      end_date = null
%      response_status = "Completed"
%% then Download, then click on the created csv file to download it
%%   give it an appropriate name, like testStimSet4-Aug31.csv

%% the paths are relative to istyles/code, where this is located

    
%% the human subject's judgements, as exported from QuestionPro; omitting the .csv extension
%judgmFilename = 'materials/RawData--second-round-with-perfect-worker';
judgmFilename = '../experiment/pilot/RawData--7537745-08-31-2020-T185956';   

%% file made by copying the relevant lines from the preds file generated  by deriveISspace()

predictionsFilenameBis = '../experiment/pilot/rescaled-testset-preds-for-mturk-stimuli-set1.csv';  % what JAE used
predictionsFilenameBis = '../experiment/pilot/rescaled-testset-set1-preds-sorted.csv';  % subset of what JAE used
predictionsFilename = '../testIStyles/preds-for-mturk-testset-set1-resorted.csv'

%% how the scales in the survey are derived from the dimensions, as used in the predictions
scalesToDimsFilename = '../experiment/scales-to-dims-v4.txt';

N_STIMULI = 16;
N_DIMENSIONS = 8;
SCALE_SIZE = 7;

judgmTable = readtable(judgmFilename, 'RowNamesColumn', 1, 'VariableNamesLine', 3)
predictionsTable = readtable(predictionsFilename, 'RowNamesColumn', 1)
predictionsTableBis = readtable(predictionsFilenameBis, 'RowNamesColumn', 1)
scalesToDimsTable = readtable(scalesToDimsFilename),

%% Get a cell array of strings like x33_Vlc14_Generalizing_makingContrasts_
%% where V1c14 is a name set by the creator of the survey in QuestionPro
%% and Generalizing-makingContrasts is also set by the creator (?)
judgmVariableNames = judgmTable.Properties.VariableNames;

judgmResponseIDs = judgmTable.Properties.RowNames;
judgmTableWorkerIdIndex = match(judgmVariableNames, 'Worker_id$', 1);

for i=1:length(judgmResponseIDs)
  fprintf('========= ========= processing judgment set %d ========= ========= \n', i), 
  responseID = judgmResponseIDs(i);
  workerID = judgmTable{responseID, judgmTableWorkerIdIndex};
    
  userResponses = zeros(N_STIMULI,N_DIMENSIONS);
  
  %% Populate userResponses (16x8 double) with responses from judgmTable
  for stimulus = 1:N_STIMULI
    expression = sprintf('c%d_(?!.*comments)', stimulus);
    stimulusColIndices = match(judgmVariableNames, expression, N_DIMENSIONS);
    stimulusResponses = judgmTable{responseID,stimulusColIndices};
    userResponses(stimulus,:) = stimulusResponses;
  end
  
  %% Flip userResponses dimensions that have negative direction
  directions = scalesToDimsTable{:,'directionOfDimension'};
  colsToRescale = find(directions < 0);
  userResponses(:,colsToRescale) = SCALE_SIZE + 1 - userResponses(:,colsToRescale);
  
  %% Reorder userResponses dimensions to match scalesToDimsTable
  mapping = scalesToDimsTable{:,'correspondingDimension'};
  userResponses(:,mapping') = userResponses(:,:);
  
  systemPredictions = predictionsTable{:,1:N_DIMENSIONS};
  
  %% Find the correlation between userResponses and systemPredictions. 
  correlationType = 'Spearman';
  [rho, pval] = corr(userResponses, systemPredictions, 'Type', correlationType);
  rhoDiag = diag(rho);
  pvalDiag = diag(pval);
  
  %% Print stats.
  fprintf('responseID= %s, workerID= ''%d'', correlationType= ''%s''\n', ...
	  string(responseID), workerID, correlationType);
  for dim = 1:N_DIMENSIONS
    fprintf('\t\tdim%d:  rho= %6.3f   pval=%5.2f\n', dim, rhoDiag(dim), pvalDiag(dim));
  end
  fprintf('\n');
  
end


function matchingIndices = match(cellArray, expression, nExpected)
  startIndices = regexp(cellArray, expression);
  matchingIndices = ~cellfun(@isempty, startIndices);
  if ~ismember(1, matchingIndices) 
    error('failed to find any match for expression "%s"\n', expression);
  end
  if sum(matchingIndices) ~= nExpected
    error('for expression "%s", found %d matches, not %d "\n',  ...
	  expression, sum(matchingIndices), nExpected);
  end 
end
