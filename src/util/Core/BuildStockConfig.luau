return function(defaults: { [string]: any }, overrides: { [string]: any }?): { [string]: any }
	local resultBySection: { [string]: { [string]: any } } = {}

	local overridesBySection: { [string]: any } = overrides or {}

	for sectionName: string, defaultsSection: { [string]: any } in defaults do
		local resultSection: { [string]: any } = {}
		local overrideSection: { [string]: any }? = overridesBySection[sectionName]

		for key: string, defaultValue: any in defaultsSection do
			local value: any = overrideSection and overrideSection[key]
			resultSection[key] = value or defaultValue
		end

		resultBySection[sectionName] = resultSection
	end

	return resultBySection
end
