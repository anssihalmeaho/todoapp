
ns uc

import domain

import valuez
import stdvar

# error codes
No-Error = 1
Invalid-Request = 3

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

