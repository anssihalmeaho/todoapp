
ns main

import stdvar
import stddbc
import stdfu

import valuez
import http
import uc

# use logger from http
log = http.log

main = proc()
	# open valuez data store
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
	task-id-var = call(stdvar.new biggest-id)

	routes = map(
		'GET' list(

				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(http.create-middle call(http.create-items-reader col uc.task-getter-by-id uc.get-query-names))
				)

				list(
					list('todoapp' 'v1' 'tasks')
					call(http.create-middle call(http.create-items-reader col uc.task-getter uc.get-query-names))
				)
			)

		'POST' list(
				list(
					list('todoapp' 'v1' 'tasks')
					call(http.create-middle call(http.create-item-writer col task-id-var uc.task-adder http.put-created))
				)

				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(http.create-middle call(http.create-item-writer col task-id-var uc.task-modifier proc(w) 'ok' end))
				)
			)

		'DELETE' list(
				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(http.create-middle call(http.create-item-writer col task-id-var uc.task-deleter proc(w) 'ok' end))
				)
			)

		'PUT' list(
				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(http.create-middle call(http.create-item-writer col task-id-var uc.task-replacer proc(w) 'ok' end))
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
	_ = call(valuez.close db)
	'done'
end

endns
