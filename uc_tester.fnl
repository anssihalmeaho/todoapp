
ns main

import uc

import stdvar
import stdfu

new-simulated-store = proc()
	task-store = call(stdvar.new list())

	get-values = proc(matcher)
		tasklist = call(stdvar.value task-store)
		tasks = call(stdfu.filter tasklist matcher)
		tasks
	end

	take-values = proc(matcher)
		list() # to be done...
	end

	update = proc(matcher)
		true # to be done...
	end

	put-value = proc(item)
		ok err _ = call(stdvar.change task-store func(prev) append(prev item) end):
		list(ok err)
	end

	store-object = map(
		'get-values'  get-values
		'take-values' take-values
		'update'      update
		'put-value'   put-value
	)
	store-object
end

main = proc()
	store = call(new-simulated-store)

	task-adder = call(uc.new-task-adder store)
	task-getter = call(uc.new-task-getter store)

	_ = print('first: '
		call(task-getter
			map()
			map('query-map' map())
			map()
		)
	)

	task-id-var = call(stdvar.new 100)
	ctx = map(
		'task-id-var' task-id-var
	)
	msg = map(
		'name'  'task-A'
		'state' 'done'
	)

	_ = print('put: '
		call(task-adder
			ctx
			map()
			msg
		)
	)

	_ = print('then: '
		call(task-getter
			map()
			map('query-map' map())
			map()
		)
	)

	'done'
end

endns

