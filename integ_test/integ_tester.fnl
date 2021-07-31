
ns main

import stdjson
import stdhttp
import stddbc
import stdpr
import stdfu

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

delete-task = proc(task-id)
	server-endpoint = sprintf('http://localhost:%s/todoapp/v1/tasks/%d' port-number task-id)
	response = call(stdhttp.do 'DELETE' server-endpoint map())
	call(check-response-ok response 200)
end

delete-tasks = proc(task-ids)
	call(stdfu.ploop delete-task task-ids 'none')
end

check-tasks = proc(tasks task-A task-B)
	task-AR = call(stdfu.filter tasks func(item) eq(get(item 'name') get(task-A 'name')) end):
	task-BR = call(stdfu.filter tasks func(item) eq(get(item 'name') get(task-B 'name')) end):

	_ = call(verify eq(get(task-AR 'description') get(task-A 'description')) 'invalid task data')
	_ = call(verify eq(get(task-BR 'description') get(task-B 'description')) 'invalid task data')
	_ = call(verify eq(get(task-AR 'tags') get(task-A 'tags')) 'invalid task data')
	_ = call(verify eq(get(task-BR 'tags') list()) 'invalid task data')
	true
end

main = proc()
	# Add two tasks
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

	# Ask tasks and validate content
	tasks = call(debugpp 'tasks: ' call(get-tasks))
	_ = call(verify eq(len(tasks) 2) sprintf('unexpected task count: %d' len(tasks)))
	_ = call(check-tasks tasks task-A task-B)
	task-ids = call(stdfu.apply tasks func(v) get(v 'id') end)

	# Remove tasks
	_ = call(delete-tasks task-ids)
	tasks2 = call(debugpp 'after delete: ' call(get-tasks))
	_ = call(verify eq(len(tasks2) 0) sprintf('unexpected task count: %d' len(tasks2)))

	'OK'
end

endns

