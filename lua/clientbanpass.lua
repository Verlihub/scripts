-- Client Ban Pass 0.1.1.1
-- Â© 2015-2020 RoLex

function VH_OnParsedMsgPM (from, data, to)
	if data:match ("^BAN for .+") then
		VH:SendToUser ("$To: " .. to .. " From: " .. from .. " $<" .. from .. "> " .. data .. "|", to)
		return 0
	end

	return 1
end

-- end of file