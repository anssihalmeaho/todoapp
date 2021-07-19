
ns main

import stdhttp

import stdvar
import stdjson
import stdbytes
import stddbc
import stdfu
import stdlog

import valuez

import uc
import http

# logger to use in this server
log = call(stdlog.get-default-logger map('prefix' 'todoapp: ' 'date' true 'time' true))

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

	# define HTTP routes
	import httprouter

	routes = map(
		'GET' list(

				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(http.create-middle call(http.create-items-reader col uc.task-getter-by-id))
				)

				list(
					list('todoapp' 'v1' 'tasks')
					call(http.create-middle call(http.create-items-reader col uc.task-getter))
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

	import stdos
	# returns TCP port which is listened
	get-port = proc()
		found port = call(stdos.getenv 'TODOAPP_PORT'):
		if(not(found) ':8003' plus(':' port))
	end

	router-info = map(
		'addr'   call(get-port) #':8003'
		'routes' routes
	)

	# create new router instance
	router = call(httprouter.new-router router-info)

	# get router procedures
	listen = get(router 'listen')
	shutdown = get(router 'shutdown')

	# signal handler for doing router shutdown
	sig-handler = proc(signum sigtext)
		_ = call(log 'signal received: ' signum sigtext)
		call(shutdown)
	end
	_ = call(stdos.reg-signal-handler sig-handler 2)

	# wait and serve requests (until shutdown is made)
	_ = call(log '...serving...')
	_ = call(log 'listen: ' call(listen))

	_ = call(valuez.close db)
	'done'
end

endns
