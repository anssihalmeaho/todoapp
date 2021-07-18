
ns uc

import domain

import valuez
import stdvar

# error codes
No-Error = 1
Invalid-Request = 2

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

task-modifier = proc(ctx req msg)
	task-id-var = get(ctx 'task-id-var')
	col = get(ctx 'col')
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
		list(Invalid-Request str(err-descr) '')
		list(No-Error '' '')
	)
end

task-adder = proc(ctx req msg)
	task-id-var = get(ctx 'task-id-var')
	col = get(ctx 'col')

	has-id idvalue = getl(msg 'id'):
	item = call(domain.fill-missing-fields msg)
	is-valid err-text = call(call(domain.get-task-validator item)):

	_ _ next-id-val = if( and(is-valid not(has-id))
		call(stdvar.change task-id-var func(x) plus(x 1) end)
		list('not' 'valid' 'req')
	):

	if( has-id
		list(Invalid-Request 'id not allowed in task when new task added' '')
		if( is-valid
			call(proc()
				added-ok add-error = call(valuez.put-value col put(put(item 'id' next-id-val) 'version' 'v1')):
				if( added-ok
					list(No-Error '' '')
					list(Invalid-Request sprintf('adding task failed: %s' add-error) '')
				)
			end)

			list(Invalid-Request sprintf('invalid task: %s' err-text) '')
		)
	)
end

endns

