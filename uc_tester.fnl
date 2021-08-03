
ns main

import uc

import stdvar
import stdfu

import stdpr

# set debug print functions
is-debug-on = true
debug = call(stdpr.get-pr is-debug-on)
debugpp = call(stdpr.get-pp-pr is-debug-on)

new-simulated-store = proc()
	task-store = call(stdvar.new list())

	get-values = proc(matcher)
		tasklist = call(stdvar.value task-store)
		tasks = call(stdfu.filter tasklist matcher)
		tasks
	end

	take-values = proc(matcher)
		updator = func(tasks)
			choose = func(remaining left-list taken-list)
				if( empty(remaining)
					list(left-list taken-list)
					call(func()
						next-task = head(remaining)
						next-left next-taken = if( call(matcher next-task)
							list(left-list append(taken-list next-task))
							list(append(left-list next-task) taken-list)
						):
						call(choose rest(remaining) next-left next-taken)
					end)
				)
			end

			left taken = call(choose tasks list() list()):
			list(left taken)
		end

		ok err _ takenlist = call(stdvar.change-v2 task-store updator):
		takenlist
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
	task-deleter = call(uc.new-task-deleter store)

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

	msg2 = map(
		'name'  'task-B'
		'state' 'done'
	)
	_ = print('put: '
		call(task-adder
			ctx
			map()
			msg2
		)
	)

	msg3 = map(
		'name'  'task-C'
		'state' 'done'
	)
	_ = print('put: '
		call(task-adder
			ctx
			map()
			msg3
		)
	)

	_ = call(debugpp 'then: '
		call(task-getter
			map()
			map('query-map' map())
			map()
		)
	)

	_ = call(debugpp 'delete: '
		call(task-deleter
			map()
			map('query-map' map() 'selected-id' 103)
			map()
		)
	)

	_ = call(debugpp 'then2: '
		call(task-getter
			map()
			map('query-map' map())
			map()
		)
	)

	'done'
end

endns

