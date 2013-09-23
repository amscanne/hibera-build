#!/usr/bin/make -f

VERSION ?= 0.0
RELEASE ?= 1
MAINTAINER ?= Adin Scannell <adin@scannell.ca>
SUMMARY ?= A distributed control plane for reliable applications.
URL ?= http://github.com/amscanne/hibera

# Our GO source build command.
go_build = @GOPATH=$(CURDIR) $(1)

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

PREFIX := github.com/amscanne/hibera
PACKAGES := $(shell cd src/$(PREFIX) && ls -1 | grep -v README)

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

build-%: fmt-% test-%
	$(call go_build,go build $(PREFIX)/$*)
install-%: fmt-% test-%
	$(call go_build,go install $(PREFIX)/$*)
test-%:
	$(call go_build,go test $(PREFIX)/$*)
bench-%:
	$(call go_build,go test -bench=".*" $(PREFIX)/$*)
fmt-%:
	$(call go_build,gofmt -l=true -w=true -tabs=false -tabwidth=4 src/$(PREFIX)/$*)

submodules:
.PHONY: submodules

go-%:
ifeq ($(PACKAGES),)
	@git submodules init && git submodules update
endif
	@$(MAKE) $(foreach pkg,$(PACKAGES),$*-$(pkg))
go-doc: doc-root

dist: go-install
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
