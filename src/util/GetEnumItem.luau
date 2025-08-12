return function(enum: Enum, item: string): EnumItem?
	if not enum or not item then
		return
	end

	for _index: number, enumItem: EnumItem in enum:GetEnumItems() do
		if enumItem.Name == item then
			return enumItem
		end
	end

	return
end
