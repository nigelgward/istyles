%% wordFreqAnalysis()
%% Nigel Ward, June 2020
%% writes a bash script to compute word ratios

%% the directory structure here is messed up;
%% some files are written to stats/ and some to wordstats/
%% reads some files from swbd-various, namely swbdCount.txt and swbdTotal.txt

function wordFreqAnalysis(score, metad)
  %% for testing:!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  %%  score = score(1:1000,:);
  %%  metad = metad(1:1000,:);
  %%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  for dim=1:8
    for direction = -1:2:+1
      if direction == -1
	clipsubset = score(:,dim) < prctile(score(:,dim), 10);
      else
	clipsubset = score(:,dim) > prctile(score(:,dim), 90);
      end 
      sidesToUse = metad(clipsubset==1,:);
      bashFilename = writeWordStatsBash(dim, direction, sidesToUse);
      system(['c:\cygwin64\bin\bash.exe ' bashFilename]);   
      %%system(['bash ' bashFilename]);   % 'c:\cygwin64\bin\bash.exe'
    end
  end
end


function scriptfile = writeWordStatsBash(dim, direction, clipsubset);
  scriptfile = 'wordstats/runStats.sh';
  fd = fopen(scriptfile, 'w');

  dimdir = sprintf("%1d%s", dim, posNegCode(direction));
  fprintf(fd, 'rm idim%sWords.txt\n\n', dimdir);
  nclips = size(clipsubset, 1);
  fprintf('processing %s, examining %d clips\n', dimdir, nclips);
  for i = 1:nclips
    thisclip = clipsubset(i,:);
    file = clipsubset(i,2);
    track = clipsubset(i,3);
    clip = clipsubset(i,4);
    dir = floor(file / 100);
    
    fprintf(fd, ' awk ''{if ($2 > %2d && $3 < %2d && $4 != "[silence]") {print $4}}'' ../../comparisons-partial/swb-transcripts/%2d/%4d/sw%4d%s-ms98-a-word.text >> idim%sWords.txt\n\n', startOfClip(clip), endOfClip(clip), dir, file, file, letterForTrack(track), dimdir);
  end
  
  fprintf(fd, 'wc -l idim%sWords.txt > idim%sTotal.txt\n\n', dimdir, dimdir);
  fprintf(fd, 'sort idim%sWords.txt | uniq -c | sort -k 2 > idim%sCounts.txt\n\n', ...
	  dimdir, dimdir);
  fprintf(fd, 'join -1 2 -2 2 idim%sCounts.txt swbd-various/swbdCounts.txt > tmpJoined.txt\n\n', ...
	  dimdir);
  fprintf(fd, 'awk -v zoneTotal=idim%sTotal.txt -f ../code/freqRatios.awk tmpJoined.txt > isratios%s.txt\n', dimdir, dimdir);
end


function ssec = startOfClip(clipnum)
  ssec = 30 * (clipnum - 1);
end

function esec = endOfClip(clipnum)
  esec = 30 * clipnum;
end

function letter = letterForTrack(track)
  if track == 0
    letter = 'A';
  else
    letter = 'B';
  end
end

function code = posNegCode(direction)
  if direction == -1
    code = 'lo';
  else
    code = 'hi';
  end
end

