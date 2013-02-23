#!/usr/bin/make -f

VERSION ?= 0.0
RELEASE ?= 1
MAINTAINER ?= Adin Scannell <adin@scannell.ca>
SUMMARY ?= A distributed control plane for reliable applications.
URL ?= http://github.com/amscanne/hibera

ARCH ?= $(shell arch)
ifeq ($(ARCH),x86_64)
DEB_ARCH := amd64
RPM_ARCH := x86_64
else
    ifeq ($(ARCH),i686)
DEB_ARCH := i386
RPM_ARCH := i386
    else
$(error Unknown arch "$(ARCH)".)
    endif
endif

PACKAGES := $(shell cd src/hibera && ls)
PROTOCOLS := $(shell find src/hibera -name \*.proto)
PROTOCOLSGO := $(patsubst %.proto,%.pb.go,$(PROTOCOLS))

all: dist
.PHONY: all

install: go-install
.PHONY: install
doc: go-doc
.PHONY: doc
test: go-test
.PHONY: test
fmt: go-fmt
.PHONY: fmt
packages: deb rpm
.PHONY: packages

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
	@rm -rf bin/ pkg/ dist/
	@rm -rf debbuild/ rpmbuild/ *.deb *.rpm
.PHONY: clean

%.pb.go: protoc %.proto
	@PATH=$(CURDIR)/bin/:$(PATH) protoc --go_out=$(CURDIR) $*.proto
	@rm -f bin/protoc-gen-go

build-%:
	@GOPATH=$(CURDIR) go build hibera/$*
install-%:
	@GOPATH=$(CURDIR) go install hibera/$*
doc-%:
	@GOPATH=$(CURDIR) go doc hibera/$*
test-%:
	@GOPATH=$(CURDIR) go test hibera/$*
bench-%:
	@GOPATH=$(CURDIR) go test -bench=".*" hibera/$*
fmt-%:
	@gofmt -l=true -w=true -tabindent=false -tabwidth=4 src/hibera/$*

go-%: $(PROTOCOLSGO)
	@$(MAKE) $(foreach pkg,$(PACKAGES),$*-$(pkg))

dist: go-test go-install
	@mkdir -p dist/usr/bin
	@install -m 0755 bin/* dist/usr/bin
	@rm -rf dist/etc && cp -ar etc/ dist/etc

deb: dist
	@rm -rf debbuild && mkdir -p debbuild
	@rsync -ruav packagers/DEBIAN debbuild
	@rsync -ruav dist/ debbuild
	@sed -i "s/VERSION/$(VERSION)-$(RELEASE)/" debbuild/DEBIAN/control
	@sed -i "s/MAINTAINER/$(MAINTAINER)/" debbuild/DEBIAN/control
	@sed -i "s/ARCHITECTURE/$(DEB_ARCH)/" debbuild/DEBIAN/control
	@sed -i "s/SUMMARY/$(SUMMARY)/" debbuild/DEBIAN/control
	@sed -i "s#URL#$(URL)#" debbuild/DEBIAN/control
	@fakeroot dpkg -b debbuild/ .

rpm: dist
	@rm -rf rpmbuild && mkdir -p rpmbuild
	@rpmbuild -bb --buildroot $(PWD)/rpmbuild/BUILDROOT \
	  --define="%_topdir $(PWD)/rpmbuild" \
	  --define="%version $(VERSION)" \
	  --define="%release $(RELEASE)" \
	  --define="%maintainer $(MAINTAINER)" \
	  --define="%architecture $(RPM_ARCH)" \
	  --define="%summary $(SUMMARY)" \
	  --define="%url $(URL)" \
	  packagers/hibera.spec
	@mv rpmbuild/RPMS/$(RPM_ARCH)/*.rpm .
