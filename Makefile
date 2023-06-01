# factorio-mod-makefile is released under the MIT license.  Informally, this
# means you can do basically whatever with it you like, as long as you leave this
# file intact.  The full legalese is below.
#
# factorio-mod-makefile is Copyright (c) 2015 Octav "narc" Sandulescu
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

PKG_NAME := $(shell cat PKG_NAME)
PACKAGE_NAME := $(if $(PKG_NAME),$(PKG_NAME),$(error No package name, please create PKG_NAME))
PACKAGE_NAME := $(if $(DEV),$(PACKAGE_NAME)-dev,$(PACKAGE_NAME))
ifneq ($(wildcard SHORT_VERSION),)
	VERSION := $(shell cat SHORT_VERSION || true)
	BUILD_NUMBER := $(shell git describe --tags --match 'v[0-9]*.[0-9]*' --long|cut -d- -f2 || echo 1)
	VERSION_STRING := $(if $(VERSION),$(VERSION).$(BUILD_NUMBER),$(error No version supplied, please add it as 'VERSION=x.y'))
else
	VERSION := $(shell cat VERSION || true)
	VERSION_STRING := $(if $(VERSION),$(VERSION),$(error No version supplied, please add it as 'VERSION=x.y.z'))
endif

OUTPUT_NAME := $(PACKAGE_NAME)_$(VERSION_STRING)
OUTPUT_DIR := pkg/$(OUTPUT_NAME)

PKG_COPY := $(wildcard *.md) $(shell cat PKG_COPY || true)

SED_FILES := $(shell find . -iname '*.json' -type f \! -path './pkg/*') \
             $(shell find . -iname '*.lua' -type f \! -path './pkg/*')
OUT_FILES := $(SED_FILES:%=$(OUTPUT_DIR)/%)

SED_EXPRS := -e 's/{{MOD_NAME}}/$(PACKAGE_NAME)/g'
SED_EXPRS += -e 's/{{VERSION}}/$(VERSION_STRING)/g'

all: package

package-copy: $(PKG_DIRS) $(PKG_FILES)
	mkdir -p $(OUTPUT_DIR)
ifneq ($(PKG_COPY),)
	cp -r $(PKG_COPY) pkg/$(OUTPUT_NAME)
endif

$(OUTPUT_DIR)/%.lua: %.lua
	mkdir -p $(@D)
	sed -e 's/{{__FILE__}}/'"$(strip $(subst /,\/, $(subst ./,,$*)))"'.lua/g' $(SED_EXPRS) $< > $@
	luac -p $@

$(OUTPUT_DIR)/%: %
	mkdir -p $(@D)
	sed $(SED_EXPRS) $< > $@

package-dir: package-copy $(OUT_FILES)

package: package-dir
	cd pkg && zip -r $(OUTPUT_NAME).zip $(OUTPUT_NAME)

clean:
	rm -rf pkg/$(OUTPUT_NAME)
