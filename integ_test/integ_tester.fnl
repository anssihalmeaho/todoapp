
ns main

import stdjson
import stdhttp
import stddbc
import stdpr

# set debug print functions
debug = call(stdpr.get-pr true)
debugpp = call(stdpr.get-pp-pr true)

# Server URL
port-number = '8003'

verify = proc(condition err-str)
	call(stddbc.assert condition err-str)
end

check-response-ok = proc(resp expected-code)
	ok err = cond(
		eq(type(resp) 'string')
			list(false sprintf('error from server: %s' resp))
		not( eq(get(resp 'status-code') expected-code) )
			list(false sprintf('unexpected error code: %v' resp))
		list(true '')
	):
	call(verify ok err)
end

add-task = proc(task)
	server-endpoint = sprintf('http://localhost:%s/todoapp/v1/tasks' port-number)
	header = map('Content-Type' 'application/json')

	ok err body = call(stdjson.encode task):

	_ = call(verify ok err)
	response = call(stdhttp.do 'POST' server-endpoint header body)
	call(check-response-ok response 201)
end

get-tasks = proc()
	server-endpoint = sprintf('http://localhost:%s/todoapp/v1/tasks' port-number)
	response = call(stdhttp.do 'GET' server-endpoint map())
	_ = call(check-response-ok response 200)
	ok err val = call(stdjson.decode get(response 'body')):
	_ = call(stddbc.assert ok err)
	val
end

main = proc()
	task-A = map(
		'name'        'A'
		'description' 'text-A'
		'tags'        list('t1' 't2')
	)
	_ = call(add-task task-A)
	task-B = map(
		'name'        'B'
		'description' 'text-B'
	)
	_ = call(add-task task-B)
	_ = call(debugpp 'tasks: ' call(get-tasks))
	'OK'
end

endns
