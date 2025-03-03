-- github.com/ccxmIcal
-- discord: sufi1337

local variables = {}

local function tableContains(tbl, item)
	for _, value in pairs(tbl) do
		if value == item then
			return true
		end
	end
	return false
end

local function operatorPrecedence(op)
	if op == "+" or op == "-" then
		return 1
	elseif op == "*" or op == "/" then
		return 2
	elseif op == ">" or op == "<" or op == ">=" or op == "<=" or op == "==" then
		return 3
	end
	return 0
end

local function evaluateExpression(expression)
	local tokens, operators = {}, {}
	local comparisonOperators = { ">", "<", ">=", "<=", "==" }

	for token in expression:gmatch("%S+") do
		if tonumber(token) then
			table.insert(tokens, tonumber(token))
		elseif variables[token] then
			table.insert(tokens, variables[token])
		elseif tableContains(comparisonOperators, token) then
			while #operators > 0 and operators[#operators] ~= "(" and operatorPrecedence(token) <= operatorPrecedence(operators[#operators]) do
				local right, left = table.remove(tokens), table.remove(tokens)
				local op = table.remove(operators)

				if op == ">" then table.insert(tokens, left > right)
				elseif op == "<" then table.insert(tokens, left < right)
				elseif op == ">=" then table.insert(tokens, left >= right)
				elseif op == "<=" then table.insert(tokens, left <= right)
				elseif op == "==" then table.insert(tokens, left == right) end
			end
			table.insert(operators, token)
		elseif token == "+" or token == "-" or token == "*" or token == "/" then
			while #operators > 0 and operators[#operators] ~= "(" and not tableContains(comparisonOperators, operators[#operators]) do
				local right, left = table.remove(tokens), table.remove(tokens)
				local op = table.remove(operators)

				if op == "+" then table.insert(tokens, left + right)
				elseif op == "-" then table.insert(tokens, left - right)
				elseif op == "*" then table.insert(tokens, left * right)
				elseif op == "/" then table.insert(tokens, left / right) end
			end
			table.insert(operators, token)
		elseif token == "(" then
			table.insert(operators, token)
		elseif token == ")" then
			while operators[#operators] ~= "(" do
				local right, left = table.remove(tokens), table.remove(tokens)
				local op = table.remove(operators)

				if op == "+" then table.insert(tokens, left + right)
				elseif op == "-" then table.insert(tokens, left - right)
				elseif op == "*" then table.insert(tokens, left * right)
				elseif op == "/" then table.insert(tokens, left / right) end
			end
			table.remove(operators)
		else
			print("Error: Undefined variable or value '" .. token .. "'.")
			return nil
		end
	end

	while #operators > 0 do
		local right, left = table.remove(tokens), table.remove(tokens)
		local op = table.remove(operators)

		if op == "+" then table.insert(tokens, left + right)
		elseif op == "-" then table.insert(tokens, left - right)
		elseif op == "*" then table.insert(tokens, left * right)
		elseif op == "/" then table.insert(tokens, left / right) end
	end
	return tokens[1]
end

local functions = {}

local function interpret(input)
	local lines = {}
	for line in input:gmatch("[^\n]+") do
		table.insert(lines, line)
	end

	local lineCount, lineIndex = #lines, 1
	local executeBlock = true

	local function readNextLine()
		local line = lines[lineIndex]
		lineIndex = lineIndex + 1
		return line
	end

	local function handleBlock()
		local block, depth = {}, 1
		while depth > 0 and lineIndex <= lineCount do
			local line = readNextLine()
			if line:match("{") then
				depth = depth + 1
			elseif line:match("}") then
				depth = depth - 1
			end
			if depth > 0 then
				table.insert(block, line)
			end
		end
		return table.concat(block, "\n")
	end

	while lineIndex <= lineCount do
		local line = readNextLine()

		if line:match("^var") then
			local varName, expression = line:match("var ([%w_]+) = (.+);")
			local result = evaluateExpression(expression)
			if result then variables[varName] = result end

		elseif line:match("^print") then
			local expression = line:match("print%((.+)%)")
			local result = evaluateExpression(expression)
			if result then print(result) end

		elseif line:match("^if") then
			local condition = line:match("if%((.+)%) {")
			executeBlock = evaluateExpression(condition)
			if executeBlock then
				local blockCode = handleBlock()
				interpret(blockCode)
				executeBlock = true
			end

		elseif line:match("^elseif") then
			local condition = line:match("elseif%((.+)%) {")
			if not executeBlock and evaluateExpression(condition) then
				local blockCode = handleBlock()
				interpret(blockCode)
				executeBlock = true
			else
				handleBlock()
			end

		elseif line:match("^else%s*{") then
			if not executeBlock then
				local blockCode = handleBlock()
				interpret(blockCode)
			else
				handleBlock()
			end
			executeBlock = true

		elseif line:match("^function") then
			local funcName, params = line:match("function ([%w_]+)%((.-)%) {")
			local blockCode = handleBlock()
			functions[funcName] = { params = params, body = blockCode }

		elseif line:match("([%w_]+)%((.-)%)") then
			local funcName, args = line:match("([%w_]+)%((.-)%)")
			if functions[funcName] then
				local func = functions[funcName]
				local params = {}
				for param in func.params:gmatch("[^, ]+") do table.insert(params, param) end
				local values = {}
				for value in args:gmatch("[^, ]+") do table.insert(values, evaluateExpression(value)) end

				local oldVars = {}
				for i, param in ipairs(params) do
					oldVars[param] = variables[param]
					variables[param] = values[i]
				end

				interpret(func.body)

				for i, param in ipairs(params) do
					variables[param] = oldVars[param]
				end
			end
		end
	end
end

local code = [[
var x = 8;
var y = 8;
var z = 5;
var w = 5;

print(x + y);

if (x > 7) {
	print(w);
} elseif (x == 7) {
	print(z);
} else {
	print(y);
}
]]

interpret(code)
