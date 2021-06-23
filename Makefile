GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test

BINARY_NAME=todoapp

all: build

build:
	$(GOBUILD) -o $(BINARY_NAME) -v .

clean:
	$(GOCLEAN)
	rm -f $(BINARY_NAME)
