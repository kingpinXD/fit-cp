export ANDROID_HOME := $(HOME)/android-sdk

PKG := com.kingpinxd.fitcp
DEBUG_APK := build/app/outputs/flutter-apk/app-debug.apk
RELEASE_APK := build/app/outputs/flutter-apk/app-release.apk

.PHONY: build test analyze install install-phone check-phone clean run release distribute bump-version

build:
	flutter build apk --debug
	rm -f $(HOME)/Downloads/Fit.apk
	cp $(DEBUG_APK) $(HOME)/Downloads/Fit.apk
	@echo "APK copied to ~/Downloads/Fit.apk"

test:
	flutter test

analyze:
	flutter analyze

install:
	adb install $(DEBUG_APK)

check-phone:
	@tmpf=$$(mktemp); \
	adb devices -l 2>/dev/null | tail -n +2 | grep -v '^$$' | grep 'model:' | \
		sed 's/.*model://;s/ .*//' | sort -u > "$$tmpf"; \
	while read -r mdl; do \
		line=$$(adb devices -l </dev/null 2>/dev/null | grep "model:$$mdl " | head -1); \
		serial=$$(echo "$$line" | sed 's/  *device .*//'); \
		model=$$(adb -s "$$serial" shell getprop ro.product.model </dev/null 2>/dev/null | tr -d '\r'); \
		brand=$$(adb -s "$$serial" shell getprop ro.product.brand </dev/null 2>/dev/null | tr -d '\r'); \
		version=$$(adb -s "$$serial" shell dumpsys package $(PKG) </dev/null 2>/dev/null | grep versionName | head -1 | awk -F= '{print $$2}' | tr -d '\r'); \
		echo "$$brand $$model ($$serial) — installed: v$$version"; \
	done < "$$tmpf"; \
	rm -f "$$tmpf"

install-phone: build
	@tmpf=$$(mktemp); \
	adb devices -l 2>/dev/null | tail -n +2 | grep -v '^$$' | grep 'model:' | \
		sed 's/.*model://;s/ .*//' | sort -u > "$$tmpf"; \
	while read -r mdl; do \
		line=$$(adb devices -l </dev/null 2>/dev/null | grep "model:$$mdl " | head -1); \
		serial=$$(echo "$$line" | sed 's/  *device .*//'); \
		model=$$(adb -s "$$serial" shell getprop ro.product.model </dev/null 2>/dev/null | tr -d '\r'); \
		echo "Installing on $$model ($$serial)..."; \
		adb -s "$$serial" install -r $(DEBUG_APK) </dev/null && \
			echo "  done" || \
			echo "  FAILED"; \
	done < "$$tmpf"; \
	rm -f "$$tmpf"

clean:
	flutter clean

run: build
	adb wait-for-device
	adb install -r $(DEBUG_APK)
	adb shell am start -n $(PKG)/$(PKG).MainActivity

APP_ID := 1:1093127919791:android:81ec162d9501f0b16adc5a

release:
	flutter build apk --release
	cp $(RELEASE_APK) $(HOME)/Downloads/Fit.apk
	@echo "Release APK at ~/Downloads/Fit.apk"

bump-version:
	@current=$$(grep '^version:' pubspec.yaml | sed 's/version: //;s/+.*//'); \
	code=$$(grep '^version:' pubspec.yaml | sed 's/.*+//'); \
	major=$$(echo $$current | cut -d. -f1); \
	minor=$$(echo $$current | cut -d. -f2); \
	patch=$$(echo $$current | cut -d. -f3); \
	new_minor=$$((minor + 1)); \
	new_version="$$major.$$new_minor.$$patch"; \
	new_code=$$((code + 1)); \
	sed -i '' "s/^version: $$current+$$code$$/version: $$new_version+$$new_code/" pubspec.yaml; \
	echo "Bumped version: $$current ($$code) -> $$new_version ($$new_code)"

distribute: bump-version release
	firebase appdistribution:distribute $(RELEASE_APK) \
		--app $(APP_ID) \
		--groups "fit-app-testers" \
		--release-notes "$(NOTES)"
