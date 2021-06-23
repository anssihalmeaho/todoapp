
ns main

import stdhttp
import stdvar
import stdjson
import stdbytes
import stddbc
import stdfu
import stdpr

import valuez

import domain

# https://www.smashingmagazine.com/2018/01/understanding-using-rest-api/
# https://restfulapi.net/resource-naming/
# https://www.kennethlange.com/avoid-data-corruption-in-your-rest-api-with-etags/

/*
 - logging
 - http-status code symbols
 - port as env.var
*/

# set debug print functions
is-debug-on = false
debug = call(stdpr.get-pr is-debug-on)
debugpp = call(stdpr.get-pp-pr is-debug-on)

create-get-item-with-id = func(col)
	proc(w r params)
		selected-id = conv(get(params ':id') 'int')
		matched-items = call(valuez.get-values col call(domain.task-id-match selected-id))

		_ = call(stdhttp.add-response-header w map('Content-Type' 'application/json'))
		_ _ response = call(stdjson.encode matched-items):
		call(stdhttp.write-response w 200 response)
	end
end

create-get-all-matching-items = func(col)
	get-query-params = func(keyname qparams result-map)
		has-key query-str-list = getl(qparams keyname):

		if( has-key
			if( empty(query-str-list)
				result-map
				call(func()
					qnames = split(head(query-str-list) ',')
					cond(
						eq(qnames list('')) result-map
						put(result-map keyname qnames)
					)
				end)
			)
			result-map
		)
	end

	proc(w r)
		call(debug 'trying: ' try(call(proc()

		query-params = call(debug 'query: ' get(r 'query'))
		qp-getter = func(keyname cum) call(get-query-params keyname query-params cum) end
		query-map = call(stdfu.foreach call(domain.get-query-names) qp-getter map())

		query-func = call(domain.get-query-func query-map)
		all-items = call(valuez.get-values col func(item) call(query-func item) end)

		_ = call(stdhttp.add-response-header w map('Content-Type' 'application/json'))
		_ _ response = call(stdjson.encode all-items):
		call(stdhttp.write-response w 200 response)

		end)))
	end
end

is-valid-version = func(has-version version)
	check-version-format = func(vers)
		import stdstr
		and(
			call(stdstr.is-digit slice(version 1))
			call(stdstr.startswith version 'v')
		)
	end

	cond(
		not(has-version)                        list(false 'version not found')
		not(eq(type(version) 'string'))         list(false 'version assumed to be string')
		lt(len(version) 2)                      list(false sprintf('too short version (%s)' version))
		not(call(check-version-format version)) list(false sprintf('invalid format for version (%s)' version))
		list(true '')
	)
end

create-middle = func(actual-handler)
	if( false
		proc(w r params)
			retv = try(call(actual-handler argslist():))
			_ = print('MIDDLE: ' retv)
			retv
		end

		actual-handler
	)
end

generate-new-version = func(vers)
	plus('v' str(plus(conv(slice(vers 1) 'int') 1)))
end

create-modify-item = func(col)
	proc(w r params)
		selected-id = conv(get(params ':id') 'int')
		_ _ new-item-1 = call(stdjson.decode get(r 'body')):

		has-version version = getl(new-item-1 'version'):
		check-ok err-text = call(is-valid-version has-version version):

		new-item = if( and(has-version check-ok)
			put(del(new-item-1 'version') 'version' call(generate-new-version version))
			new-item-1
		)

		# following part is same as in replace (duplicate code)
		all-ok err-descr = if( check-ok
			call(proc()
				id-matcher = call(domain.task-id-match selected-id)

				upd-func = func(x)
					if( call(id-matcher x)
						if( eq(get(x 'version') version)
							call(func()
								modified-item = call(domain.interleave-fields x new-item)
								list(true modified-item)
							end)
							list(false 'none')
						)
						list(false 'none')
					)
				end

				was-any-updated = call(valuez.update col upd-func)
				if( was-any-updated
					list(true '')
					list(false sprintf('task not found (id: %d) or version mismatch' selected-id))
				)
			end)

			list(false err-text)
		):

		if( not(all-ok)
			call(stdhttp.write-response w 400 call(stdbytes.str-to-bytes str(err-descr)))
			'success'
		)
	end
end

create-replace-item = func(col)
	proc(w r params)
		selected-id = conv(get(params ':id') 'int')

		_ _ new-item-1 = call(stdjson.decode get(r 'body')):
		has-id idvalue = getl(new-item-1 'id'):

		has-version version = getl(new-item-1 'version'):
		is-valid-vers vers-err = call(is-valid-version has-version version):

		new-item = if( and(has-version is-valid-vers)
			put(del(new-item-1 'version') 'version' call(generate-new-version version))
			new-item-1
		)

		check-ok err-text = cond(
			not(has-id)                  list(false sprintf('id not found in task (%d)' selected-id))
			not(eq(idvalue selected-id)) list(false sprintf('assuming same ids (%d <-> %d)' selected-id idvalue))
			not(is-valid-vers)           list(false vers-err)
			call(call(domain.get-task-validator new-item))
		):

		all-ok err-descr = if( check-ok
			call(proc()
				id-matcher = call(domain.task-id-match selected-id)

				upd-func = func(x)
					if( call(id-matcher x)
						if( eq(get(x 'version') version)
							list(true new-item)
							list(false 'none')
						)
						list(false 'none')
					)
				end

				was-any-updated = call(valuez.update col upd-func)
				if( was-any-updated
					list(true '')
					list(false sprintf('task not found (id: %d) or version mismatch' selected-id))
				)
			end)

			list(false err-text)
		):

		if( not(all-ok)
			call(stdhttp.write-response w 400 call(stdbytes.str-to-bytes str(err-descr)))
			'success'
		)
	end
end

create-del-item = func(col)
	proc(w r params)
		selected-id = conv(get(params ':id') 'int')
		taken-items = call(valuez.take-values col call(domain.task-id-match selected-id))

		case( len(taken-items)
			0 call(stdhttp.write-response w 400 call(stdbytes.str-to-bytes sprintf('task with id %d not found' selected-id)))
			'its ok'
		)
	end
end

create-add-item = func(col task-id-var)
	proc(w r params)
		_ _ item-1 = call(stdjson.decode get(r 'body')):
		has-id idvalue = getl(item-1 'id'):

		item = call(domain.fill-missing-fields item-1)

		is-valid err-text = call(call(domain.get-task-validator item)):

		_ _ next-id-val = if( and(is-valid not(has-id))
			call(stdvar.change task-id-var func(x) plus(x 1) end)
			list('not' 'valid' 'req')
		):

		if( has-id
			call(stdhttp.write-response w 400 call(stdbytes.str-to-bytes 'id not allowed in task when new task added'))
			if( is-valid
				call(proc()
					added-ok add-error = call(valuez.put-value col put(put(item 'id' next-id-val) 'version' 'v1')):
					if( added-ok
						call(stdhttp.write-response w 201 stdbytes.nl)
						call(stdhttp.write-response w 400 call(stdbytes.str-to-bytes sprintf('adding task failed: %s' add-error)))
					)
				end)

				call(stdhttp.write-response w 400 call(stdbytes.str-to-bytes sprintf('invalid task: %s' err-text)))
			)
		)
	end
end

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
					call(create-middle call(create-get-item-with-id col))
				)

				list(
					list('todoapp' 'v1' 'tasks')
					call(create-middle call(create-get-all-matching-items col))
				)
			)

		'POST' list(
				list(
					list('todoapp' 'v1' 'tasks')
					call(create-middle call(create-add-item col task-id-var))
				)

				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(create-middle call(create-modify-item col))
				)
			)

		'DELETE' list(
				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(create-middle call(create-del-item col))
				)
			)

		'PUT' list(
				list(
					list('todoapp' 'v1' 'tasks' ':id')
					call(create-middle call(create-replace-item col))
				)
			)
	)

	router-info = map(
		'addr'   ':8003'
		'routes' routes
	)

	# create new router instance
	router = call(httprouter.new-router router-info)

	# get router procedures
	listen = get(router 'listen')
	shutdown = get(router 'shutdown')

	# signal handler for doing router shutdown
	import stdos
	sig-handler = proc(signum sigtext)
		_ = print('signal received: ' signum sigtext)
		call(shutdown)
	end
	_ = call(stdos.reg-signal-handler sig-handler 2)

	# wait and serve requests (until shutdown is made)
	_ = print('...serving...')
	_ = print('listen: ' call(listen))

	_ = call(valuez.close db)
	'done'
end

endns
