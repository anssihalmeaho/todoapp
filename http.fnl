
ns http

import stdpr
import stdlog
import stdjson
import stdbytes
import stdfu
import stdhttp

import er

# HTTP status codes
Status-OK          = 200 # OK HTTP status code
Status-Created     = 201 # Created HTTP status code
Status-Bad-Request = 400 # Bad Request HTTP status code

# logger to use in this server
log = call(stdlog.get-default-logger map('prefix' 'todoapp: ' 'date' true 'time' true))

# set debug print functions
is-debug-on = false
debug = call(stdpr.get-pr is-debug-on)
debugpp = call(stdpr.get-pp-pr is-debug-on)

run = proc(router-info)
	import httprouter
	import stdos

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

	'none'
end

put-created = proc(w)
	call(stdhttp.write-response w Status-Created stdbytes.nl)
end

put-error = proc(w status-code text)
	call(stdhttp.write-response w status-code call(stdbytes.str-to-bytes text))
end

create-items-reader = func(uc-handler query-names-getter)
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

	proc(w r params)
		call(debug 'trying: ' try(call(proc()

		req = call(get-task-id-if-found params map())
		ctx = map()

		# query parameters are really not for case when id is given
		query-params = call(debug 'query: ' get(r 'query'))
		qp-getter = func(keyname cum) call(get-query-params keyname query-params cum) end
		query-map = call(stdfu.foreach call(query-names-getter) qp-getter map())

		req2 = put(req 'query-map' query-map)

		items = call(uc-handler ctx req2)

		_ = call(stdhttp.add-response-header w map('Content-Type' 'application/json'))
		_ _ response = call(stdjson.encode items):
		call(stdhttp.write-response w Status-OK response)

		end)))
	end
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

get-task-id-if-found = func(params inmap)
	has-id id-val = getl(params ':id'):
	cond(
		in(inmap 'selected-id') inmap
		has-id put(inmap 'selected-id' conv(id-val 'int'))
		inmap
	)
end

create-item-writer = func(task-id-var uc-handler ok-writer)
	proc(w r params)
		req = call(get-task-id-if-found params map())
		body-found body = getl(r 'body'):
		has-body = and(
			body-found
			gt(call(stdbytes.count body) 0)
		)
		decode-ok decode-err item = if( has-body
			call(stdjson.decode get(r 'body'))
			list(true '' map()) # cases when there is no body
		):

		if( decode-ok
			call(proc()
				ctx = map('task-id-var' task-id-var)
				code err resp = call(uc-handler ctx req item):
				http-code = case( code
					er.Invalid-Request Status-Bad-Request
					Status-Bad-Request
				)
				if( eq(code er.No-Error)
					call(ok-writer w)
					call(put-error w http-code err)
				)
			end)

			call(proc()
				_ = call(log 'error in decoding: ' decode-err)
				call(put-error w Status-Bad-Request 'invalid request body')
			end)
		)
	end
end

endns
