-- github.com/ccxmIcal
-- discord: sufi1337

local variables: { { any } } = {};

local function tableContains(table: { any }, item: any): boolean
	for _, value in pairs(table) do
		if value == item then
			return true;
		end
	end
	return false;
end

local function operatorPrecedence(operator: string): number
	if operator == "+" or operator == "-" then
		return 1;
	elseif operator == "*" or operator == "/" then
		return 2;
	elseif operator == ">" or operator == "<" or operator == ">=" or operator == "<=" or operator == "==" then
		return 3;
	end
	return 0;
end

local function evaluateExpression(expression)
	local tokens: { string } = {};
	local operators: { string } = {};
	local comparisonOperators: { string } = {">", "<", ">=", "<=", "=="};

	for token: string in expression:gmatch("%S+") do
		if tonumber(token) then
			table.insert(tokens, tonumber(token))
		elseif variables[token] then
			table.insert(tokens, variables[token])
		elseif tableContains(comparisonOperators, token) then
			while #operators > 0 and operators[#operators] ~= "(" and operatorPrecedence(token) <= operatorPrecedence(operators[#operators]) do
				local right: string = table.remove(tokens);
				local left: string = table.remove(tokens);
				local op: string? = table.remove(operators);

				if op == ">" then
					table.insert(tokens, left > right);
				elseif op == "<" then
					table.insert(tokens, left < right);
				elseif op == ">=" then
					table.insert(tokens, left >= right);
				elseif op == "<=" then
					table.insert(tokens, left <= right);
				elseif op == "==" then
					table.insert(tokens, left == right);
				end
			end
			table.insert(operators, token);
		elseif token == "+" or token == "-" or token == "*" or token == "/" then
			while #operators > 0 and operators[#operators] ~= "(" and not tableContains(comparisonOperators, operators[#operators]) do
				local right: string = table.remove(tokens);
				local left: string = table.remove(tokens);
				local op: string = table.remove(operators);

				if op == "+" then
					table.insert(tokens, left + right);
				elseif op == "-" then
					table.insert(tokens, left - right);
				elseif op == "*" then
					table.insert(tokens, left * right);
				elseif op == "/" then
					table.insert(tokens, left / right);
				end
			end
			table.insert(operators, token);
		elseif token == "(" then
			table.insert(operators, token);
		elseif token == ")" then
			while operators[#operators] ~= "(" do
				local right: string = table.remove(tokens);
				local left: string = table.remove(tokens);
				local op: string = table.remove(operators);

				if op == "+" then
					table.insert(tokens, left + right);
				elseif op == "-" then
					table.insert(tokens, left - right);
				elseif op == "*" then
					table.insert(tokens, left * right);
				elseif op == "/" then
					table.insert(tokens, left / right);
				end
			end
			table.remove(operators);
		else
			print("Error: Variable or value '" .. token .. "' is not defined.");
			return nil;
		end
	end

	while #operators > 0 do
		local right: string = table.remove(tokens)
	    local left: string = table.remove(tokens)
	    local op: string = table.remove(operators)
    
	    if op == "+" then
	    	table.insert(tokens, left + right);
	    elseif op == "-" then
	    	table.insert(tokens, left - right);
	    elseif op == "*" then
	    	table.insert(tokens, left * right);
	    elseif op == "/" then
	    	table.insert(tokens, left / right);
	    end
	end
	return tokens[1];
end



local function interpret(input: string): nil
	local lines: { string } = {};
	for line: string in input:gmatch("[^\n]+") do
		table.insert(lines, line);
	end

	local lineCount: number = #lines;
	local lineIndex: number = 1;
	local executeBlock: boolean = true;

	local function readNextLine(): string
		local line: string = lines[lineIndex];
		lineIndex += 1;
		return line;
	end

	local function handleBlock(): string
		local block: { string } = {};
		local depth: number = 1;
		while depth > 0 and lineIndex <= lineCount do
			local line: string = readNextLine();
			if line:match("{") then
				depth += 1;
			elseif line:match("}") then
				depth -= 1;
			end
			if depth > 0 then
				table.insert(block, line);
			end
		end
		return table.concat(block, "\n");
	end

	while lineIndex <= lineCount do
		local line: string = readNextLine();
		if line:match("^var") then
			local varName: string, expression: string = line:match("var ([%w_]+) = (.+);");
			local result: string = evaluateExpression(expression);
			if result then
				variables[varName] = result;
			end
		elseif line:match("^print") then
			local expression: string = line:match("print (.+);");
			local result: string = evaluateExpression(expression);
			if result then
				print(result);
			end
		elseif line:match("^if") then
			local condition: string = line:match("if (.+) {")
			executeBlock = evaluateExpression(condition)
			if executeBlock then
				local blockCode: string = handleBlock();
				interpret(blockCode);
				executeBlock = true;
			end
		end
	end
end

local code: string = [[
var x = 8;
var y = 8;
var z = 5;
var w = 5;
print z / w * x - 8;
if x > 7 {
print w;
}
]]

interpret(code);
