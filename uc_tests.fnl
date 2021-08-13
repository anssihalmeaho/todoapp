
ns main

import uc
import er
import domain

import stdvar
import stdfu
import stdpr
import stddbc

# set debug print functions
is-debug-on = true
debug = call(stdpr.get-pr is-debug-on)
debugpp = call(stdpr.get-pp-pr is-debug-on)

new-simulated-store = proc()
	task-store = call(stdvar.new list())

	# mock implementation for get-values
	get-values = proc(matcher)
		tasklist = call(stdvar.value task-store)
		tasks = call(stdfu.filter tasklist matcher)
		tasks
	end

	# mock implementation for take-values
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

	# mock implementation for update
	update = proc(matcher)
		updator = func(tasks)
			update-items = func(remaining newlist any-change)
				if( empty(remaining)
					list(newlist any-change)
					call(func()
						next-item = head(remaining)
						do-update new-value = call(matcher next-item):
						if( do-update
							call(update-items rest(remaining) append(newlist new-value) true)
							call(update-items rest(remaining) append(newlist next-item) any-change)
						)
					end)
				)
			end

			new-tasks is-any-change = call(update-items tasks list() false):
			list(new-tasks is-any-change)
		end

		ok err _ is-any-change = call(stdvar.change-v2 task-store updator):
		is-any-change
	end

	# mock implementation for put-value
	put-value = proc(item)
		ok err _ = call(stdvar.change task-store func(prev) append(prev item) end):
		list(ok err)
	end

	# return mock store-object
	store-object = map(
		'get-values'  get-values
		'take-values' take-values
		'update'      update
		'put-value'   put-value
	)
	store-object
end

# --- test task adding ok
test-add-task-ok = proc()
	store = call(new-simulated-store)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter = call(uc.new-task-getter store)

	msg = map(
		'name'  'task-A'
		'state' 'done'
	)

	status err val = call(task-adder map() msg):
	_ = call(stddbc.assert eq(er.No-Error status) sprintf('task adding failed: %s (%d)' err status))

	tasklist = call(task-getter map('query-map' map()) map())
	_ = call(stddbc.assert eq(len(tasklist) 1) sprintf('unexpected tasks: %v' tasklist))

	task = head(tasklist)
	_ = call(stddbc.assert eq(get(task 'name') 'task-A') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'state') 'done') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'id') 101) sprintf('wrong id: %v' task))
	_ = call(stddbc.assert eq(get(task 'version') 'v1') sprintf('wrong version: %v' task))
	true
end

# --- test task adding fails as id -field not allowed
test-add-task-fail-id-not-allowed = proc()
	store = call(new-simulated-store)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter = call(uc.new-task-getter store)

	msg = map(
		'name'  'task-A'
		'state' 'done'
		'id'    100
	)

	status err val = call(task-adder map() msg):

	_ = call(stddbc.assert eq(er.Invalid-Request status) sprintf('task adding should fail: %s (%d)' err status))
	_ = call(stddbc.assert eq('id not allowed in task when new task added' err) sprintf('unexpected err: %s (%d)' err status))

	tasklist = call(task-getter map('query-map' map()) map())
	_ = call(stddbc.assert empty(tasklist) sprintf('unexpected tasks: %v' tasklist))

	true
end

# --- test task adding fails as name is missing (invalid task data)
test-add-task-fail-invalid-task-data = proc()
	store = call(new-simulated-store)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter = call(uc.new-task-getter store)

	msg = map(
		'state' 'done'
	)

	status err val = call(task-adder map() msg):

	_ = call(stddbc.assert eq(er.Invalid-Request status) sprintf('task adding should fail: %s (%d)' err status))
	_ = call(stddbc.assert eq('invalid task: required field name not found ()' err) sprintf('unexpected err: %s (%d)' err status))

	tasklist = call(task-getter map('query-map' map()) map())
	_ = call(stddbc.assert empty(tasklist) sprintf('unexpected tasks: %v' tasklist))

	true
end

# --- test task adding fails in store
test-add-task-fail-in-store = proc()
	failing-put-value = proc(item)
		list(false 'fake error')
	end

	store = put(del(call(new-simulated-store) 'put-value') 'put-value' failing-put-value)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter = call(uc.new-task-getter store)

	msg = map(
		'name'  'task-A'
		'state' 'done'
	)

	status err val = call(task-adder map() msg):

	_ = call(stddbc.assert eq(er.Invalid-Request status) sprintf('task adding should fail: %s (%d)' err status))
	_ = call(stddbc.assert eq('adding task failed: fake error' err) sprintf('unexpected err: %s (%d)' err status))

	tasklist = call(task-getter map('query-map' map()) map())
	_ = call(stddbc.assert empty(tasklist) sprintf('unexpected tasks: %v' tasklist))

	true
end

# --- test task modify ok
test-modify-task-ok = proc()
	store = call(new-simulated-store)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter = call(uc.new-task-getter store)
	task-modifier = call(uc.new-task-modifier store)

	msg = map(
		'name'  'task-A'
		'state' 'done'
	)
	_ = call(task-adder map() msg)

	status err _ = call(task-modifier
		map('query-map' map() 'selected-id' 101)
		map('version' 'v1' 'state' 'ongoing' 'description' 'Huraa !!!')
	):
	_ = call(stddbc.assert eq(er.No-Error status) sprintf('task modify failed: %s (%d)' err status))

	tasklist = call(task-getter map('query-map' map()) map())
	_ = call(stddbc.assert eq(len(tasklist) 1) sprintf('unexpected tasks: %v' tasklist))

	task = head(tasklist)
	_ = call(stddbc.assert eq(get(task 'name') 'task-A') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'state') 'ongoing') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'description') 'Huraa !!!') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'id') 101) sprintf('wrong id: %v' task))
	_ = call(stddbc.assert eq(get(task 'version') 'v2') sprintf('wrong version: %v' task))
	true
end

# --- test task modify fails as wrong version is given
test-modify-task-fail-as-wrong-version = proc()
	store = call(new-simulated-store)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter = call(uc.new-task-getter store)
	task-modifier = call(uc.new-task-modifier store)

	msg = map(
		'name'  'task-A'
		'state' 'done'
	)
	_ = call(task-adder map() msg)

	status err _ = call(task-modifier
		map('query-map' map() 'selected-id' 101)
		map('version' 'v10' 'state' 'ongoing' 'description' 'Huraa !!!')
	):
	_ = call(stddbc.assert eq(er.Invalid-Request status) sprintf('task modify, unexpected status: %s (%d)' err status))

	# lets check that nothing has changed
	tasklist = call(task-getter map('query-map' map()) map())
	_ = call(stddbc.assert eq(len(tasklist) 1) sprintf('unexpected tasks: %v' tasklist))

	task = head(tasklist)
	_ = call(stddbc.assert eq(get(task 'name') 'task-A') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'state') 'done') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'description') '') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'id') 101) sprintf('wrong id: %v' task))
	_ = call(stddbc.assert eq(get(task 'version') 'v1') sprintf('wrong version: %v' task))
	true
end

# --- test task replace ok
test-replace-task-ok = proc()
	store = call(new-simulated-store)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter = call(uc.new-task-getter store)
	task-replacer = call(uc.new-task-replacer store)

	msg = map(
		'name'  'task-A'
		'state' 'done'
	)
	_ = call(task-adder map() msg)

	task-prev = head(call(task-getter map('query-map' map()) map()))

	new-task = map(
		'id'          get(task-prev 'id')
		'name'        get(task-prev 'name')
		'description' 'text-replaced'
		'tags'        list('new-tag')
		'state'       'ongoing'
		'version'     get(task-prev 'version')
	)

	status err _ = call(task-replacer
		map('query-map' map() 'selected-id' 101)
		new-task
	):
	_ = call(stddbc.assert eq(er.No-Error status) sprintf('task replace failed: %s (%d)' err status))

	tasklist = call(task-getter map('query-map' map()) map())
	_ = call(stddbc.assert eq(len(tasklist) 1) sprintf('unexpected tasks: %v' tasklist))

	task = head(tasklist)
	_ = call(stddbc.assert eq(get(task 'name') 'task-A') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'state') 'ongoing') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'description') 'text-replaced') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'tags')  list('new-tag')) sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'id') 101) sprintf('wrong id: %v' task))
	_ = call(stddbc.assert eq(get(task 'version') 'v2') sprintf('wrong version: %v' task))
	true
end

# --- test task replace fails as wrong version is given
test-replace-task-fail-as-wrong-version = proc()
	store = call(new-simulated-store)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter = call(uc.new-task-getter store)
	task-replacer = call(uc.new-task-replacer store)

	msg = map(
		'name'  'task-A'
		'state' 'done'
	)
	_ = call(task-adder map() msg)

	task-prev = head(call(task-getter map('query-map' map()) map()))

	new-task = map(
		'id'          get(task-prev 'id')
		'name'        get(task-prev 'name')
		'description' 'text-replaced'
		'tags'        list('new-tag')
		'state'       'ongoing'
		'version'     'this is wrong version'
	)

	status err _ = call(task-replacer
		map('query-map' map() 'selected-id' 101)
		new-task
	):
	_ = call(stddbc.assert eq(er.Invalid-Request status) sprintf('task replace, unexpected status: %s (%d)' err status))

	# lets check that nothing has changed
	tasklist = call(task-getter map('query-map' map()) map())
	_ = call(stddbc.assert eq(len(tasklist) 1) sprintf('unexpected tasks: %v' tasklist))

	task = head(tasklist)
	_ = call(stddbc.assert eq(get(task 'name') 'task-A') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'state') 'done') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'description') '') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'tags') list()) sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'id') 101) sprintf('wrong id: %v' task))
	_ = call(stddbc.assert eq(get(task 'version') 'v1') sprintf('wrong version: %v' task))

	true
end

# --- test task deletion ok
test-delete-task-ok = proc()
	store = call(new-simulated-store)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter = call(uc.new-task-getter store)
	task-deleter = call(uc.new-task-deleter store)

	msg = map(
		'name'  'task-A'
		'state' 'done'
	)
	_ = call(task-adder map() msg)

	status err _ = call(task-deleter
		map('query-map' map() 'selected-id' 101)
		map()
	):
	_ = call(stddbc.assert eq(er.No-Error status) sprintf('task modify failed: %s (%d)' err status))

	tasklist = call(task-getter map('query-map' map()) map())
	_ = call(stddbc.assert empty(tasklist) sprintf('unexpected tasks: %v' tasklist))

	true
end

# --- test task getting with id ok
test-get-task-by-id = proc()
	store = call(new-simulated-store)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter-by-id = call(uc.new-task-getter-by-id store)

	tasks = list(
		map(
			'name'  'task-A'
			'state' 'new'
		)
		map(
			'name'  'task-B'
			'state' 'ongoing'
		)
		map(
			'name'  'task-C'
			'state' 'done'
		)
	)
	_ = call(stdfu.ploop proc(task _) call(task-adder map() task) end tasks 'none')

	tasklist = call(task-getter-by-id map('selected-id' 102) map())
	_ = call(stddbc.assert eq(len(tasklist) 1) sprintf('unexpected tasks: %v' tasklist))

	task = head(tasklist)
	_ = call(stddbc.assert eq(get(task 'name') 'task-B') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'state') 'ongoing') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'description') '') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'id') 102) sprintf('wrong id: %v' task))
	_ = call(stddbc.assert eq(get(task 'version') 'v1') sprintf('wrong version: %v' task))

	# test also by giving non existing id
	tasklist2 = call(task-getter-by-id map('selected-id' 1234) map())
	_ = call(stddbc.assert empty(tasklist2) sprintf('should be empty: %v' tasklist))

	true
end

# --- test task getting with query parameter ok
test-get-task-by-query = proc()
	store = call(new-simulated-store)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter = call(uc.new-task-getter store)

	tasks = list(
		map(
			'name'  'task-A'
			'state' 'new'
		)
		map(
			'name'  'task-B'
			'state' 'ongoing'
		)
		map(
			'name'  'task-C'
			'state' 'done'
		)
	)
	_ = call(stdfu.ploop proc(task _) call(task-adder map() task) end tasks 'none')

	tasklist = call(task-getter
		map('query-map' map('state' list('ongoing' 'new')))
		map()
	)
	_ = call(stddbc.assert eq(len(tasklist) 2) sprintf('unexpected tasks: %v' tasklist))

	check-task = proc(task)
		_ = call(stddbc.assert in(list('task-A' 'task-B') get(task 'name')) sprintf('unexpected task: %v' task))
		_ = call(stddbc.assert in(list('ongoing' 'new') get(task 'state')) sprintf('unexpected task: %v' task))
		_ = call(stddbc.assert in(list(101 102) get(task 'id')) sprintf('wrong id: %v' task))
		true
	end

	and(
		call(check-task head(tasklist))
		call(check-task last(tasklist))
	)
end

# --- test task getting with query parameter (search) for text search
test-get-task-by-text-search = proc()
	store = call(new-simulated-store)
	task-id-var = call(stdvar.new 100)

	task-adder = call(uc.new-task-adder store task-id-var)
	task-getter = call(uc.new-task-getter store)

	tasks = list(
		map(
			'name'  'Carwash'
			'description' 'Washing car'
		)
		map(
			'name'  'Garage'
			'description' 'Clean the garage'
		)
		map(
			'name'  'Shopping'
			'description' 'Drive with car to do shopping'
		)
	)
	_ = call(stdfu.ploop proc(task _) call(task-adder map() task) end tasks 'none')

	check-names = proc(tasklist expect-names)
		_ = call(stddbc.assert eq(len(tasklist) len(expect-names)) sprintf('unexpected tasks: %v' tasklist))
		namelist = call(stdfu.apply tasklist func(task) get(task 'name') end)
		_ = call(stddbc.assert eq(len(namelist) len(expect-names)) sprintf('list len dont match: %v' tasklist))
		names-ok = call(stdfu.applies-for-all expect-names func(tn) in(namelist tn) end)
		_ = call(stddbc.assert names-ok sprintf('names dont match: %v' namelist))
		true
	end

	do-get = proc(search-list)
		call(task-getter
			map('query-map' map('search' search-list))
			map()
		)
	end
	# search one string which occurs in two tasks
	_ = call(check-names call(do-get list('car')) list('Shopping' 'Carwash'))

	# no search string given -> empty result list
	_ = call(check-names call(do-get list()) list())

	# search two strings
	_ = call(check-names call(do-get list('Car' 'garage')) list('Carwash' 'Garage'))
	true
end

main = proc()
	tests-uc = list(
		test-add-task-ok
		test-add-task-fail-id-not-allowed
		test-add-task-fail-in-store
		test-add-task-fail-invalid-task-data

		test-modify-task-ok
		test-modify-task-fail-as-wrong-version

		test-replace-task-ok
		test-replace-task-fail-as-wrong-version

		test-delete-task-ok

		test-get-task-by-id
		test-get-task-by-query

		test-get-task-by-text-search
	)
	tests = extend(tests-uc call(domain.get-testcases))

	test-runner = proc(tst-proc)
		res = try(call(tst-proc))
		test-result = cond(
			eq(type(res) 'string') false
			res
		)
		_ = if(test-result
			print('PASS: ' tst-proc)
			print('FAIL: ' tst-proc '\n' res)
		)
		test-result
	end

	tp-list = call(stdfu.proc-apply tests proc(tp) proc() call(test-runner tp) end end)
	all-tests-ok = call(stdfu.ploop proc(tp prev-res) and(call(tp) prev-res) end tp-list true)

	result = if( all-tests-ok
		'PASS'
		'FAILED'
	)
	result
end

endns

