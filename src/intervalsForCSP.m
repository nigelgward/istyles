%% for computeStyleParams

%% very unlikely to have values outside the range -10 ~ 10
function intervals = intervalsForCSP()
  intervals =  [-10 -2.4;
		-2.4 -1.4
		-1.4 -0.4;
		-0.4 0.4;
		0.4 1.4;
  		1.4 2.4;
		2.4 10];
end
