import { Glob } from "bun";
import { join } from "path";

const OHMYGODBRUH = "src";
const OUT = "dist/Markdown.lua";

const files = Array.from(new Glob("*.lua").scanSync(OHMYGODBRUH)).sort();

const shim = `-- Version:	1.0
-- License:	MIT
-- Author:	t7ru [[User:Gabonnie]]
local _modules = {}
local _base_require = require
local function require(name)
    if _modules[name] then return _modules[name] end
    return _base_require(name)
end

`;

const parts: string[] = [shim];

for (const fname of files) {
	const moduleName = fname.replace(/\.lua$/, "");
	const content = await Bun.file(join(OHMYGODBRUH, fname)).text();
	parts.push(
		`_modules['${moduleName}'] = (function()\n${content.trim()}\nend)()\n\n`,
	);
}

const last = files.at(-1)!.replace(/\.lua$/, "");
parts.push(`return _modules['${last}']\n`);

await Bun.write(OUT, parts.join(""));
console.log(`Built ${OUT} from ${files.length} files:`);
files.forEach((f) => console.log(`  ${f}`));
