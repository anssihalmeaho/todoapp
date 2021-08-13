
ns main

import http

# use logger from http
log = http.log

new-store = proc()
	import valuez
	import stddbc
	import stdfu

	open-ok open-err db = call(valuez.open 'tasks'):
	_ = call(stddbc.assert open-ok open-err)

	cn-ok cn-err colnames = call(valuez.get-col-names db):
	_ = call(stddbc.assert cn-ok cn-err)

	col-exists = in(colnames 'tasks')
	col-opener = if( col-exists
		valuez.get-col
		valuez.new-col
	)
	col-ok col-err col = call(col-opener db 'tasks'):
	_ = call(stddbc.assert col-ok col-err)

	biggest-id = if( col-exists
		call(proc()
			items = call(valuez.get-values col func(x) true end)
			ids = call(stdfu.apply items func(item) get(item 'id') end)
			if( empty(ids)
				10
				call(stdfu.max ids func(x y) if(gt(x y) x y) end)
			)
		end)
		10
	)

	store-object = map(
		'get-values'  proc(matcher) call(valuez.get-values col matcher) end
		'take-values' proc(matcher) call(valuez.take-values col matcher) end
		'update'      proc(matcher) call(valuez.update col matcher) end
		'put-value'   proc(item) call(valuez.put-value col item) end
	)

	list(store-object biggest-id proc() call(valuez.close db) end)
end

main = proc()
	import stdvar
	import uc

	store biggest-id closer = call(new-store):
	task-id-var = call(stdvar.new biggest-id)

	routes = map(
		'GET' list(

				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(http.create-middle call(http.create-items-reader call(uc.new-task-getter-by-id store) uc.get-query-names))
				)

				list(
					list('todoapp' 'v1' 'tasks')
					call(http.create-middle call(http.create-items-reader call(uc.new-task-getter store) uc.get-query-names))
				)
			)

		'POST' list(
				list(
					list('todoapp' 'v1' 'tasks')
					call(http.create-middle call(http.create-item-writer call(uc.new-task-adder store task-id-var) http.put-created))
				)

				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(http.create-middle call(http.create-item-writer call(uc.new-task-modifier store) proc(w) 'ok' end))
				)
			)

		'DELETE' list(
				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(http.create-middle call(http.create-item-writer call(uc.new-task-deleter store) proc(w) 'ok' end))
				)
			)

		'PUT' list(
				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(http.create-middle call(http.create-item-writer call(uc.new-task-replacer store) proc(w) 'ok' end))
				)
			)
	)

	# returns TCP port which is listened
	get-port = proc()
		import stdos

		found port = call(stdos.getenv 'TODOAPP_PORT'):
		if(not(found) ':8003' plus(':' port))
	end

	router-info = map(
		'addr'   call(get-port)
		'routes' routes
	)

	_ = call(http.run router-info)
	_ = call(closer)
	'done'
end

endns
