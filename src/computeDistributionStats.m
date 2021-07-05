
function stats = computeDistributionStats(dimNum, dimColumn, sigma)
  intervals = intervalsForCSP();          % endpoints of each bin: -10 to -2.4, etc.
  adjustedIntervals = intervals * sigma;  % normalize for this dimension's variance
  nIntervals = size(intervals,1);
  stats = zeros(1,nIntervals);
  %%fprintf('  dim %2d, mean is %.2f \n', dimNum, mean(dimColumn));
  for i = 1:nIntervals
    stats(i) = countFractionInRange(dimColumn, adjustedIntervals(i,1), adjustedIntervals(i,2));
  end
end


function frac = countFractionInRange(column, lowerBound, upperBound)
  frac = length(column(column>=lowerBound & column< upperBound)) /length(column);
  %%fprintf('frac between %4.1f and %4.1f is %.3f\n', lowerBound, upperBound, frac);
end
