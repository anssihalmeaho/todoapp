
ns main

import uc
import er

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

	task-adder = call(uc.new-task-adder store)
	task-getter = call(uc.new-task-getter store)

	task-id-var = call(stdvar.new 100)
	ctx = map(
		'task-id-var' task-id-var
	)
	msg = map(
		'name'  'task-A'
		'state' 'done'
	)

	status err val = call(task-adder ctx map() msg):
	_ = call(stddbc.assert eq(er.No-Error status) sprintf('task adding failed: %s (%d)' err status))

	tasklist = call(task-getter map() map('query-map' map()) map())
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

	task-adder = call(uc.new-task-adder store)
	task-getter = call(uc.new-task-getter store)

	task-id-var = call(stdvar.new 100)
	ctx = map(
		'task-id-var' task-id-var
	)
	msg = map(
		'name'  'task-A'
		'state' 'done'
		'id'    100
	)

	status err val = call(task-adder ctx map() msg):

	_ = call(stddbc.assert eq(er.Invalid-Request status) sprintf('task adding should fail: %s (%d)' err status))
	_ = call(stddbc.assert eq('id not allowed in task when new task added' err) sprintf('unexpected err: %s (%d)' err status))

	tasklist = call(task-getter map() map('query-map' map()) map())
	_ = call(stddbc.assert empty(tasklist) sprintf('unexpected tasks: %v' tasklist))

	true
end

# --- test task adding fails as name is missing (invalid task data)
test-add-task-fail-invalid-task-data = proc()
	store = call(new-simulated-store)

	task-adder = call(uc.new-task-adder store)
	task-getter = call(uc.new-task-getter store)

	task-id-var = call(stdvar.new 100)
	ctx = map(
		'task-id-var' task-id-var
	)
	msg = map(
		'state' 'done'
	)

	status err val = call(task-adder ctx map() msg):

	_ = call(stddbc.assert eq(er.Invalid-Request status) sprintf('task adding should fail: %s (%d)' err status))
	_ = call(stddbc.assert eq('invalid task: required field name not found ()' err) sprintf('unexpected err: %s (%d)' err status))

	tasklist = call(task-getter map() map('query-map' map()) map())
	_ = call(stddbc.assert empty(tasklist) sprintf('unexpected tasks: %v' tasklist))

	true
end

# --- test task adding fails in store
test-add-task-fail-in-store = proc()
	failing-put-value = proc(item)
		list(false 'fake error')
	end

	store = put(del(call(new-simulated-store) 'put-value') 'put-value' failing-put-value)

	task-adder = call(uc.new-task-adder store)
	task-getter = call(uc.new-task-getter store)

	task-id-var = call(stdvar.new 100)
	ctx = map(
		'task-id-var' task-id-var
	)
	msg = map(
		'name'  'task-A'
		'state' 'done'
	)

	status err val = call(task-adder ctx map() msg):

	_ = call(stddbc.assert eq(er.Invalid-Request status) sprintf('task adding should fail: %s (%d)' err status))
	_ = call(stddbc.assert eq('adding task failed: fake error' err) sprintf('unexpected err: %s (%d)' err status))

	tasklist = call(task-getter map() map('query-map' map()) map())
	_ = call(stddbc.assert empty(tasklist) sprintf('unexpected tasks: %v' tasklist))

	true
end

# --- test task modify ok
test-modify-task-ok = proc()
	store = call(new-simulated-store)

	task-adder = call(uc.new-task-adder store)
	task-getter = call(uc.new-task-getter store)
	task-modifier = call(uc.new-task-modifier store)

	task-id-var = call(stdvar.new 100)
	ctx = map(
		'task-id-var' task-id-var
	)
	msg = map(
		'name'  'task-A'
		'state' 'done'
	)
	_ = call(task-adder ctx map() msg)

	status err _ = call(task-modifier
		map()
		map('query-map' map() 'selected-id' 101)
		map('version' 'v1' 'state' 'ongoing' 'description' 'Huraa !!!')
	):
	_ = call(stddbc.assert eq(er.No-Error status) sprintf('task modify failed: %s (%d)' err status))

	tasklist = call(task-getter map() map('query-map' map()) map())
	_ = call(stddbc.assert eq(len(tasklist) 1) sprintf('unexpected tasks: %v' tasklist))

	task = head(tasklist)
	_ = call(stddbc.assert eq(get(task 'name') 'task-A') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'state') 'ongoing') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'description') 'Huraa !!!') sprintf('unexpected task: %v' task))
	_ = call(stddbc.assert eq(get(task 'id') 101) sprintf('wrong id: %v' task))
	_ = call(stddbc.assert eq(get(task 'version') 'v2') sprintf('wrong version: %v' task))
	true
end

# --- test task replace ok
test-replace-task-ok = proc()
	store = call(new-simulated-store)

	task-adder = call(uc.new-task-adder store)
	task-getter = call(uc.new-task-getter store)
	task-replacer = call(uc.new-task-replacer store)

	task-id-var = call(stdvar.new 100)
	ctx = map(
		'task-id-var' task-id-var
	)
	msg = map(
		'name'  'task-A'
		'state' 'done'
	)
	_ = call(task-adder ctx map() msg)

	task-prev = head(call(task-getter map() map('query-map' map()) map()))

	new-task = map(
		'id'          get(task-prev 'id')
		'name'        get(task-prev 'name')
		'description' 'text-replaced'
		'tags'        list('new-tag')
		'state'       'ongoing'
		'version'     get(task-prev 'version')
	)

	status err _ = call(task-replacer
		map()
		map('query-map' map() 'selected-id' 101)
		new-task
	):
	_ = call(stddbc.assert eq(er.No-Error status) sprintf('task replace failed: %s (%d)' err status))

	tasklist = call(task-getter map() map('query-map' map()) map())
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

# --- test task deletion ok
test-delete-task-ok = proc()
	store = call(new-simulated-store)

	task-adder = call(uc.new-task-adder store)
	task-getter = call(uc.new-task-getter store)
	task-deleter = call(uc.new-task-deleter store)

	task-id-var = call(stdvar.new 100)
	ctx = map(
		'task-id-var' task-id-var
	)
	msg = map(
		'name'  'task-A'
		'state' 'done'
	)
	_ = call(task-adder ctx map() msg)

	status err _ = call(task-deleter
		map()
		map('query-map' map() 'selected-id' 101)
		map()
	):
	_ = call(stddbc.assert eq(er.No-Error status) sprintf('task modify failed: %s (%d)' err status))

	tasklist = call(task-getter map() map('query-map' map()) map())
	_ = call(stddbc.assert empty(tasklist) sprintf('unexpected tasks: %v' tasklist))

	true
end

main = proc()
	tests = list(
		test-add-task-ok
		test-add-task-fail-id-not-allowed
		test-add-task-fail-in-store
		test-add-task-fail-invalid-task-data

		test-modify-task-ok

		test-replace-task-ok

		test-delete-task-ok
	)

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

