
ns main

import stdjson
import stdhttp
import stddbc
import stdpr
import stdfu

# set debug print functions
test-print-on = false
debug = call(stdpr.get-pr test-print-on)
debugpp = call(stdpr.get-pp-pr test-print-on)

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

get-task-by-id = proc(task-id)
	server-endpoint = sprintf('http://localhost:%s/todoapp/v1/tasks/%d' port-number task-id)
	response = call(stdhttp.do 'GET' server-endpoint map())
	_ = call(check-response-ok response 200)
	ok err val = call(stdjson.decode get(response 'body')):
	_ = call(stddbc.assert ok err)
	_ = call(stddbc.assert eq(len(val) 1) 'Exactly one task assumed')
	head(val)
end

check-tasks-by-id = proc(task-ids task-A task-B)
	tasks = call(stdfu.ploop proc(tid cum) append(cum call(get-task-by-id tid)) end task-ids list())
	call(check-tasks tasks task-A task-B)
end

get-task-by-query-param = proc(query-param)
	server-endpoint = sprintf('http://localhost:%s/todoapp/v1/tasks?%s' port-number query-param)
	response = call(stdhttp.do 'GET' server-endpoint map())
	_ = call(check-response-ok response 200)
	ok err val = call(stdjson.decode get(response 'body')):
	_ = call(stddbc.assert ok err)
	val
end

modify-task = proc(task-id new-data)
	server-endpoint = sprintf('http://localhost:%s/todoapp/v1/tasks/%d' port-number task-id)
	header = map('Content-Type' 'application/json')

	ok err body = call(stdjson.encode new-data):

	_ = call(verify ok err)
	response = call(stdhttp.do 'POST' server-endpoint header body)
	call(check-response-ok response 200)
end

import-tasks = proc(tasks)
	server-endpoint = sprintf('http://localhost:%s/todoapp/v1/import/tasks' port-number)
	header = map('Content-Type' 'application/json')

	ok err body = call(stdjson.encode tasks):

	_ = call(verify ok err)
	response = call(stdhttp.do 'POST' server-endpoint header body)
	call(check-response-ok response 201)
end

importing-tasks = proc()
	new-tasks = list(
		map(
			'id'          1001
			'name'        'task-A'
			'description' 'text-A'
			'tags'        list('tag-A')
			'state'       'ongoing'
			'version'     'v100'
		)
		map(
			'id'          1002
			'name'        'task-B'
			'description' 'text-B'
			'tags'        list('tag-B')
			'state'       'new'
			'version'     'v101'
		)
		map(
			'id'          1003
			'name'        'task-C'
			'description' 'text-C'
			'tags'        list('tag-C')
			'state'       'done'
			'version'     'v102'
		)
	)

	# Read original tasks first
	original-tasks = call(get-tasks)

	# Import some new tasks
	_ = call(verify call(import-tasks new-tasks) 'import failed')
	new-ones = call(get-tasks)
	_ = call(verify eq(len(new-ones) len(new-tasks)) 'invalid length')
	new-names = call(stdfu.apply new-tasks func(x) get(x 'name') end)
	_ = call(verify in(new-names get(head(new-ones) 'name')) sprintf('invalid name: %v \n %v \n' new-names new-ones))

	# Import original tasks
	_ = call(verify call(import-tasks original-tasks) 'import failed')
	orig-ones = call(get-tasks)
	_ = call(verify eq(len(orig-ones) len(original-tasks)) 'invalid length')
	orig-names = call(stdfu.apply original-tasks func(x) get(x 'name') end)
	_ = call(verify in(orig-names get(head(orig-ones) 'name')) sprintf('invalid name: %v \n %v \n' new-names new-ones))

	'ok'
end

replace-task = proc(task-id new-data)
	server-endpoint = sprintf('http://localhost:%s/todoapp/v1/tasks/%d' port-number task-id)
	header = map('Content-Type' 'application/json')

	ok err body = call(stdjson.encode new-data):

	_ = call(verify ok err)
	response = call(stdhttp.do 'PUT' server-endpoint header body)
	call(check-response-ok response 200)
end

do-testing = proc()
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
	_ = call(check-tasks-by-id task-ids task-A task-B)

	# Modify task
	b-task-old = head(call(get-task-by-query-param 'name=B'))
	modif-part = map(
		'description' 'new-text'
		'version'     get(b-task-old 'version')
	)
	_ = call(modify-task get(b-task-old 'id') modif-part)

	# Ask task with query parameter
	b-task = head(call(get-task-by-query-param 'name=B'))
	_ = call(verify eq(get(b-task 'name') 'B') 'invalid task data')
	_ = call(verify eq(get(b-task 'description') 'new-text') 'invalid task data')

	# Replace task
	b-task-prev = head(call(get-task-by-query-param 'name=B'))
	new-b-task = map(
		'id'          get(b-task-prev 'id')
		'name'        get(b-task-prev 'name')
		'description' 'text-replaced'
		'tags'        list('new-tag')
		'state'       'done'
		'version'     get(b-task-prev 'version')
	)
	_ = call(replace-task get(new-b-task 'id') new-b-task)

	# Ask task with query parameter
	b-task-2 = head(call(get-task-by-query-param 'name=B'))
	_ = call(verify eq(get(b-task-2 'name') 'B') 'invalid task data')
	_ = call(verify eq(get(b-task-2 'description') 'text-replaced') 'invalid task data')
	_ = call(verify eq(get(b-task-2 'tags') list('new-tag')) 'invalid task data')
	_ = call(verify eq(get(b-task-2 'state') 'done') 'invalid task data')

	# Test some tasks importing
	_ = call(importing-tasks)

	'OK'
end

main = proc()
	result = call(debug 'test: ' try(call(do-testing)))
	_ = call(debug 'result: ' result)

	# Remove tasks
	task-ids-to-del = call(stdfu.apply call(get-tasks) func(v) get(v 'id') end)
	_ = call(delete-tasks task-ids-to-del)
	tasks = call(get-tasks)
	_ = call(verify eq(len(tasks) 0) sprintf('unexpected task count: %d' len(tasks)))

	case( result
		'OK' result
		'FAILED'
	)
end

endns

