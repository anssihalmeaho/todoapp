
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
	list('name' 'tags' 'state' 'search')
end

get-all-tags = func(tasks)
	import stdfu
	import stdset

	taglist = call(stdfu.loop func(task tags) extend(tags get(task 'tags')) end tasks list())
	tagset = call(stdset.list-to-set call(stdset.newset) taglist)
	call(stdset.as-list tagset)
end

get-query-func = func(query-map)
	import stdfu

	has-tags tag-list = getl(query-map 'tags'):
	has-state state-list = getl(query-map 'state'):
	has-name name-list = getl(query-map 'name'):

	has-search search-list = getl(query-map 'search'):

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

	is-text-found-in-task = func(task search-text)
		to-one-str = func(val)
			next-val = func(nval result-str)
				case( type(nval)
					'string' plus(result-str nval)
					'list'   plus(result-str call(stdfu.loop func(x cum) call(next-val x cum) end nval '') )
					'map'    plus(result-str call(stdfu.loop func(x cum) call(next-val x cum) end vals(nval) '') )
					result-str
				)
			end

			call(next-val val '')
		end

		in(call(to-one-str task) search-text)
	end

	if( has-search
		func(task)
			if( empty(search-list)
				false
				call(stdfu.applies-for-any search-list func(search-text) call(is-text-found-in-task task search-text) end)
			)
		end

		func(task)
			and(
				call(qcheck task 'tags' has-tags tag-list true)
				call(qcheck task 'state' has-state state-list false)
				call(qcheck task 'name' has-name name-list false)
			)
		end
	)
end

interleave-fields = func(old-item new-item)
	import stdfu

	conflict-solver = func(key val1 val2)
		list(true val1)
	end

	call(stdfu.merge conflict-solver old-item new-item)
end

# --- test cases
get-testcases = func()
	import stdfu
	import stdpp

	test-interleave = func()
		mold = map('a' 1 'b' 2)
		mnew = map('b' 3 'a' 4 'c' 5)

		eq(
			call(interleave-fields mold mnew)
			map('c' 5 'b' 3 'a' 4)
		)
	end

	test-queries = func()
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
		call(f task)
	end

	test-query-tags = func()
		task = map(
			'name' 'Dummy'
			'tags' list('tag1' 'tag2')
		)

		querymap = map(
			'tags'  list('t1', 'tag1', 't3')
		)

		f = call(get-query-func querymap)
		call(f task)
	end

	test-filling-missing-fields = func()
		draft-task = map(
			'name' 'Some Name'
		)
		expected-task = map(
			'name'        'Some Name'
			'description' ''
			'state'       'new'
			'tags'        list()
		)
		result-task = call(fill-missing-fields draft-task)

		eq(expected-task result-task)
	end

	test-validations = func()
		tasks = list(
			map(
				'name' 123
				'description' '...'
				'state'       'done'
				'tags'        list()
			)
			map(
				'description' '...'
				'state'       'done'
				'tags'        list()
			)
			map(
				'name'        'Some Name'
				'description' '...'
				'state'       'done'
				'tags'        'this should be list'
			)
			map(
				'name'        'Some Name'
				'description' '...'
				'state'       'not valid state'
				'tags'        list('tag1' 'tag2')
			)
			map(
				'name'        'Some Name'
				'description' '...'
				'state'       'ongoing'
				'tags'        list('tag1' 'tag2')
			)
		)
		results = call(stdfu.loop func(task cum) append(cum call(call(get-task-validator task))) end tasks list())
		#_ = print('\nresults: ' call(stdpp.form results) '\n')

		expected = list(
			list(
					false
					'field name is not required type (got: int, expected: string)()'
			)
			list(
					false
					'required field name not found ()'
			)
			list(
					false
					'field tags is not required type (got: string, expected: list)()'
			)
			list(
					false
					'field state is not in allowed set (not valid state not in: list(\'new\', \'ongoing\', \'done\'))()'
			)
			list(
					true
					''
			)
		)

		eq(results expected)
	end

	list(
		test-query-tags
		test-queries
		test-interleave
		test-filling-missing-fields
		test-validations
	)
end

endns
