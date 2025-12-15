-- Frequency Check 0.3.2.2
-- Â© 2015-2020 RoLex

conf = {
	wait = 10,															-- check time in seconds
	next = 300,															-- next check in seconds
	stop = 100,															-- stop after number of runs
	trig = 0.5,															-- minimal trigger value
	exec = "tcpdump -nnpvvi enp3s0 -w <path>/dump_<date>.cap -c 10000",	-- full command to execute
	path = "",															-- path variable replacement
	date = "%Y%m%d_%H%M%S",												-- date variable format
	feed = 5,															-- minimal feed message class
	nick = "",															-- feed message nick to use
	repl = false														-- comma decimal separator
}

sets = {
	last = 0,
	runs = 0
}

function Main (file)
	if # conf.nick == 0 then
		conf.nick = VH.OpChat
	end

	if # conf.path == 0 then
		local _, path = VH:GetVHCfgDir ()
		conf.path = path
	end

	sets.last = os.time () + conf.next
	return 1
end

function VH_OnTimer (msec)
	if sets.runs >= conf.stop then
		return 1
	end

	local now = os.time ()

	if os.difftime (now, sets.last) >= conf.wait then
		sets.last = now
		local ok, freq = VH:GetServFreq ()

		if ok and freq then
			if conf.repl then
				freq = freq:gsub ("%.", ",")
			end

			if tonumber (freq) <= conf.trig then
				local exec = conf.exec
				exec = exec:gsub ("<path>", conf.path)
				exec = exec:gsub ("<date>", os.date (conf.date))
				os.execute (exec .. " &")
				VH:SendPMToAll ("Server frequency too low: " .. freq, conf.nick, conf.feed, 10)
				sets.last = sets.last + conf.next
				sets.runs = sets.runs + 1
			end
		end
	end

	return 1
end

-- end of file