// GML formatter. Run with: node format_gml.js
//
// Scope:
// - Recursively formats .gml files only (excluding .git, Build, and node_modules).
// - Normalizes indentation and spaces inside single-line array literals, e.g.
//   [ c_red, c_lime, c_blue ]. Array accessors such as _comp[$ _m] are unchanged.
//
// Control-block spacing:
// - Add a blank line before and after if, for, and while blocks.
// - Do not add a blank line before a control block when it follows a comment,
//   a function declaration/body opening, another if, or a closing brace (including
//   the closing-brace line in `} else {`).
// - Do not add a blank line before the first statement inside a function, if,
//   for, or while body. This includes an if or while directly inside a for loop,
//   and a while directly inside an if block.
// - Do not add a blank line after a control block when the next code line is a
//   closing brace; remove an existing blank line there as well.
// - Keep else and else-if branches attached to the preceding if block.

const fs = require("node:fs");
const path = require("node:path");

const projectRoot = path.resolve(__dirname, "..", "..");
const ignoredDirectories = new Set([".git", "Build", "node_modules"]);
const indentUnit = "  ";

function collectGmlFiles(directory, files = []) {
	for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
		if (entry.isDirectory() && !ignoredDirectories.has(entry.name)) {
			collectGmlFiles(path.join(directory, entry.name), files);
		} else if (entry.isFile() && entry.name.toLowerCase().endsWith(".gml")) {
			files.push(path.join(directory, entry.name));
		}
	}

	return files;
}

function formatIndentation(source) {
	const newline = source.includes("\r\n") ? "\r\n" : "\n";
	const lines = source.split(/\r\n|\n/);
	const delimiterStack = [];
	let inBlockComment = false;
	let quote = null;
	let escaped = false;

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const content = line.replace(/^\s+/, "");

		if (content.length === 0) continue;

		// Preprocessor directives and lines inside a multiline literal keep their
		// original indentation; their contents can have language-specific meaning.
		if (quote !== null || content.startsWith("#")) {
			updateLexicalState(line);
			continue;
		}

		const leadingClosers = countLeadingClosers(content, delimiterStack);
		const depth = Math.max(0, delimiterStack.length - leadingClosers);
		lines[i] = indentUnit.repeat(depth) + content;
		updateLexicalState(line);
	}

	const spacedControlBlocks = addControlBlockSpacing(lines);
	return addSingleLineArraySpacing(spacedControlBlocks).join(newline);

	function updateLexicalState(line) {
		for (let i = 0; i < line.length; i++) {
			const char = line[i];
			const next = line[i + 1];

			if (quote !== null) {
				if (escaped) {
					escaped = false;
				} else if (char === "\\") {
					escaped = true;
				} else if (char === quote) {
					quote = null;
				}
				continue;
			}

			if (inBlockComment) {
				if (char === "*" && next === "/") {
					inBlockComment = false;
					i++;
				}
				continue;
			}

			if (char === "/" && next === "/") break;
			if (char === "/" && next === "*") {
				inBlockComment = true;
				i++;
				continue;
			}
			if (char === "\"" || char === "'") {
				quote = char;
				escaped = false;
				continue;
			}

			if (char === "(" || char === "[" || char === "{") {
				delimiterStack.push(char);
			} else if (char === ")" || char === "]" || char === "}") {
				const expected = char === ")" ? "(" : char === "]" ? "[" : "{";
				if (delimiterStack[delimiterStack.length - 1] === expected) {
					delimiterStack.pop();
				}
			}
		}
	}

	function countLeadingClosers(text, stack) {
		let count = 0;
		for (const char of text) {
			if (char !== ")" && char !== "]" && char !== "}") break;
			const expected = char === ")" ? "(" : char === "]" ? "[" : "{";
			if (stack[stack.length - 1 - count] !== expected) break;
			count++;
		}
		return count;
	}
}

function addControlBlockSpacing(lines) {
	const tokens = tokenizeGml(lines);
	const pairs = new Map();
	const stack = [];

	for (let i = 0; i < tokens.length; i++) {
		const value = tokens[i].value;
		if (value === "(" || value === "[" || value === "{") {
			stack.push(i);
			continue;
		}

		const expectedOpen = value === ")" ? "(" : value === "]" ? "[" : value === "}" ? "{" : null;
		if (expectedOpen === null || tokens[stack[stack.length - 1]]?.value !== expectedOpen) {
			continue;
		}

		const openIndex = stack.pop();
		pairs.set(openIndex, i);
	}

	const before = new Set();
	const removeBefore = new Set();
	const after = new Set();
	const removeBlankAfter = new Set();
	const bodyEndByHeader = new Map();
	const openingByClosing = new Map([...pairs].map(([open, close]) => [close, open]));
	// Pass 1: map every control header to its body end first. The else-if
	// chain walk below needs entries of headers that appear later in the
	// token stream (e.g. the `if` in `} else if`), which a single forward
	// pass has not seen yet when the outer `if` is processed.
	for (let i = 0; i < tokens.length; i++) {
		if (tokens[i].value !== "if" && tokens[i].value !== "for" && tokens[i].value !== "while") continue;

		const parenIndex = i + 1;
		const conditionEnd = pairs.get(parenIndex);
		if (tokens[parenIndex]?.value !== "(" || conditionEnd === undefined) continue;

		const bodyIndex = conditionEnd + 1;
		const bodyEnd = pairs.get(bodyIndex);
		if (tokens[bodyIndex]?.value !== "{" || bodyEnd === undefined) continue;
		bodyEndByHeader.set(i, bodyEnd);
	}
	for (let i = 0; i < tokens.length; i++) {
		if (tokens[i].value !== "if" && tokens[i].value !== "for" && tokens[i].value !== "while") continue;

		const bodyEnd = bodyEndByHeader.get(i);
		if (bodyEnd === undefined) continue;

		const isElseIf = tokens[i].value === "if" && tokens[i - 1]?.value === "else";
		const followsIf = isImmediatelyAfterIf(tokens, pairs, openingByClosing, i);
		const followsFunctionHeader = isFunctionHeader(tokens, pairs, i - 1);
		const followsFunctionOrControlOpening = isImmediatelyInsideFunction(tokens, pairs, i - 1) ||
			isImmediatelyInsideControl(tokens, pairs, i - 1);
		const followsComment = hasCommentImmediatelyBefore(lines, tokens[i].line);
		const followsClosingBraceLine = /^\s*}\s*(?:\/\/.*)?$/.test(lines[tokens[i].line - 1] ?? "");
		const followsElseOpeningLine = /^\s*}\s*else\s*\{\s*(?:\/\/.*)?$/.test(lines[tokens[i].line - 1] ?? "");
		if (!isElseIf && !followsIf && !followsFunctionHeader && !followsFunctionOrControlOpening && !followsComment &&
			!followsClosingBraceLine && !followsElseOpeningLine) {
			before.add(tokens[i].line);
		}
		if (followsFunctionOrControlOpening) {
			removeBefore.add(tokens[i].line);
		}

		let finalBodyEnd = bodyEnd;
		let nextIndex = finalBodyEnd + 1;
		while (tokens[nextIndex]?.value === "else") {
			const branchIndex = nextIndex + 1;
			if (tokens[branchIndex]?.value === "if") {
				const branchEnd = bodyEndByHeader.get(branchIndex);
				if (branchEnd === undefined) break;
				finalBodyEnd = branchEnd;
				nextIndex = finalBodyEnd + 1;
				continue;
			}

			if (tokens[branchIndex]?.value === "{") {
				const elseEnd = pairs.get(branchIndex);
				if (elseEnd !== undefined) finalBodyEnd = elseEnd;
			}
			break;
		}

		const bodyEndLine = tokens[finalBodyEnd].line;
		let nextContentLine = bodyEndLine + 1;
		while (nextContentLine < lines.length && lines[nextContentLine].trim() === "") nextContentLine++;
		if (/^\s*}/.test(lines[nextContentLine] ?? "")) {
			removeBlankAfter.add(bodyEndLine);
		} else {
			after.add(bodyEndLine);
		}
	}

	const result = [];
	for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
		if (lines[lineIndex].trim() === "") {
			let previousContentLine = lineIndex - 1;
			while (previousContentLine >= 0 && lines[previousContentLine].trim() === "") previousContentLine--;
			if (removeBlankAfter.has(previousContentLine)) continue;
		}
		if (removeBefore.has(lineIndex) && result[result.length - 1]?.trim() === "") {
			result.pop();
		}
		if (before.has(lineIndex) && lineIndex > 0 && lines[lineIndex - 1].trim() !== "") {
			if (result[result.length - 1] !== "") result.push("");
		}

		result.push(lines[lineIndex]);

		if (after.has(lineIndex) && lineIndex < lines.length - 1 && lines[lineIndex + 1].trim() !== "") {
			if (result[result.length - 1] !== "") result.push("");
		}
	}

	return result;
}

function isFunctionHeader(tokens, pairs, closeIndex) {
	if (closeIndex < 0 || tokens[closeIndex]?.value !== ")") return false;
	const openIndex = [...pairs.entries()].find(([, end]) => end === closeIndex)?.[0];
	if (openIndex === undefined) return false;
	const functionNameIndex = openIndex - 1;
	return tokens[functionNameIndex]?.type === "word" &&
		tokens[functionNameIndex - 1]?.value === "function";
}

function isImmediatelyInsideFunction(tokens, pairs, openIndex) {
	if (tokens[openIndex]?.value !== "{") return false;
	const closeParenIndex = openIndex - 1;
	return isFunctionHeader(tokens, pairs, closeParenIndex);
}

function isImmediatelyInsideControl(tokens, pairs, openIndex) {
	if (tokens[openIndex]?.value !== "{") return false;
	const closeParenIndex = openIndex - 1;
	if (tokens[closeParenIndex]?.value !== ")") return false;
	const openParenIndex = [...pairs.entries()].find(([, end]) => end === closeParenIndex)?.[0];
	return openParenIndex !== undefined &&
		["if", "for", "while"].includes(tokens[openParenIndex - 1]?.value);
}

function isImmediatelyAfterIf(tokens, pairs, openingByClosing, ifIndex) {
	const previousIndex = ifIndex - 1;
	if (tokens[previousIndex]?.value !== "}") return false;
	const bodyOpen = openingByClosing.get(previousIndex);
	if (bodyOpen === undefined) return false;
	const conditionClose = bodyOpen - 1;
	if (tokens[conditionClose]?.value !== ")") return false;
	const conditionOpen = [...pairs.entries()].find(([, end]) => end === conditionClose)?.[0];
	return conditionOpen !== undefined && tokens[conditionOpen - 1]?.value === "if";
}

function hasCommentImmediatelyBefore(lines, lineIndex) {
	let cursor = lineIndex - 1;
	while (cursor >= 0 && lines[cursor].trim() === "") cursor--;
	if (cursor < 0) return false;

	const line = lines[cursor].trim();
	if (line.startsWith("//") || line.startsWith("/*") || line.endsWith("*/") || line.startsWith("*")) {
		return true;
	}
	return false;
}

function tokenizeGml(lines) {
	const tokens = [];
	let inBlockComment = false;
	let quote = null;
	let escaped = false;

	for (let lineIndex = 0; lineIndex < lines.length; lineIndex++) {
		const line = lines[lineIndex];
		if (line.trimStart().startsWith("#")) continue;

		for (let i = 0; i < line.length; i++) {
			const char = line[i];
			const next = line[i + 1];

			if (quote !== null) {
				if (escaped) escaped = false;
				else if (char === "\\") escaped = true;
				else if (char === quote) quote = null;
				continue;
			}

			if (inBlockComment) {
				if (char === "*" && next === "/") {
					inBlockComment = false;
					i++;
				}
				continue;
			}

			if (char === "/" && next === "/") break;
			if (char === "/" && next === "*") {
				inBlockComment = true;
				i++;
				continue;
			}
			if (char === "\"" || char === "'") {
				quote = char;
				escaped = false;
				tokens.push({ value: "<string>", type: "string", line: lineIndex, start: i, end: i + 1 });
				continue;
			}

			if (/[A-Za-z_]/.test(char)) {
				const start = i;
				while (i + 1 < line.length && /[A-Za-z0-9_]/.test(line[i + 1])) i++;
				tokens.push({ value: line.slice(start, i + 1), type: "word", line: lineIndex, start, end: i + 1 });
				continue;
			}
			if (/[0-9]/.test(char)) {
				const start = i;
				while (i + 1 < line.length && /[A-Za-z0-9_.]/.test(line[i + 1])) i++;
				tokens.push({ value: line.slice(start, i + 1), type: "number", line: lineIndex, start, end: i + 1 });
				continue;
			}

			if (!/\s/.test(char)) {
				tokens.push({ value: char, type: "symbol", line: lineIndex, start: i, end: i + 1 });
			}
		}
	}

	return tokens;
}

function addSingleLineArraySpacing(lines) {
	const tokens = tokenizeGml(lines);
	const pairs = new Map();
	const stack = [];

	for (let i = 0; i < tokens.length; i++) {
		const value = tokens[i].value;
		if (value === "[") {
			stack.push(i);
		} else if (value === "]" && tokens[stack[stack.length - 1]]?.value === "[") {
			const openIndex = stack.pop();
			pairs.set(openIndex, i);
		}
	}

	const arrayPairsByLine = new Map();
	const prefixKeywords = new Set([
		"case", "delete", "do", "else", "for", "globalvar", "if", "new",
		"not", "repeat", "return", "throw", "typeof", "until", "var", "while",
		"with", "yield",
	]);
	for (const [openIndex, closeIndex] of pairs) {
		const open = tokens[openIndex];
		const close = tokens[closeIndex];
		if (open.line !== close.line) continue;

		const inside = tokens.slice(openIndex + 1, closeIndex);
		if (inside.length === 0 || ["$", "?", "#", "|", "@"].includes(inside[0].value)) continue;

		const previous = tokens[openIndex - 1];
		const followsExpression = previous && (
			previous.type === "string" ||
			previous.type === "number" ||
			(previous.type === "word" && !prefixKeywords.has(previous.value)) ||
			[")", "]", "}"].includes(previous.value)
		);
		if (followsExpression) continue;

		if (!arrayPairsByLine.has(open.line)) arrayPairsByLine.set(open.line, new Map());
		arrayPairsByLine.get(open.line).set(open.start, close.start);
	}

	return lines.map((line, lineIndex) => {
		const pairsOnLine = arrayPairsByLine.get(lineIndex);
		if (!pairsOnLine) return line;

		const closes = new Set(pairsOnLine.values());
		let output = "";
		for (let i = 0; i < line.length; ) {
			if (pairsOnLine.has(i)) {
				const close = pairsOnLine.get(i);
				const inner = line.slice(i + 1, close);
				if (inner.trim().length === 0) {
					output += line.slice(i, close + 1);
					i = close + 1;
					continue;
				}

				output += "[ ";
				let next = i + 1;
				while (next < close && /\s/.test(line[next])) next++;
				if (closes.has(next)) {
					output = output.replace(/[ \t]+$/, "");
					output += " ";
				}
				i = next;
				continue;
			}

			if (closes.has(i)) {
				output = output.replace(/[ \t]+$/, "");
				output += " ]";
				i++;
				continue;
			}
			output += line[i];
			i++;
		}
		return output;
	});
}

const files = collectGmlFiles(projectRoot).sort();
let changed = 0;

for (const file of files) {
	const original = fs.readFileSync(file, "utf8");
	const formatted = formatIndentation(original);
	if (formatted !== original) {
		fs.writeFileSync(file, formatted, "utf8");
		changed++;
		console.log(`Formatted ${path.relative(projectRoot, file)}`);
	}
}

console.log(`Formatted ${changed} of ${files.length} GML files.`);
