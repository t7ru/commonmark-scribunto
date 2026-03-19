local header                     = require('01_header')
local utils                      = require('02_utils')

local PUNCT                      = header.PUNCT
local normalizeLabel             = header.normalizeLabel
local flanking                   = utils.flanking

local sFind, sGsub, sMatch, sSub =
	string.find, string.gsub, string.match, string.sub
local tConcat, tInsert           = table.concat, table.insert

local inlines                    = {}

function inlines.parseInlines(s, refs)
	local toks = {}
	local function protect(x)
		tInsert(toks, x)
		return "\127MDTK" .. #toks .. "\127"
	end

	-- §6.1 Code spans
	do
		local out, i, n = {}, 1, #s
		while i <= n do
			local b = sFind(s, "`", i, true)
			if not b then
				tInsert(out, sSub(s, i)); break
			end
			if b > i then tInsert(out, sSub(s, i, b - 1)) end
			local e = b
			while e < n and sSub(s, e + 1, e + 1) == "`" do e = e + 1 end
			local rlen = e - b + 1
			local j, found = e + 1, false
			while j <= n do
				local cb = sFind(s, "`", j, true)
				if not cb then break end
				local ce = cb
				while ce < n and sSub(s, ce + 1, ce + 1) == "`" do ce = ce + 1 end
				if ce - cb + 1 == rlen then
					local cont = sGsub(sSub(s, e + 1, cb - 1), "\n", " ")
					if sMatch(cont, "^ ") and sMatch(cont, " $")
						and sFind(cont, "[^ ]") then
						cont = sSub(cont, 2, -2)
					end
					tInsert(out, protect("<code>" .. mw.text.nowiki(cont) .. "</code>"))
					i = ce + 1; found = true; break
				end
				j = ce + 1
			end
			if not found then
				tInsert(out, sSub(s, b, e)); i = e + 1
			end
		end
		s = tConcat(out)
	end

	-- §6.5 Autolinks
	s = sGsub(s, "<([a-zA-Z][a-zA-Z0-9+%.%-]+:[^%s<>]*)>",
		function(u) return protect("[" .. u .. " " .. u .. "]") end)
	s = sGsub(s,
		"<([a-zA-Z0-9%.!#$%%&'%*%+/=%?%^_`{|}~%-]+@[a-zA-Z0-9][a-zA-Z0-9%-%.]*%.[a-zA-Z][a-zA-Z0-9%-]*)>",
		function(em) return protect("[mailto:" .. em .. " " .. em .. "]") end)

	-- §2.4 Backslash escapes
	s = sGsub(s, "\\([!\"#$%%&'()*+,%-./\\:;<=>?@%[%]^_`{|}~])",
		function(c) return protect(c) end)

	-- §6.7 Hard line breaks
	s = sGsub(s, "\\\n", protect("<br />\n"))
	s = sGsub(s, "  +\n", protect("<br />\n"))

	-- §6.4 Images
	s = sGsub(s, "!%[(.-)%]%s*%[([^%]]*)%]", function(alt, lbl)
		local ref = refs[normalizeLabel(lbl == "" and alt or lbl)]
		if ref then return protect("[[File:" .. ref.url .. "|alt=" .. alt .. "]]") end
	end)
	s = sGsub(s, '!%[(.-)%]%(([^%s)"\'<>]+)[ \t]+"[^"]*"[ \t]*%)',
		function(alt, url) return protect("[[File:" .. url .. "|alt=" .. alt .. "]]") end)
	s = sGsub(s, "!%[(.-)%]%(([^%s)'\"<>]+)[ \t]+'[^']*'[ \t]*%)",
		function(alt, url) return protect("[[File:" .. url .. "|alt=" .. alt .. "]]") end)
	s = sGsub(s, "!%[(.-)%]%(<([^>]*)>[ \t]*%)",
		function(alt, url) return protect("[[File:" .. url .. "|alt=" .. alt .. "]]") end)
	s = sGsub(s, "!%[(.-)%]%(([^%s)\"'<>]*)[ \t]*%)",
		function(alt, url) return protect("[[File:" .. url .. "|alt=" .. alt .. "]]") end)
	s = sGsub(s, "!%[([^%]%[]+)%]", function(alt)
		local ref = refs[normalizeLabel(alt)]
		if ref then return protect("[[File:" .. ref.url .. "|alt=" .. alt .. "]]") end
	end)

	local function formatLink(text, url)
		if sMatch(url, "^%a+:") or sMatch(url, "^//") then
			return protect("[" .. url .. " " .. text .. "]")
		else
			return protect("[[" .. url .. "|" .. text .. "]]")
		end
	end

	-- §6.3 Links
	s = sGsub(s, "%[(.-)%]%s*%[([^%]]+)%]", function(text, lbl)
		local ref = refs[normalizeLabel(lbl)]
		if ref then return formatLink(text, ref.url) end
	end)
	s = sGsub(s, "%[([^%]%[]+)%]%s*%[%]", function(text)
		local ref = refs[normalizeLabel(text)]
		if ref then return formatLink(text, ref.url) end
	end)
	s = sGsub(s, "%[(.-)%]%(<([^>%s]*)>[ \t]*%)",
		function(text, url) return formatLink(text, url) end)
	s = sGsub(s, '%[(.-)%]%(([^%s)"\'<>]+)[ \t]+"[^"]*"[ \t]*%)',
		function(text, url) return formatLink(text, url) end)
	s = sGsub(s, "%[(.-)%]%(([^%s)'\"<>]+)[ \t]+'[^']*'[ \t]*%)",
		function(text, url) return formatLink(text, url) end)
	s = sGsub(s, "%[(.-)%]%(([^%s)\"'<>]*)[ \t]*%)",
		function(text, url) return formatLink(text, url) end)
	s = sGsub(s, "%[([^%]%[]+)%]", function(text)
		local ref = refs[normalizeLabel(text)]
		if ref then return formatLink(text, ref.url) end
	end)

	-- §6.2 Emphasis and strong emphasis (frickin' delimiter stack algorithm)
	do
		local runs = {}
		local i, n = 1, #s
		while i <= n do
			local c = sSub(s, i, i)
			if c == "*" or c == "_" then
				local j = i
				while j < n and sSub(s, j + 1, j + 1) == c do j = j + 1 end
				local left, right = flanking(s, i, j, PUNCT)
				local canOpen, canClose
				if c == "*" then
					canOpen = left; canClose = right
				else
					local bef = i > 1 and sSub(s, i - 1, i - 1) or " "
					local aft = j < n and sSub(s, j + 1, j + 1) or " "
					canOpen   = left and (not right or PUNCT[bef])
					canClose  = right and (not left or PUNCT[aft])
				end
				tInsert(runs, {
					s = i,
					e = j,
					orig = j - i + 1,
					char = c,
					canOpen = canOpen,
					canClose = canClose,
					lc = 0,
					rc = 0
				})
				i = j + 1
			else
				i = i + 1
			end
		end

		local inserts = {}
		local function ins(pos, tag)
			if not inserts[pos] then inserts[pos] = {} end
			tInsert(inserts[pos], tag)
		end

		local ob = {}
		local ci = 1
		while ci <= #runs do
			local r   = runs[ci]
			local avr = r.orig - r.lc - r.rc
			if r.canClose and avr > 0 then
				local base = ob[r.char] or 0
				local foi  = nil
				for oi = ci - 1, base + 1, -1 do
					local op = runs[oi]
					if op.char == r.char and op.canOpen
						and (op.orig - op.lc - op.rc) > 0 then
						local ok = true
						if op.canClose or r.canOpen then
							local sum = op.orig + r.orig
							if sum % 3 == 0
								and not (op.orig % 3 == 0 and r.orig % 3 == 0) then
								ok = false
							end
						end
						if ok then
							foi = oi; break
						end
					end
				end
				if foi then
					local op  = runs[foi]
					local avo = op.orig - op.lc - op.rc
					avr       = r.orig - r.lc - r.rc
					local use = (avo >= 2 and avr >= 2) and 2 or 1
					local tag = use == 2 and "'''" or "''"
					ins(op.e - op.rc - use + 1, tag)
					op.rc = op.rc + use
					ins(r.s + r.lc, tag)
					r.lc = r.lc + use
				else
					ob[r.char] = ci - 1
					ci = ci + 1
				end
			else
				ci = ci + 1
			end
		end

		local dead = {}
		for _, run in ipairs(runs) do
			for k = run.s, run.s + run.lc - 1 do dead[k] = true end
			for k = run.e - run.rc + 1, run.e do dead[k] = true end
		end

		local out = {}
		for pos = 1, #s do
			if inserts[pos] then
				for _, tag in ipairs(inserts[pos]) do tInsert(out, tag) end
			end
			if not dead[pos] then tInsert(out, sSub(s, pos, pos)) end
		end
		if inserts[#s + 1] then
			for _, tag in ipairs(inserts[#s + 1]) do tInsert(out, tag) end
		end
		s = tConcat(out)
	end

	local escaped = {}
	local last = 1
	for ts, id, te in s:gmatch("()\127MDTK(%d+)\127()") do
		tInsert(escaped, mw.text.nowiki(sSub(s, last, ts - 1)))
		tInsert(escaped, toks[tonumber(id)])
		last = te
	end
	tInsert(escaped, mw.text.nowiki(sSub(s, last)))
	return tConcat(escaped)
end

return inlines
