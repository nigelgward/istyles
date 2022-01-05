%% Spring 2020 - June 2021, Nigel Ward 
%% examinePredictability.m
%% Examine predictability and variation across speakers etc.


function examinePredictability(score, metad)
  isComparable = comparableSubset(metad);
  score = score(isComparable==1,1:8);  % only the comparables, only the first 8 dim 
%  score = score(isComparable==1,:); % use this instead if want to consider all dims
  metad = metad(isComparable==1,:);
  speakerList1 = unique(metad(:,speakerField()));
  fprintf('examining over %d speakers\n', length(speakerList1));

  globalMSEs = evaluatePredictingMean(score);
  spMSEs = evaluatePredictingSpeakerMeans(score,metad);
  printEightPercents('error reductions from global to per-speaker', ...
		    (globalMSEs - spMSEs) ./ globalMSEs);
  mfMSEs = evaluatePredictingGenderMean(score, metad);
  printEightPercents('error reductions from global to per-gender', ...
		    (globalMSEs - mfMSEs) ./ globalMSEs);
  %evaluatePredictingSideMean(score, metad);   % A or B; firstcomer to the conversation; miniscule effect
  yoMSEs = evaluatePredictingYoungOldMeans(score,metad);
  printEightPercents('error reductions from global to per age class', ...
		    (globalMSEs - yoMSEs) ./ globalMSEs);

  evaluatePredictingStageMeans(score,metad);  % also miniscule
%   evaluateUsingBothPartnersMeans(score, metad); 
end


%% return a binary vector, indicating for each clip whether there are 
%% enough other clips from the same speaker to form a meaningful references
function isComparable = comparableSubset(metad)
  minOthersNeeded = 20;  
  nsides = length(metad);
  isComparable = zeros(nsides,1);
  for i = 1:nsides
    vec = isFromSameSpeakerDifferentDialog(i, metad);
    isComparable(i) = sum(vec) >= minOthersNeeded;
  end
  fprintf('Found %d clips that each have at least %d other-call clips by the same speaker:\n', ...
	  sum(isComparable), minOthersNeeded);
  fprintf('  so the matched comparisons will be done on these, not the full %d-clip set\n', ...
	  length(metad));
end

    
function vec = isFromSameSpeakerDifferentDialog(clip, metad)
  dialogIdField = 2;
  speaker = metad(clip,speakerField());
  vec = (metad(:,speakerField()) == speaker);
  vec(metad(:,dialogIdField) == metad(clip,dialogIdField)) = 0;  % axe same-dialog clips
end


function [perDimMSEs, overallMse] = evaluatePredictions(truth, predictions, predictorName)
  %% implicitly weighted, since the earlier dimensions have higher stds
  errors = truth - predictions;
  sqErrors = errors.*errors;
  perDimMSEs = mean(sqErrors,1);  % per-dimension mse
  overallMse = mean(sum(sqErrors,2));  % mean of per-clip squared Euclidean distances
  overallEuclidean = mean(sqrt(sum(sqErrors,2)));  % mean of per-clip Euclidean distances 
  fprintf('    when using _%s_ avg Euclidean distance is %.3f ; per-dimension MSEs are ...\n', ...
	  predictorName, overallEuclidean);
  fprintf('    %.2f %.2f %.2f %.2f   %.2f %.2f %.2f %.2f\n', perDimMSEs);
end 


function mses = evaluatePredictingMean(score)
  means = mean(score);
  predictions = repmat(means, length(score), 1);
  mses = evaluatePredictions(score, predictions, 'global mean');
end 

function vec = makeFemaleVec(metad)
  vec = (metad(:,genderField()) == 1);
end


function mses = evaluatePredictingGenderMean(score, metad)
  mses = evalPredsByClass(score, metad, makeFemaleVec(metad), 'male', 'female');
end

function evaluatePredictingSideMean(score, metad)
  sideField = 3;  % 0 is left, 1 is right 
  rightSideVec = (metad(:,sideField) == 1);
  evalPredsByClass(score, metad, rightSideVec, 'A', 'B');
end


function mses = evaluatePredictingYoungOldMeans(score, metad)
  BirthYearField = 7;
  meanBirthYear = mean(metad(:,BirthYearField));
  fprintf('          (meanBirthYear was %.0f, hence mean age was %.0f)', ...
	   meanBirthYear, 1991 - meanBirthYear);
  olderVec = metad(:,BirthYearField) < meanBirthYear;
  mses = evalPredsByClass(score, metad, olderVec, 'young', 'old');    
end


%% stage in the dialog: early or late 
function evaluatePredictingStageMeans(score, metad)
  meanClipNum = mean(metad(:,clipNumField()));
  fprintf('          (meanClipnum was %.1f)\n', meanClipNum);
  laterVec = metad(:,clipNumField()) > meanClipNum;
  evalPredsByClass(score, metad, laterVec, 'earlier', 'later');    
end


function mses = evalPredsByClass(score, metad, membership, label0, label1);
  fprintf('\n');
  nsides = length(score);
  preds = zeros(nsides, size(score,2));
  class1means = mean(score(membership==1,:));
  class0means = mean(score(membership==0,:));
  printEightNumbers(label0, class0means);
  printEightNumbers(label1, class1means);
  preds(membership==1,:) = repmat(class1means, sum(membership),1);
  preds(membership==0,:) = repmat(class0means, nsides - sum(membership),1);
  mses = evaluatePredictions(score, preds, strcat(label0, '/', label1));
end

function printEightPercents(label, numbers)
  fprintf('        %7s ', label);
  fprintf('%5.1f%%', 100 * numbers(1:4));
  fprintf('  ');
  fprintf('%5.1f%%', 100 * numbers(5:8));
  fprintf('\n')
end


function printEightNumbers(label, numbers)
  fprintf('        %7s ', label);
  fprintf('%6.2f', numbers(1:4));
  fprintf('  ');
  fprintf('%6.2f', numbers(5:8));
  fprintf('\n')
end


function mses = evaluatePredictingSpeakerMeans(score, metad)
  nsides = length(score);
  spreds = zeros(nsides, size(score,2));         % predictions based on speaker average
  for i = 1:nsides
    speaker = metad(i,speakerField());
    referenceSet = isFromSameSpeakerDifferentDialog(i, metad);
    speakerMean = mean(score(referenceSet,:),1);
    spreds(i,:) = speakerMean;
  end
  mses = evaluatePredictions(score, spreds, 'speaker means');
  findPredictabilityExtremeSpeakers(score, spreds, metad);
end


function findPredictabilityExtremeSpeakers(score, spreds, metad) 
  errors = spreds - score;
  sqErrors = errors.*errors;
  perClipSqDistance = sum(sqErrors,2);
  perClipDistance = sqrt(perClipSqDistance);

  %% digress to see if the predictability is higher for fragments later in dialogs?
  meanClipNum = mean(metad(:,clipNumField()));
  laterVec = metad(:,clipNumField()) > meanClipNum;
  earlierVec = metad(:,clipNumField()) <= meanClipNum;
  fprintf('avg distance to speaker mean for early clips %.2f and late clips %.2f\n', ...
	 mean(perClipDistance(earlierVec)), mean(perClipDistance(laterVec)));
  
  speakerList = unique(metad(:,speakerField()));
  fprintf('looking for extreme speakers out of %d speakers\n', length(speakerList));
  femaleList = zeros(length(speakerList),1);
  perSpeakerError = zeros(length(speakerList),1);
  numberOfClipsWithSpeaker = zeros(length(speakerList),1);
  for i = 1:length(speakerList)
    speaker = speakerList(i);
    clipsWithThisSpeaker = metad(:, speakerField()) == speaker;
    numberOfClipsWithSpeaker(i) = sum(clipsWithThisSpeaker);
    perSpeakerError(i) = mean(perClipDistance(clipsWithThisSpeaker));
    indicesForClipsWithThisSpeaker = find(clipsWithThisSpeaker==1);
    gender = metad(indicesForClipsWithThisSpeaker(1), genderField);
    femaleList(i) = gender;
  end

  histogram(perSpeakerError,30);
  fprintf('fraction of speakers with informative averages is %.2f\n', ...
    sum(perSpeakerError < 44.2) / length(perSpeakerError));
  [maxval, maxix] = max(perSpeakerError);
  fprintf('the least consistent speaker is %d with mean mse %.2f across %d clips \n', ...
	  speakerList(maxix), maxval, numberOfClipsWithSpeaker(maxix));
  %% returns speaker 1236

  [minval, minix] = min(perSpeakerError);
  fprintf('the most consistent speaker is %d with mean mse %.2f across %d clips \n', ...
	  speakerList(minix), minval, numberOfClipsWithSpeaker(minix));
  %% returns speaker 1555

  fprintf('per-speaker mean sq distance: males %.2f, females %.2f\n', ...
	  mean(perSpeakerError(femaleList==0)),  mean(perSpeakerError(femaleList==1)));
end


%% columns of the metadata matrix, metad
function ix = clipNumField()
  ix = 4;
end
function ix = speakerField()
  ix = 5;   
end
function ix = genderField()
  ix = 6;   
end

