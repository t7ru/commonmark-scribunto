local header = {}

header.PUNCT = {}
for c in string.gmatch('!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~', ".") do
	header.PUNCT[c] = true
end

local ustringLower = (type(mw) == "table" and mw.ustring and mw.ustring.lower)
	or string.lower

local mwTrim = mw.text.trim

function header.normalizeLabel(lbl)
	return ustringLower(mwTrim(lbl):gsub("[ \t\r\n]+", " "))
end

return header
