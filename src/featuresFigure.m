%% istyles/code/featuresFigure.m
%% generate a feature illustrating the feature computation workflow
%% derived from midlevel/src/applynormrot.m

%% run from istyles/illustrations/for-figure 

function featuresFigure()
  addpath '../../../midlevel/src';
  addpath '../../../midlevel/src/voicebox';

  aufilename = 'social-utep00-thru20s.au';
  audirname = './';
  aufilepath = [audirname aufilename];
  
  fssfile = '../../pcdparams/pbook.fss';
  rsfile = '../../pcdparams/rotationspec.mat';
  sifile = '../../pcdparams/sigmas.csv';          

  [signals, rate] = audioread(aufilepath);
  nsamples = size(signals,1);
  xaxis1 = (1:nsamples) / rate * 1.0;
  figure('Position', [10, -50, 800, 850])
  hold on

  leftLabelX1 = -2.6;
  leftLabelX2 = -3.0;

  subplot(5,1,1);
  plot(xaxis1,signals(:,1));
  ylim([-1.2, 1.2]);
  set(gca, 'xtick', []);
  text(leftLabelX1, .32, 'A channel');
  text(leftLabelX1, -.09, 'signal')

  subplot(5,1,2);
  plot(xaxis1,signals(:,2));
  ylim([-1.2, 1.2]);
  text(leftLabelX1, .32, 'B channel');
  text(leftLabelX1, -.09, 'signal')
  
  featurespec = getfeaturespec(fssfile);
  trackspec = createSingleTrackspec(aufilename, './');

  load(rsfile);

  provenance = 'nothing special';
  rotated = normrotoneAblations(trackspec, featurespec, ...
				nmeans, nstds, coeff, provenance, '/tmp', '/tmp');
  prosDimSigmas = csvread(sifile);
  
  labels = {'B has turn', 'A has turn',  'enth. overlap', ...
	    'silence', 'A yields turn', 'A takes turn'};
  
  nframes = size(rotated,1);
  xaxis2 = (1:nframes) * .01;
  for dim = 1:3
    subplot(5,1,dim+2);
    hold on 
    plot(xaxis2, rotated(:,dim) / prosDimSigmas(dim));
    plot(xaxis2, zeros(nframes));
    text(leftLabelX2, +2.5, labels{2*dim-1});
    text(leftLabelX2, -2.4, labels{2*dim+0});

    ylim([-3, +3])
    if dim < 3
      set(gca, 'xtick', []);
    end
    stats = computeDistributionStats(dim, rotated(:,dim), prosDimSigmas(dim));
    for bin = 1:7
      binString = sprintf('.%02d', round(100 * stats(bin)));
      text(1.0 + nframes * .01, -3.6 + .9*bin, binString);
      text(0.0 + nframes * .01, -3.6 + .9*bin, binString);
    end
  end
end 


function trackspec = createSingleTrackspec(filename, dirname)
  trackspec.side = 'l';
  trackspec.filename = filename;
  trackspec.directory = dirname;
  trackspec.path = [dirname filename];
end

  
