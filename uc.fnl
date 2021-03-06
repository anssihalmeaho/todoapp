
ns uc

import domain
import er

import stdvar
import stdpr

# set debug print functions
is-debug-on = false
debug = call(stdpr.get-pr is-debug-on)
debugpp = call(stdpr.get-pp-pr is-debug-on)

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

generate-new-version = func(vers)
	plus('v' str(plus(conv(slice(vers 1) 'int') 1)))
end

get-query-names = func()
	call(domain.get-query-names)
end

new-tag-getter = proc(store)
	get-values = get(store 'get-values')

	proc(req msg)
		all-tasks = call(get-values func(item) true end)
		call(domain.get-all-tags all-tasks)
	end
end

new-task-getter = proc(store)
	get-values = get(store 'get-values')

	proc(req msg)
		query-map = get(req 'query-map')
		query-func = call(domain.get-query-func query-map)
		matched-items = call(get-values func(item) call(query-func item) end)
		matched-items
	end
end

new-task-getter-by-id = proc(store)
	get-values = get(store 'get-values')

	proc(req msg)
		selected-id = get(req 'selected-id')
		matched-items = call(get-values call(domain.task-id-match selected-id))
		matched-items
	end
end

new-task-deleter = proc(store)
	take-values = get(store 'take-values')

	proc(req msg)
		selected-id = get(req 'selected-id')
		taken-items = call(take-values call(domain.task-id-match selected-id))
		case( len(taken-items)
			0 list(er.Invalid-Request sprintf('task with id %d not found' selected-id) '')
			list(er.No-Error '' '')
		)
	end
end

new-task-replacer = proc(store)
	update = get(store 'update')

	proc(req msg)
		selected-id = get(req 'selected-id')
		has-id idvalue = getl(msg 'id'):
		has-version version = getl(msg 'version'):
		is-valid-vers vers-err = call(is-valid-version has-version version):
		new-item = if( and(has-version is-valid-vers)
			put(del(msg 'version') 'version' call(generate-new-version version))
			msg
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

				was-any-updated = call(update upd-func)
				if( was-any-updated
					list(true '')
					list(false sprintf('task not found (id: %d) or version mismatch' selected-id))
				)
			end)

			list(false err-text)
		):

		if( not(all-ok)
			list(er.Invalid-Request str(err-descr) '')
			list(er.No-Error '' '')
		)
	end
end

new-task-modifier = proc(store)
	update = get(store 'update')

	proc(req msg)
		selected-id = get(req 'selected-id')
		has-version version = getl(msg 'version'):
		check-ok err-text = call(is-valid-version has-version version):
		new-item = if( and(has-version check-ok)
			put(del(msg 'version') 'version' call(generate-new-version version))
			msg
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
								is-valid validity-err = call(call(domain.get-task-validator modified-item)):
								if( is-valid
									list(true modified-item)
									list(false 'none') # how to get error text ..?
								)
							end)
							list(false 'none')
						)
						list(false 'none')
					)
				end

				was-any-updated = call(update upd-func)
				if( was-any-updated
					list(true '')
					list(false sprintf('task not found (id: %d) or version mismatch or invalid data' selected-id))
				)
			end)

			list(false err-text)
		):

		if( not(all-ok)
			list(er.Invalid-Request str(err-descr) '')
			list(er.No-Error '' '')
		)
	end
end

new-tasks-importer = proc(store task-id-var)
	import stdfu

	proc(req msg)
		importer = proc(txn)
			put-value = get(txn 'put-value')
			take-values = get(txn 'take-values')
			get-values = get(txn 'get-values')

			put-one-task = proc(item result)
				if( result
					call(proc()
						_ _ next-id-val = call(stdvar.change task-id-var func(x) plus(x 1) end):
						task = if(in(item 'id') del(item 'id') item)

						added-ok _ = call(put-value put(task 'id' next-id-val)):
						added-ok
					end)

					false
				)
			end

			# lets delete all current tasks first
			_ = call(take-values func() true end)

			# then add imported tasks one by one
			call(stdfu.ploop put-one-task msg true)
		end

		validate-one-task = func(item resultlist)
			has-version = in(item 'version')
			is-valid err-text = call(call(domain.get-task-validator item)):

			cond(
				not(has-version) append(resultlist list(er.Invalid-Request 'task does not have version' ''))
				not(is-valid)    append(resultlist list(er.Invalid-Request sprintf('invalid task: %s' err-text) ''))
				append(resultlist list(er.No-Error '' ''))
			)
		end

		choose-result = func(results-list)
			errors = call(stdfu.filter results-list func(res) not(eq(head(res) er.No-Error)) end)
			if( empty(errors)
				head(results-list)
				head(errors)
			)
		end

		cond(
			not(eq(type(msg) 'list')) list(er.Invalid-Request sprintf('request should contain list (was: %s)' type(msg)) '')
			empty(msg)                list(er.Invalid-Request 'no tasks to import' '')

			call(proc()
				validity-result = call(choose-result call(stdfu.loop validate-one-task msg list()))
				if( eq(head(validity-result) er.No-Error)
					call(proc()
						trans = get(store 'trans')
						changes-done = call(trans importer)
						if( changes-done
							list(er.No-Error '' '')
							list(er.Invalid-Request 'import storing failed' '')
						)
					end)

					validity-result
				)
			end)
		)
	end
end

new-task-adder = proc(store task-id-var)
	put-value = get(store 'put-value')

	proc(req msg)
		has-id idvalue = getl(msg 'id'):
		item = call(domain.fill-missing-fields msg)
		is-valid err-text = call(call(domain.get-task-validator item)):

		_ _ next-id-val = if( and(is-valid not(has-id))
			call(stdvar.change task-id-var func(x) plus(x 1) end)
			list('not' 'valid' 'req')
		):

		if( has-id
			list(er.Invalid-Request 'id not allowed in task when new task added' '')
			if( is-valid
				call(proc()
					added-ok add-error = call(put-value put(put(item 'id' next-id-val) 'version' 'v1')):
					if( added-ok
						list(er.No-Error '' '')
						list(er.Invalid-Request sprintf('adding task failed: %s' add-error) '')
					)
				end)

				list(er.Invalid-Request sprintf('invalid task: %s' err-text) '')
			)
		)
	end
end

endns

