export type ClientPath = {
	controller: { [string]: any },
	module: { [string]: any },
	tag: { [string]: any },
	local_tag: { [string]: any },
}

export type ServerPath = {
	controller: { [string]: any },
	module: { [string]: any },
	tag: { [string]: any },
}

return table.freeze({})
