# F-Droid Release Guide

## Prerequisites

1. GitHub account with your app's source code
2. GitLab account (for fdroiddata)
3. Android SDK installed

## Build Steps

### 1. Build the F-Droid APK

```bash
./build_fdroid.sh
```

This will create: `build/app/outputs/apk/fdroid/release/app-fdroid-release.apk`

### 2. Rename the APK for release

```bash
cp build/app/outputs/apk/fdroid/release/app-fdroid-release.apk hdict-1.5.14-fdroid.apk
```

### 3. Create GitHub Release

1. Go to: https://github.com/drdhaval2785/hdict/releases
2. Click "Create a new release"
3. Tag: `v1.5.14`
4. Title: `Version 1.5.14`
5. Upload `hdict-1.5.14-fdroid.apk`
6. Click "Publish release"

### 4. Submit to F-Droid

#### Option A: Using fdroidserver (Recommended)

```bash
# Clone fdroiddata
git clone --depth=1 https://gitlab.com/YOUR_USERNAME/fdroiddata.git
cd fdroiddata

# Install fdroidserver
git clone --depth=1 https://gitlab.com/fdroid/fdroidserver.git ~/fdroidserver
export PATH="$PATH:$PWD/fdroidserver"

# Initialize
fdroid init
fdroid readmeta

# Add your app metadata
# Copy fdroid_metadata/in.sanskritworld.hdict.yml to metadata/in.sanskritworld.hdict.yml

# Test build
fdroid build -v -l in.sanskritworld.hdict

# Commit and push
git checkout -b in.sanskritworld.hdict
git add metadata/in.sanskritworld.hdict.yml
git commit -m "New app: hdict - Sanskrit Dictionary"
git push origin in.sanskritworld.hdict
```

#### Option B: GitLab Issue (Simpler)

1. Go to: https://gitlab.com/fdroid/fdroiddata/-/issues
2. Create new issue with "Request for Packaging" template
3. Fill in the required information

## Files Provided

- `build_fdroid.sh` - Build script
- `fastlane/metadata/android/en-US/` - App metadata for F-Droid store
- `fdroid_metadata/in.sanskritworld.hdict.yml` - Build recipe for F-Droid

## Notes

- The app uses GPL-3.0 license (compatible with F-Droid)
- The fdroid flavor uses null signing (your signature will be preserved via reproducible builds)
- App ID: `in.sanskritworld.hdict`