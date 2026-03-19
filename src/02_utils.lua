local utils = {}

function utils.indentOf(s)
	local n = 0
	for i = 1, #s do
		local c = s:sub(i, i)
		if c == " " then
			n = n + 1
		elseif c == "\t" then
			n = n + (4 - n % 4)
		else
			break
		end
	end
	return n
end

function utils.stripN(s, n)
	local gone, i = 0, 1
	while i <= #s and gone < n do
		local c = s:sub(i, i)
		if c == " " then
			gone = gone + 1; i = i + 1
		elseif c == "\t" then
			local step = 4 - gone % 4
			if gone + step <= n then
				gone = gone + step; i = i + 1
			else
				return string.rep(" ", n - gone) .. s:sub(i + 1)
			end
		else
			break
		end
	end
	return s:sub(i)
end

function utils.colWidth(s)
	local n = 0
	for k = 1, #s do
		local c = s:sub(k, k)
		if c == "\t" then n = n + (4 - n % 4) else n = n + 1 end
	end
	return n
end

function utils.isThematicBreak(line)
	if utils.indentOf(line) >= 4 then return false end
	local s = line:gsub("[ \t]", "")
	if #s < 3 then return false end
	local c = s:sub(1, 1)
	if c ~= "-" and c ~= "*" and c ~= "_" then return false end
	for k = 2, #s do
		if s:sub(k, k) ~= c then return false end
	end
	return true
end

function utils.flanking(s, b, e, PUNCT)
	local bef                = b > 1 and s:sub(b - 1, b - 1) or " "
	local aft                = e < #s and s:sub(e + 1, e + 1) or " "
	local befSpace           = bef == " " or bef == "\t" or bef == "\n" or bef == "\r"
	local aftSpace           = aft == " " or aft == "\t" or aft == "\n" or aft == "\r"
	local befPunct, aftPunct = PUNCT[bef], PUNCT[aft]
	local left               = (not aftSpace) and (not aftPunct or befSpace or befPunct)
	local right              = (not befSpace) and (not befPunct or aftSpace or aftPunct)
	return left, right
end

return utils
