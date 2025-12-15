-- AntiBanFor 0.0.1.1
-- © 2018-2020 RoLex

function VH_OnParsedMsgPM (nick, data, to)
	if data:sub (1, 8) == "BAN for " then
		local _, info = VH:GetMyINFO (to)

		if info and # info > 0 then
			local befo, slot, afte, size = info:match ("^(%$MyINFO %$ALL [^ ]+ .*<.+,S:)(%d+)(.*>%$.*%$.*%$.*%$)(%d+)%$$")

			if befo and slot and afte and size then
				slot, size = tonumber (slot or 0) or 0, tonumber (size or 0) or 0
				VH:SendToUser (befo .. _tostring (math.random (15, 25) + slot) .. afte .. _tostring (math.random (10240) * math.random (12345678, 123456789) + size) .. "$|", nick)
			end
		end

		return 0
	end

	return 1
end

function _tostring (val)
	if type (val) == "number" then
		return string.format ("%d", val)
	end

	return tostring (val)
end

-- end of file