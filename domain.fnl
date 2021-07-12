
ns domain

get-task-validator = func(task)
	import stdmeta
	import stdstr

	/*
	- name : string
	- description : string
	- tags : list(string)
	- state: enum:string(new, ongoing, done)
	- date/time (begin, end) : optional

	- id : int ==> auto generated
	- version: string ==> auto generated
	*/
	func()
		schema = list('map' map(
			'name'        list(list('required') list('type' 'string'))
			'description' list(list('required') list('type' 'string'))
			'tags'        list(list('required') list('type' 'list'))
			'state'       list(list('required') list('type' 'string') list('in' 'new' 'ongoing' 'done'))
		))
		is-valid err-list = call(stdmeta.validate schema task):
		if( is-valid
			list(true '')
			list(false call(stdstr.join err-list ', '))
		)
	end
end

fill-missing-fields = func(source-item)
	import stdfu

	add-field-if-has-not = func(item field-name default-value)
		if( in(item field-name)
			item
			put(item field-name default-value)
		)
	end

	chain = list(
		func(it) call(add-field-if-has-not it 'description' '') end
		func(it) call(add-field-if-has-not it 'tags' list()) end
		func(it) call(add-field-if-has-not it 'state' 'new') end
	)
	call(stdfu.chain source-item chain)
end

task-id-match = func(selected-id)
	func(item) eq(get(item 'id') selected-id) end
end

get-query-names = func()
	list('name' 'tags' 'state')
end

get-query-func = func(query-map)
	import stdfu

	has-tags tag-list = getl(query-map 'tags'):
	has-state state-list = getl(query-map 'state'):
	has-name name-list = getl(query-map 'name'):

	get-cut = func(l1 l2)
		import stdset

		set1 = call(stdset.list-to-set call(stdset.newset) l1)
		set2 = call(stdset.list-to-set call(stdset.newset) l2)
		cut = call(stdset.intersection set1 set2)
		not(call(stdset.is-empty cut))
	end

	qcheck = func(task qname has-it src-list is-list)
		x = if( has-it
			if(is-list get(task qname) list(get(task qname)))
			'whatever'
		)

		or(
			not(has-it)
			if( in(task qname)
				call(get-cut x src-list)
				true
			)
		)
	end

	func(task)
		and(
			call(qcheck task 'tags' has-tags tag-list true)
			call(qcheck task 'state' has-state state-list false)
			call(qcheck task 'name' has-name name-list false)
		)
	end
end

interleave-fields = func(old-item new-item)
	import stdfu

	conflict-solver = func(key val1 val2)
		list(true val1)
	end

	call(stdfu.merge conflict-solver old-item new-item)
end

#===================== tests ====

test-interl = proc()
	mold = map('a' 1 'b' 2)
	mnew = map('b' 3 'a' 4 'c' 5)

	call(interleave-fields mold mnew)
end

test-q-all = proc()
	import stdfu
	import stdpp

	tclist = list(
		test-q-1
		test-q-2
	)
	call(stdpp.pform call(stdfu.proc-apply tclist proc(tc) call(tc) end))
end

test-q-2 = proc()
	task = map(
		'name'  'Dum'
		'tags'  list('tag1' 'tag2')
		'state' 'new'
	)

	qm = map(
		'tags'  list('tag2')
		'name'  list('Dum')
		'state' list('new' 'done')
	)

	f = call(get-query-func qm)
	case( call(f task)
		true  'PASSED'
		false 'FAILED'
	)
end

test-q-1 = proc()
	task = map(
		'name' 'Dummy'
		'tags' list('tag1' 'tag2')
	)

	qm = map(
		'tags'  list('t1', 'tag1', 't3')
	)

	f = call(get-query-func qm)
	case( call(f task)
		true  'PASSED'
		false 'FAILED'
	)
end

endns
