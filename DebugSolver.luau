--// DEFINING TYPES

export type DebugSolverSettings = {
	Prefix: string;
	MismatchMessage: string;
}

export type Default = {
	Condition: boolean,
	DefaultValue: any
}

--// CONSTANTS

local DebugSolver = {}
DebugSolver.__index = DebugSolver

local DefaultPrefix = "DebugSolver [!] - "
local DefaultMismatch = " is not valid"

local Default: Default = {
	Condition = false,
	DefaultValue = nil
}

--// MAIN

function DebugSolver.new(Settings: {})
	local self = setmetatable({}, DebugSolver)
	
	self.DebugMode = false
	
	self:match(Settings, {
		Prefix = function(...)
			return self:matchType(..., "string")
		end;
		MismatchMessage = function(...)
			return self:matchType(..., "string")
		end,
	})
	
	self.Prefix = Settings.Prefix
	self.MismatchMessage = Settings.MismatchMessage
	
	return self
end

function DebugSolver:Debug(message)
	if (self.DebugMode) then
		print(message)
	end
end

function DebugSolver:broadcast(message: string, btype: string)
	if (btype == "error") then
		error(self.Prefix .. message, 3)
	elseif (btype == "warn") then
		warn(self.Prefix .. message)
	end
end

function DebugSolver:matchType(target: any, targetType: string)
	return typeof(target) == targetType;
end

function DebugSolver:matchList(target: {[number]: any}, condition: (any, number) -> any, default: {[any]: any})
	local queue = {};
	
	assert(target, DefaultPrefix .. "Missing Argument 1")
	assert(condition, DefaultPrefix .. "Missing Argument 2")
	
	for index, value in pairs(target) do
		local result, customBroadcast = condition(value, index)
		local newBroadcast = customBroadcast
		
		if (not customBroadcast) then
			newBroadcast = "Index " .. tostring(index) .. DefaultMismatch
		end
		
		if (not result) then
			if (default) then
				target[index] = default
			end
			
			table.insert(queue, {
				message = newBroadcast;
				type = "warn";
			});
		end
	end

	for _, v in pairs(queue) do
		task.spawn(function()
			print("broadcasting")
			self:broadcast(v.message, v.type)
		end)
	end
	
	return target
end

function DebugSolver:Default(conditionCheck: () -> any, DefaultValue: any) -- return value to a default value if it doesn't match
	return {
		ConditionCheck = conditionCheck,
		DefaultValue = DefaultValue
	}
end

function DebugSolver:match(target: {[string]: any}, conditions: {[any]: (any) -> any}, additionalInfo: {[string]: any})
	self:Debug("Matching")
	
	assert(target, DefaultPrefix .. "Missing Argument 1")
	assert(conditions, DefaultPrefix .. "Missing Argument 2")
	
	local queue = {};
	
	for subject, value in pairs(target) do
		self:Debug("CHECKING", subject, value, conditions, target)
		
		local conditionCheck
		local hasDefaultValue = typeof(conditions[subject]) == "table"
		
		if (hasDefaultValue) then -- has a default value
			conditionCheck = conditions[subject].ConditionCheck
		else
			conditionCheck = conditions[subject]
		end
		
		if (conditionCheck) then
			local result, customBroadcast = conditionCheck(value)
			local newBroadcast = customBroadcast

			if (not customBroadcast) then
				newBroadcast = subject .. (additionalInfo and " at Index " .. tostring(additionalInfo.Index) .. " of " .. additionalInfo.Source or '') .. DefaultMismatch
			end

			if (not result) then
				self:Debug(subject, "inserted to queue")

				table.insert(queue, {
					message = newBroadcast;
					type = "warn";
				});

				if (hasDefaultValue) then
					target[subject] = conditions[subject].DefaultValue
				end
			end
		end
	end
	
	for _, v in pairs(queue) do
		task.spawn(function()
			self:Debug("broadcasting")
			
			self:broadcast(v.message, v.type)
		end)
	end
	
	self:Debug(target)
	
	return target
end

return DebugSolver
