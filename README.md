# todoapp
ToDo application in FunL

REST (HTTP) server for ToDo-task management:

* Adding tasks
* Modifying tasks (modifying data and replacing data with new)
* Removing tasks
* Listing tasks (all, with certain task-id or with some filters)

## Install

Go language need to be installed first.
After that get **todoapp** repository from Github:

```
git clone https://github.com/anssihalmeaho/todoapp.git
```

Then run make (Linux/Unix/Cygwin/MacOS) to create executable (**todoapp**):

```
make
```

Building executable in Windows can be made as:

```
go build -o todoapp.exe -v .
```

And start the server:

```
./todoapp
todoapp: 2021/07/12 15:30:06 :'...serving...'
```

or in Windows:

```
todoapp.exe
todoapp: 2021/07/12 15:32:48 :'...serving...'
```

And shutting down is done by CTRL-C (SIGINT):

```
...serving...
todoapp: 2021/07/12 15:32:48 :'...serving...'
todoapp: 2021/07/12 15:33:22 :'signal received: ':2:'interrupt'
todoapp: 2021/07/12 15:33:22 :'listen: ':'http: Server closed'
Result is 'done'
```

## API

Task contains following fields:

* **name**: name describing task (string)
* **description**: more detailed description of task (string, default is "")
* **state**: state of task, possible values are "new", "ongoing" and "done" (default is "new")
* **tags**: array of tags (tag is string) that can be given for task (default is [])

Also there are fields generated by server:

* **id**: unique identifier (int) for task
* **version**: used for ensuring consistency in updating data


### Adding task: POST /todoapp/v1/tasks

Adds new task. Task content is given as JSON in request body.
HTTP status code in response is:

* 201 if succeeded
* 400 in case data is invalid in request

Example:

```
curl -X POST -d '{"name": "wash car", "description": "go to washing car", "tags": ["car"]}' http://localhost:8003/todoapp/v1/tasks
```

"name" field is only required one. Fields which are not given is request body are filled with default values:

```
curl http://localhost:8003/todoapp/v1/tasks

[{
	"tags": ["car"],
	"id": 11,
	"description": "go to washing car",
	"state": "new",
	"name": "wash car",
	"version": "v1"
}]
```
### Modifying task: POST /todoapp/v1/tasks/:id

Modifies some fields in task. Modified fields are given as JSON in request body.
Version needs to match in order to succeed. 
HTTP status code in response is:

* 200 if succeeded
* 400 in case data is invalid in request

Example:

```
curl http://localhost:8003/todoapp/v1/tasks/11

[{
	"id": 11,
	"description": "go to washing car",
	"name": "wash car",
	"tags": ["car"],
	"state": "new",
	"version": "v1"
}]

curl -X POST -d '{"state": "done", "version": "v1"}' http://localhost:8003/todoapp/v1/tasks/11

curl http://localhost:8003/todoapp/v1/tasks/11

[{
	"tags": ["car"],
	"id": 11,
	"description": "go to washing car",
	"state": "done",
	"version": "v2",
	"name": "wash car"
}]
```

### Replacing task: PUT /todoapp/v1/tasks/:id

Replaces task with new content. Task content is given as JSON in request body.
Version needs to match in order to succeed. 
HTTP status code in response is:

* 200 if succeeded
* 400 in case data is invalid in request

Example:

```
curl http://localhost:8003/todoapp/v1/tasks/11

[{
	"id": 11,
	"description": "go to washing car",
	"name": "wash car",
	"tags": ["car"],
	"state": "new",
	"version": "v1"
}]

curl -X PUT -d '{"id": 11, "description": "Go to washing car", "name": "Wash car", "tags": ["car"], "state": "done", "version": "v1"}' http://localhost:8003/todoapp/v1/tasks/11

curl http://localhost:8003/todoapp/v1/tasks/11

[{
	"id": 11,
	"description": "Go to washing car",
	"name": "Wash car",
	"tags": ["car"],
	"state": "done",
	"version": "v2"
}]
```

### Deleting task: DELETE /todoapp/v1/tasks/:id

Deletes task with id.
HTTP status code in response is:

* 200 if succeeded
* 400 in case data is invalid in request

Example:

```
curl -v -X DELETE http://localhost:8003/todoapp/v1/tasks/11
```

### Reading task: GET /todoapp/v1/tasks/:id

Reading task with id.
HTTP status code in response is 200.

If id is not found then response body contains empty (JSON) array.

Example:

```
curl http://localhost:8003/todoapp/v1/tasks/11

[{
	"tags": ["car"],
	"id": 11,
	"description": "go to washing car",
	"state": "new",
	"name": "wash car",
	"version": "v1"
}]
```

### Reading tasks: GET /todoapp/v1/tasks

Reading tasks.
HTTP status code in response is 200.

There can be several query paramters given as filters:

* name => matches to any names given
* state => matches to any state given
* tags => matches if has any of given tags

Several different query parameters can be given at the same time.
If all of those match then it matches.

If no query parameters are given then all tasks are returned
in response.

If there are no matching tasks then empty array is returned.

Example: Get all tasks

```
curl http://localhost:8003/todoapp/v1/tasks

[{
	"tags": ["car"],
	"id": 11,
	"description": "go to washing car",
	"state": "new",
	"name": "wash car",
	"version": "v1"
}, {
	"tags": ["home", "yard"],
	"id": 12,
	"description": "mowing the lawn",
	"state": "new",
	"name": "lawn mowing",
	"version": "v1"
}, {
	"tags": ["yard"],
	"id": 13,
	"description": "paint the fence",
	"state": "done",
	"version": "v2",
	"name": "fence painting"
}]
```

Example: Get tasks which are in new state

```
 curl http://localhost:8003/todoapp/v1/tasks?state=new

[{
	"tags": ["car"],
	"id": 11,
	"description": "go to washing car",
	"state": "new",
	"name": "wash car",
	"version": "v1"
}, {
	"tags": ["home", "yard"],
	"id": 12,
	"description": "mowing the lawn",
	"state": "new",
	"name": "lawn mowing",
	"version": "v1"
}]
```

Example: Get all with given names

```
curl 'http://localhost:8003/todoapp/v1/tasks?name=wash%20car,lawn%20mowing'

[{
	"tags": ["car"],
	"id": 11,
	"description": "go to washing car",
	"state": "new",
	"name": "wash car",
	"version": "v1"
}, {
	"tags": ["home", "yard"],
	"id": 12,
	"description": "mowing the lawn",
	"state": "new",
	"name": "lawn mowing",
	"version": "v1"
}]
```

Example: Get all tasks matching with tags

```
curl 'http://localhost:8003/todoapp/v1/tasks?tags=home,car'

[{
	"tags": ["car"],
	"id": 11,
	"description": "go to washing car",
	"state": "new",
	"name": "wash car",
	"version": "v1"
}, {
	"tags": ["home", "yard"],
	"id": 12,
	"description": "mowing the lawn",
	"state": "new",
	"name": "lawn mowing",
	"version": "v1"
}]
```

Example: Get all tasks matching with name, state and tags

```
curl 'http://localhost:8003/todoapp/v1/tasks?tags=yard,car&state=new&name=lawn%20mowing'

[{
	"tags": ["home", "yard"],
	"id": 12,
	"description": "mowing the lawn",
	"state": "new",
	"name": "lawn mowing",
	"version": "v1"
}]
```

## Port number

By default **todoapp** is using port number **8003**.
Port number can be defined to be something else by setting
**TODOAPP_PORT** environment variable:

Example:

```
export TODOAPP_PORT=9001

$ ./todoapp
todoapp: 2021/07/12 16:13:21 :'...serving...'

curl http://localhost:8003/todoapp/v1/tasks
localhost port 8003: Connection refused

curl http://localhost:9001/todoapp/v1/tasks
[{"id": 11, "description": "", "name": "A", "tags": [], "state": "new", "version": "v1"}, {"id": 12, "description": "", "name": "B", "tags": [], "state": "new", "version": "v1"}]
```

## Implementation

Server is implemented with:

* **todoapp.go** => thin Go language wrapper (main program) to run todoapp.fnl
* **todoapp.fnl** => main module, sets up store interface and HTTP routing
* **uc.fnl** => use case implementations, uses store interface and domain functions
* **http.fnl** => contains HTTP and JSON processing for requests and responses (uses **httprouter**)
* **domain.fnl** => pure functions to implement task data handling
* **er.fnl** => error values defined between **uc** and **http** modules
* **imported/httprouter.fnl** => HTTP router library implemented in FunL
* **ValueZ** data store is used for storing tasks

In addition to Go language [FunL](https://github.com/anssihalmeaho/funl) language is used in implementation.

File embedding (Go language feature) is used in embedding FunL source files into one executable.
Go wrapper todoapp.go sets up following modules to FunL module cache:

* ValueZ value store (external module implemented in Go): https://github.com/anssihalmeaho/fuvaluez
* httprouter: https://github.com/anssihalmeaho/httprouter
* domain
* er
* uc
* http

ValueZ creates **tasks.db** file to working directory which contains all task data.

### Clean architecture

Implementation structure is based on so-called __Clean Architecture__ model:

* externals (ValueZ data store, HTTP/JSON processing)
* interfaces or adapters (store interface, which hides data storage)
* use case layer (**uc** module)
* domain model or entities (**domain** module)

There's also "main" programs to setup other parts:

* **todoapp.go** sets up needed source modules and external library (ValueZ)
* **todoapp.fnl** is FunL main module to setup store interface, use case layer and HTTP module

Clean Architecture (or Onion Architecture or Hexagonal Architecture or functional core, imperative shell), see:
https://github.com/kbilsted/Functional-core-imperative-shell/blob/master/README.md

Here's also blog writing where division is made in example so that impure part is implemented with Go and pure functional part in FunL:
https://programmingfunl.wordpress.com/2021/04/19/using-funl-as-functional-core-embedded-in-go

**Todoapp architecture**: 

![](https://github.com/anssihalmeaho/todoapp/blob/main/todo_arch.png)


