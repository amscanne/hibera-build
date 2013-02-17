#!/usr/bin/make -f

PACKAGES:=$(shell cd src/hibera && ls)
PROTOCOLS:=$(shell find src/hibera -name \*.proto)
PROTOCOLSGO:=$(patsubst %.proto,%.pb.go,$(PROTOCOLS))
BINARIES:=hibera hiberad

all: build
.PHONY: all

build: do-build
.PHONY: build
install: do-install
.PHONY: install
doc: do-doc
.PHONY: doc
test: do-test
.PHONY: test
fmt: do-fmt
.PHONY: fmt

protoc:
	@GOPATH=$(CURDIR) go get \
	    code.google.com/p/goprotobuf/proto
	@GOPATH=$(CURDIR) go get \
	    code.google.com/p/goprotobuf/protoc-gen-go
	@GOPATH=$(CURDIR) go install \
	    code.google.com/p/goprotobuf/proto
	@GOPATH=$(CURDIR) go install \
	    code.google.com/p/goprotobuf/protoc-gen-go
.PHONY: protoc

clean:
	@rm -rf bin/ pkg/ $(BINARIES)
.PHONY: clean

%.pb.go: protoc %.proto
	@PATH=$(CURDIR)/bin/:$(PATH) protoc --go_out=$(CURDIR) $*.proto

build-%: $(PROTOCOLSGO)
	@GOPATH=$(CURDIR) go build hibera/$*
install-%:
	@GOPATH=$(CURDIR) go install hibera/$*
doc-%:
	@GOPATH=$(CURDIR) go doc hibera/$*
test-%:
	@GOPATH=$(CURDIR) go test hibera/$*
fmt-%:
	@GOPATH=$(CURDIR) go fmt hibera/$*

do-%:
	@$(MAKE) $(foreach pkg,$(PACKAGES),$*-$(pkg))
