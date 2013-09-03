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

clean:
	@rm -rf bin/ pkg/ dist/ doc/
	@rm -rf debbuild/ rpmbuild/ *.deb *.rpm
.PHONY: clean

build-%:
	@GOPATH=$(CURDIR) go build hibera/$*
install-%:
	@GOPATH=$(CURDIR) go install hibera/$*
doc-%:
	@mkdir -p doc/pkg/hibera/$*
	@GOPATH=$(CURDIR) godoc -html=true hibera/$* > doc/pkg/hibera/$*/index.html
doc-root:
	@mkdir -p doc/pkg/hibera
	@GOPATH=$(CURDIR) godoc -html=true hibera > doc/pkg/hibera/index.html
test-%:
	@GOPATH=$(CURDIR) go test hibera/$*
bench-%:
	@GOPATH=$(CURDIR) go test -bench=".*" hibera/$*
fmt-%:
	@gofmt -l=true -w=true -tabs=false -tabwidth=4 src/hibera/$*

submodules:
.PHONY: submodules

go-%:
ifeq ($(PACKAGES),)
	@git submodules init && git submodules update
endif
	@$(MAKE) $(foreach pkg,$(PACKAGES),$*-$(pkg))
go-doc: doc-root

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
