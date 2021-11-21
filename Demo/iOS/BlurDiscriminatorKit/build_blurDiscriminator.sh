FRAMEWORK_NAME="BlurDiscriminatorKit"

PATH_OF_ARTIFACT="./artifact"
PATF_OF_DEVICE_FRAMEWORK="${PATH_OF_ARTIFACT}/Build/Products/Release-iphoneos/${FRAMEWORK_NAME}.framework"
PATF_OF_SIMULATOR_FRAMEWORK="${PATH_OF_ARTIFACT}/Build/Products/Release-iphonesimulator/${FRAMEWORK_NAME}.framework"
PATH_OF_XCFRAMEWORK="./built_xcframework"

xcodebuild build -project BlurDiscriminatorKit.xcodeproj \
                       -scheme BlurDiscriminatorKit \
                       -sdk iphonesimulator \
                       -configuration Release \
                       -derivedDataPath "${PATH_OF_ARTIFACT}"

xcodebuild build -project BlurDiscriminatorKit.xcodeproj \
                       -scheme BlurDiscriminatorKit \
                       -sdk iphoneos \
                       -configuration Release \
                       -derivedDataPath "${PATH_OF_ARTIFACT}"

if [ -e "${PATH_OF_XCFRAMEWORK}" ]; then
  rm -rf "${PATH_OF_XCFRAMEWORK}"
fi

xcodebuild -create-xcframework -framework "${PATF_OF_DEVICE_FRAMEWORK}" \
                               -framework "${PATF_OF_SIMULATOR_FRAMEWORK}" \
                               -output "built_xcframework/${FRAMEWORK_NAME}.xcframework"

if [ -e "${PATH_OF_ARTIFACT}" ]; then
  rm -rf "${PATH_OF_ARTIFACT}"
fi
