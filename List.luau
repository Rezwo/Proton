--!strict
local Types = require(script.Parent.Types)

local List = {}

function List.For<KeyType, ValueType>(Source : Types.ReadOnly<{ [KeyType] : ValueType }>, Processor : (KeyType, ValueType) -> Instance) : Types.ForObject<KeyType, ValueType>
	return {
		Type = "For",
		Source = Source,
		Processor = Processor
	}
end

return List