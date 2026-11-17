# Lumaware: menubar app that dims displays unless the mouse is on them.
#
#   make              build build/Lumaware.app (universal: arm64 + x86_64)
#   make run          build and launch it
#   make install      copy to /Applications (restarts a running copy)
#   make uninstall    remove it from /Applications and its login item
#   make zip          build/Lumaware-<version>.zip for sharing
#   make verify       show architectures and check the code signature
#   make clean
#
# Overrides, e.g.:  make VERSION=1.2.0 SIGN_ID="Developer ID Application: Name (TEAMID)"
#                   make EXTRA_FLAGS=-suppress-warnings

APP_NAME   := Lumaware
BUNDLE_ID  := com.0xbogon.lumaware
VERSION    ?= 1.0.0

ARM_MIN    := 11.0
X86_MIN    := 10.15
SIGN_ID    ?= -
SWIFTFLAGS := -O -swift-version 5 $(EXTRA_FLAGS)

SRC_DIR    := Sources/$(APP_NAME)
SOURCES    := $(wildcard $(SRC_DIR)/*.swift)
BUILD      := build
APP        := $(BUILD)/$(APP_NAME).app
CONTENTS   := $(APP)/Contents
INSTALLED  := /Applications/$(APP_NAME).app

.PHONY: all app run install uninstall zip verify clean
all: app
app: $(APP)

# One binary per architecture...
$(BUILD)/arm64/$(APP_NAME): $(SOURCES)
	@mkdir -p $(dir $@)
	swiftc $(SWIFTFLAGS) -target arm64-apple-macos$(ARM_MIN) -o $@ $(SOURCES)

$(BUILD)/x86_64/$(APP_NAME): $(SOURCES)
	@mkdir -p $(dir $@)
	swiftc $(SWIFTFLAGS) -target x86_64-apple-macos$(X86_MIN) -o $@ $(SOURCES)

# ...merged into one universal binary.
$(BUILD)/$(APP_NAME): $(BUILD)/arm64/$(APP_NAME) $(BUILD)/x86_64/$(APP_NAME)
	lipo -create -output $@ $^

# App icon, drawn in code.
$(BUILD)/AppIcon.icns: scripts/make-icon.swift
	rm -rf $(BUILD)/AppIcon.iconset
	swift scripts/make-icon.swift $(BUILD)/AppIcon.iconset
	iconutil -c icns $(BUILD)/AppIcon.iconset -o $@

$(APP): $(BUILD)/$(APP_NAME) $(BUILD)/AppIcon.icns resources/Info.plist
	rm -rf $(APP)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources
	cp $(BUILD)/$(APP_NAME) $(CONTENTS)/MacOS/$(APP_NAME)
	cp $(BUILD)/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns
	sed -e 's/@NAME@/$(APP_NAME)/g' -e 's/@BUNDLE_ID@/$(BUNDLE_ID)/g' -e 's/@VERSION@/$(VERSION)/g' \
		resources/Info.plist > $(CONTENTS)/Info.plist
	printf 'APPL????' > $(CONTENTS)/PkgInfo
	codesign --force --deep --sign "$(SIGN_ID)" $(APP)
	@echo "Built $(APP)"
	@lipo -info $(CONTENTS)/MacOS/$(APP_NAME)

run: app
	-pkill -x $(APP_NAME)
	open $(APP)

install: app
	-pkill -x $(APP_NAME)
	rm -rf $(INSTALLED)
	cp -R $(APP) $(INSTALLED)
	@echo "Installed $(INSTALLED)"

uninstall:
	-pkill -x $(APP_NAME)
	rm -rf $(INSTALLED)
	rm -f $(HOME)/Library/LaunchAgents/$(BUNDLE_ID).plist
	@echo "Removed $(APP_NAME)"

zip: app
	cd $(BUILD) && ditto -c -k --keepParent $(APP_NAME).app $(APP_NAME)-$(VERSION).zip
	@echo "Created $(BUILD)/$(APP_NAME)-$(VERSION).zip"

verify: app
	lipo -info $(CONTENTS)/MacOS/$(APP_NAME)
	codesign --verify --deep --strict --verbose=2 $(APP)

clean:
	rm -rf $(BUILD)
