local header                           = require('01_header')
local utils                            = require('02_utils')
local inlines                          = require('03_inlines')

local normalizeLabel                   = header.normalizeLabel
local indentOf                         = utils.indentOf
local stripN                           = utils.stripN
local colWidth                         = utils.colWidth
local isThematicBreak                  = utils.isThematicBreak
local parseInlines                     = inlines.parseInlines

local sFind, sGsub, sMatch, sRep, sSub =
	string.find, string.gsub, string.match, string.rep, string.sub
local tConcat, tInsert, tRemove        =
	table.concat, table.insert, table.remove

local mwTrim                           = mw.text.trim
local mwSplit                          = mw.text.split -- could be worth replacing: https://w.wiki/JzBY

local function itemHeader(l)
	local pre, bull = sMatch(l, "^([ \t]*)([%-%+%*])[ \t]")
	if bull then
		local rest = sSub(l, #pre + 3)
		return "bullet", bull, nil, colWidth(pre) + 2, rest
	end
	local pre2, num, delim = sMatch(l, "^([ \t]*)(%d%d?%d?%d?%d?%d?%d?%d?%d?)([%.%)])[ \t]")
	if num then
		local rest = sSub(l, #pre2 + #num + 3)
		return "ordered", delim, tonumber(num), colWidth(pre2) + #num + 2, rest
	end
end

local p = {}

function p.parse(text, frame)
	frame = frame or mw.getCurrentFrame()

	text = mw.text.unstripNoWiki(text)
	text = sGsub(text, "\r\n?", "\n")
	text = sGsub(text, "%z", "") -- §2.3 Insecure characters (U+0000)

	local refs = {}

	-- §4.7 Link reference definitions
	local function absorb(prefix, lbl, url, title)
		local k = normalizeLabel(lbl)
		if not refs[k] then refs[k] = { url = url, title = title or "" } end
		return "\n" .. (prefix or "")
	end

	local t = "\n" .. text .. "\n"

	-- 3-line, 2-line, and 1-line definitions with titles
	t = sGsub(t,
		'\n([ \t]*>?[ \t]*)%[([^%]]+)%]:[ \t]*\n?[ \t]*>?[ \t]*([^%s\n]+)[ \t]*\n?[ \t]*>?[ \t]*["\']([^"\'\n]*)["\'][ \t]*\n',
		function(pfx, l, u, ti) return absorb(pfx, l, u, ti) end)
	t = sGsub(t,
		'\n([ \t]*>?[ \t]*)%[([^%]]+)%]:[ \t]*\n?[ \t]*>?[ \t]*([^%s\n]+)[ \t]*\n?[ \t]*>?[ \t]*%(([^)\n]*)%)[ \t]*\n',
		function(pfx, l, u, ti) return absorb(pfx, l, u, ti) end)

	-- 2-line and 1-line definitions without titles
	t = sGsub(t, '\n([ \t]*>?[ \t]*)%[([^%]]+)%]:[ \t]*\n?[ \t]*>?[ \t]*([^%s\n]+)[ \t]*\n',
		function(pfx, l, u) return absorb(pfx, l, u, "") end)

	text = sSub(t, 2, -2)

	local lines = mwSplit(text, "\n")
	local blocks = {}
	local i, n = 1, #lines
	local inFence = false
	local fChar, fMin, fLang, fInd, fBuf = "", 0, "text", 0, {}

	while i <= n do
		local line = lines[i]
		local ind = indentOf(line)

		-- §4.5 Fenced code blocks (content lines)
		if inFence then
			local fc = sMatch(line, "^[ \t]*([`~]+)[ \t]*$")
			if fc and sSub(fc, 1, 1) == fChar and #fc >= fMin then
				inFence = false
				tInsert(blocks, frame:extensionTag('syntaxhighlight', tConcat(fBuf, "\n"), { lang = fLang }))
				fBuf = {}
			else
				tInsert(fBuf, stripN(line, fInd))
			end
			i = i + 1

			-- §4.9 Blank lines
		elseif mwTrim(line) == "" then
			if #blocks > 0 and blocks[#blocks] ~= "" then
				tInsert(blocks, "")
			end
			i = i + 1
		else
			local atxHh       = ind < 4 and sMatch(line, "^[ \t]*(#+)") or nil
			local atxRest     = atxHh and sMatch(line, "^[ \t]*#+(.*)")
			local isAtx       = atxHh and #atxHh <= 6 and
				(atxRest == "" or sSub(atxRest, 1, 1) == " " or sSub(atxRest, 1, 1) == "\t")

			-- §4.5 Opening fenced code blocks
			local fenceMark   = ind < 4 and sMatch(line, "^[ \t]*([`~][%`~][%`~]+)") or nil
			local isFenceOpen = false

			if fenceMark then
				local char = sSub(fenceMark, 1, 1)
				local fInfo = mwTrim(sMatch(line, "^[ \t]*[`~]+(.*)") or "")
				if not (char == "`" and sFind(fInfo, "`", 1, true)) then
					isFenceOpen = true
					fLang = mwTrim(sMatch(fInfo, "^[^ \t]+") or "")
					if fLang == "" then fLang = "text" end
				end
			end

			if isFenceOpen then
				fChar   = sSub(fenceMark, 1, 1)
				fMin    = #fenceMark
				fInd    = ind
				inFence = true; fBuf = {}
				i       = i + 1

				-- §4.2 ATX headings
			elseif isAtx then
				local body = mwTrim(atxRest)
				body = sGsub(body, "[ \t]+#+[ \t]*$", "")
				body = mwTrim(body)
				local eq = sRep("=", #atxHh)
				if body ~= "" then
					tInsert(blocks, eq .. " " .. parseInlines(body, refs) .. " " .. eq)
				else
					tInsert(blocks, eq .. " " .. eq)
				end
				i = i + 1

				-- §4.1 Thematic breaks
			elseif isThematicBreak(line) then
				tInsert(blocks, "----")
				i = i + 1

				-- §5.1 Block quotes
			elseif ind < 4 and sMatch(line, "^[ \t]*>") then
				local bq = {}
				local bqTypes = {}
				while i <= n do
					local cur = lines[i]
					local curInd = indentOf(cur)
					if curInd < 4 and sMatch(cur, "^[ \t]*>") then
						tInsert(bq, (sGsub(cur, "^[ \t]*>[ \t]?", "")))
						tInsert(bqTypes, "marker")
						i = i + 1
					elseif mwTrim(cur) ~= "" and curInd < 4 and not isThematicBreak(cur)
						and not sMatch(cur, "^[ \t]*[`~][%`~][%`~]+")
						and not sMatch(cur, "^[ \t]*[%-%+%*][ \t]")
						and not sMatch(cur, "^[ \t]*%d+[%.%)][ \t]")
						and not sMatch(cur, "^[ \t]*#") then
						tInsert(bq, cur)
						tInsert(bqTypes, "lazy")
						i = i + 1
					else
						break
					end
				end
				while #bq > 0 and mwTrim(bq[#bq]) == "" do
					tRemove(bq)
					tRemove(bqTypes)
				end

				local processedBq = {}
				for idx = 1, #bq do
					if idx > 1 and bqTypes[idx] == "lazy" then
						processedBq[#processedBq] = processedBq[#processedBq] .. " " .. bq[idx]
					else
						tInsert(processedBq, bq[idx])
					end
				end

				local bqHtml = mw.html.create('blockquote')
				bqHtml:wikitext(p.parse(tConcat(processedBq, "\n"), frame))
				tInsert(blocks, tostring(bqHtml))

				-- §5.2 / §5.3 List items and lists
			elseif sMatch(line, "^[ \t]*[%-%+%*][ \t]") or sMatch(line, "^[ \t]*%d+[%.%)][ \t]") then
				local ltype, lmarker, startNum = itemHeader(line)
				local items = {}
				local loose = false

				while i <= n do
					local cur = lines[i]
					if mwTrim(cur) == "" then break end

					local ctype, cmarker, cnum, ccol, firstContent = itemHeader(cur)
					if not ctype or ctype ~= ltype or cmarker ~= lmarker then break end

					i = i + 1
					local ilines = { firstContent }

					while i <= n do
						local nl = lines[i]
						if mwTrim(nl) == "" then
							local j = i + 1
							while j <= n and mwTrim(lines[j]) == "" do j = j + 1 end

							if j > n then
								i = j; break
							end

							local ntype, nmarker = itemHeader(lines[j])
							local nextInd        = indentOf(lines[j])

							if nextInd >= ccol then
								loose = true
								tInsert(ilines, "")
								i = j
							elseif ntype and ntype == ltype and nmarker == lmarker then
								loose = true
								i = j; break
							else
								i = j; break
							end
						else
							local nextInd = indentOf(nl)
							if nextInd >= ccol then
								tInsert(ilines, stripN(nl, ccol))
								i = i + 1
							elseif not itemHeader(nl)
								and not sMatch(nl, "^[ \t]*>")
								and not isThematicBreak(nl)
								and not sMatch(nl, "^[ \t]*[`~][`~][`~]+")
								and not sMatch(nl, "^[ \t]*#+[ \t]") then
								tInsert(ilines, nl)
								i = i + 1
							else
								break
							end
						end
					end

					tInsert(items, { lines = ilines, num = cnum })
				end

				local listEl = mw.html.create(ltype == "ordered" and "ol" or "ul")
				if ltype == "ordered" and startNum and startNum ~= 1 then
					listEl:attr("start", tostring(startNum))
				end

				for _, item in ipairs(items) do
					local li  = listEl:tag("li")
					local raw = tConcat(item.lines, "\n")
					local content

					if not loose and #item.lines == 1 then
						content = parseInlines(raw, refs)
					else
						content = mwTrim(p.parse(raw, frame))
						if loose then
							local parts = {}
							for block in (content .. "\n\n"):gmatch("(.-)\n\n") do
								block = mwTrim(block)
								if block ~= "" then
									if sMatch(block, "^<") then
										tInsert(parts, block)
									else
										tInsert(parts, "<p>" .. block .. "</p>")
									end
								end
							end
							content = tConcat(parts, "\n")
						else
							content = sGsub(content, "^<p>(.-)</p>$", "%1")
						end
					end

					li:wikitext(content)
				end

				tInsert(blocks, tostring(listEl))

				-- §4.4 Indented code blocks
			elseif ind >= 4 then
				local cBuf = {}
				while i <= n do
					local cl = lines[i]
					if indentOf(cl) >= 4 then
						tInsert(cBuf, stripN(cl, 4)); i = i + 1
					elseif mwTrim(cl) == "" then
						tInsert(cBuf, ""); i = i + 1
					else
						break
					end
				end
				while #cBuf > 0 and mwTrim(cBuf[#cBuf]) == "" do tRemove(cBuf) end
				if #cBuf > 0 then
					tInsert(blocks, frame:extensionTag('syntaxhighlight', tConcat(cBuf, "\n"), { lang = "text" }))
				end

				-- §4.8 Paragraphs / §4.3 Setext headings
			else
				local para   = {}
				local setext = nil

				while i <= n do
					local cur = lines[i]
					if mwTrim(cur) == "" then break end

					local ct  = mwTrim(cur)
					local cid = indentOf(cur)

					-- §4.3 Setext heading underline check
					if #para > 0 then
						if cid < 4 and sMatch(ct, "^=+$") then
							setext = "h1"; i = i + 1; break
						elseif cid < 4 and sMatch(ct, "^%-%-+$") then
							setext = "h2"; i = i + 1; break
						end
					end

					if #para > 0 then
						if cid < 4 and sMatch(cur, "^[ \t]*[`~][%`~][%`~]+") then break end
						if cid < 4 then
							local hh = sMatch(cur, "^[ \t]*(#+)")
							local hr = hh and sMatch(cur, "^[ \t]*#+(.*)")
							if hh and #hh <= 6 and (hr == "" or sSub(hr, 1, 1) == " " or sSub(hr, 1, 1) == "\t") then break end
						end
						if isThematicBreak(cur) then break end
						if cid < 4 and sMatch(cur, "^[ \t]*>") then break end
						if sMatch(cur, "^[ \t]*[%-%+%*][ \t]") then break end
						if sMatch(cur, "^[ \t]*1[%.%)][ \t]") then break end
					end

					tInsert(para, cur)
					i = i + 1
				end

				if #para > 0 then
					local body = mwTrim(tConcat(para, "\n"))
					if setext then
						body = sGsub(body, "\n", " ")
						if setext == "h1" then
							tInsert(blocks, "= " .. parseInlines(body, refs) .. " =")
						elseif setext == "h2" then
							tInsert(blocks, "== " .. parseInlines(body, refs) .. " ==")
						end
					else
						-- §6.8 Soft line breaks
						tInsert(blocks, parseInlines(body, refs))
					end
				end
			end
		end
	end

	if inFence then
		tInsert(blocks, frame:extensionTag('syntaxhighlight', tConcat(fBuf, "\n"), { lang = fLang }))
	end

	return tConcat(blocks, "\n")
end

function p.main(frame)
	local text = frame.args[1] or frame:getParent().args[1] or ""
	if text == "" then return "" end
	return p.parse(text, frame)
end

return p
