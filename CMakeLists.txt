cmake_minimum_required(VERSION 3.20)

project(tmux-bar
  VERSION 1.1.0
  LANGUAGES C OBJC OBJCXX
)

set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum macOS version")

if(NOT APPLE)
  message(FATAL_ERROR "tmux-bar is a macOS application; this project only supports APPLE builds.")
endif()

set(TMUX_BAR_SOURCES
  Sources/main.m
  Sources/AppDelegate.m
  Sources/FocusWatcher.m
  Sources/TouchBarController.m
  Sources/TmuxClient.mm
  Sources/Models.m
  Sources/AboutWindowController.m
)

# Capture git metadata for the About panel (build number + short commit).
find_package(Git QUIET)
set(TMUX_BAR_GIT_COMMIT "unknown")
set(TMUX_BAR_GIT_BUILD "0")
if(GIT_FOUND AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" rev-parse --short=8 HEAD
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    OUTPUT_VARIABLE TMUX_BAR_GIT_COMMIT_RAW
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
    RESULT_VARIABLE TMUX_BAR_GIT_COMMIT_RESULT
  )
  if(TMUX_BAR_GIT_COMMIT_RESULT EQUAL 0 AND TMUX_BAR_GIT_COMMIT_RAW)
    set(TMUX_BAR_GIT_COMMIT "${TMUX_BAR_GIT_COMMIT_RAW}")
  endif()
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" rev-list --count HEAD
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    OUTPUT_VARIABLE TMUX_BAR_GIT_BUILD_RAW
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
    RESULT_VARIABLE TMUX_BAR_GIT_BUILD_RESULT
  )
  if(TMUX_BAR_GIT_BUILD_RESULT EQUAL 0 AND TMUX_BAR_GIT_BUILD_RAW)
    set(TMUX_BAR_GIT_BUILD "${TMUX_BAR_GIT_BUILD_RAW}")
  endif()
endif()

set(TMUX_BAR_COMMITTED_ICNS "${CMAKE_CURRENT_SOURCE_DIR}/Resources/AppIcon.icns")
set(TMUX_BAR_SOURCE_PNG "${CMAKE_CURRENT_SOURCE_DIR}/Resources/AppIcon.source.png")
set(TMUX_BAR_GENERATED_ICNS "${CMAKE_CURRENT_BINARY_DIR}/AppIcon.icns")

if(EXISTS "${TMUX_BAR_COMMITTED_ICNS}")
  set(TMUX_BAR_APP_ICON "${TMUX_BAR_COMMITTED_ICNS}")
  set(TMUX_BAR_APP_ICON_GENERATED FALSE)
else()
  set(TMUX_BAR_APP_ICON "${TMUX_BAR_GENERATED_ICNS}")
  set(TMUX_BAR_APP_ICON_GENERATED TRUE)
  find_package(Python3 COMPONENTS Interpreter REQUIRED)
  if(EXISTS "${TMUX_BAR_SOURCE_PNG}")
    add_custom_command(
      OUTPUT "${TMUX_BAR_GENERATED_ICNS}"
      COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/gen_app_icon.py"
        "${TMUX_BAR_GENERATED_ICNS}"
        "${TMUX_BAR_SOURCE_PNG}"
      DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/gen_app_icon.py"
        "${TMUX_BAR_SOURCE_PNG}"
      COMMENT "Building AppIcon.icns from Resources/AppIcon.source.png"
      VERBATIM
    )
  else()
    add_custom_command(
      OUTPUT "${TMUX_BAR_GENERATED_ICNS}"
      COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/gen_app_icon.py"
        "${TMUX_BAR_GENERATED_ICNS}"
      DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/cmake/gen_app_icon.py"
      COMMENT "Building placeholder AppIcon.icns"
      VERBATIM
    )
  endif()
  add_custom_target(tmux_bar_generate_app_icon DEPENDS "${TMUX_BAR_GENERATED_ICNS}")
endif()

add_executable(tmux-bar MACOSX_BUNDLE ${TMUX_BAR_SOURCES} "${TMUX_BAR_APP_ICON}")

if(TMUX_BAR_APP_ICON_GENERATED)
  add_dependencies(tmux-bar tmux_bar_generate_app_icon)
endif()

set_source_files_properties("${TMUX_BAR_APP_ICON}" PROPERTIES
  MACOSX_PACKAGE_LOCATION Resources
)

if(TMUX_BAR_APP_ICON_GENERATED)
  set_source_files_properties("${TMUX_BAR_APP_ICON}" PROPERTIES GENERATED TRUE)
endif()

set_target_properties(tmux-bar PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Sources/Info.plist"
  MACOSX_BUNDLE_GUI_IDENTIFIER "com.daxliar.tmuxbar"
  MACOSX_BUNDLE_BUNDLE_NAME "tmux-bar"
  MACOSX_BUNDLE_EXECUTABLE_NAME "tmux-bar"
  MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
  MACOSX_BUNDLE_LONG_VERSION_STRING "${PROJECT_VERSION}"
  MACOSX_BUNDLE_ICON_FILE "AppIcon"
  OUTPUT_NAME "tmux-bar"
  XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
  XCODE_ATTRIBUTE_COMBINE_HIDPI_IMAGES YES
)

target_include_directories(tmux-bar PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/Sources")

target_compile_definitions(tmux-bar PRIVATE
  "TMUX_BAR_VERSION=\"${PROJECT_VERSION}\""
  "TMUX_BAR_BUILD=\"${TMUX_BAR_GIT_BUILD}\""
  "TMUX_BAR_COMMIT=\"${TMUX_BAR_GIT_COMMIT}\""
)

target_link_libraries(tmux-bar PRIVATE
  "-framework Cocoa"
  "-framework AppKit"
)

target_compile_options(tmux-bar PRIVATE
  "$<$<COMPILE_LANGUAGE:C,OBJC,OBJCXX>:-fobjc-arc>"
)
