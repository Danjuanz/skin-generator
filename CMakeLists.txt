cmake_minimum_required(VERSION 3.20)
project(skins_generator)
# Debug
#set(CMAKE_BUILD_TYPE Debug)
set(CMAKE_CXX_STANDARD 20)

# [改动1] 依赖根目录集中配置：Boost 在 <root>/boost_library，新版 CMake 用 BoostConfig 找
if (NOT DEFINED DEPS_ROOT)
    set(DEPS_ROOT "D:/C++/vslibs")
endif ()
set(CMAKE_PREFIX_PATH "${DEPS_ROOT};${DEPS_ROOT}/boost_library;${DEPS_ROOT}/dist/zlib;${DEPS_ROOT}/dist/libzip")
set(Boost_ROOT "${DEPS_ROOT}/boost_library")
# [改动5] 必须用 Release 版 zlib/libzip：Debug 版带 /RTC1，libzip 1.11.2 的 zip_close
#         有个未初始化变量 have_dos_time 会触发 RTC 检查，弹出一个看不见的模态框 → 看起来像卡死
set(ZLIB_ROOT "${DEPS_ROOT}/dist/zlib")
set(LIBZIP_ROOT "${DEPS_ROOT}/dist/libzip")

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# [改动2] 源码是 UTF-8 无 BOM，中文系统下必须显式声明，否则 C4819 / 字符串乱码
if (MSVC)
    add_compile_options(/utf-8)
endif ()

set(PROJECT_VERSION_MAJOR 0)
set(PROJECT_VERSION_MINOR 3)
set(PROJECT_VERSION_PATCH 0)
set(PROJECT_RELEASE_TYPE "release")
set(PROJECT_VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}-${PROJECT_RELEASE_TYPE}")

configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/config.h.in"
        "${CMAKE_CURRENT_BINARY_DIR}/config.h"
)

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
file(GLOB HEADER_FILES include/*.h)
file(GLOB SOURCE_FILES src/*.cpp)
message(STATUS "HEADER_FILES: ${HEADER_FILES}")
message(STATUS "SOURCE_FILES: ${SOURCE_FILES}")
include_directories(${CMAKE_SOURCE_DIR}/include ${CMAKE_CURRENT_BINARY_DIR})
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
message(STATUS "CMAKE_RUNTIME_OUTPUT_DIRECTORY: ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
file(REMOVE_RECURSE "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/resource")
file(COPY
        "${CMAKE_CURRENT_SOURCE_DIR}/resource"
        DESTINATION "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}"
)
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# BOOST
# [改动3] 删掉 add_definitions(-DBOOST_USE_WINAPI_VERSION=0x0600)
#         预编译的 Boost 是 WinAPI 0x0A00(nt62)，强行声明 0x0600 会导致 41 个 boost::log 符号解析失败
set(Boost_USE_STATIC_LIBS OFF)   # 预编译包只有 shared 版，BoostConfig 默认找 static
find_package(Boost CONFIG REQUIRED COMPONENTS log log_setup)
if (Boost_FOUND)
    message(STATUS "Boost library status:")
    message(STATUS "    Boost_VERSION: ${Boost_VERSION}")
    message(STATUS "    Boost_INCLUDE_DIRS: ${Boost_INCLUDE_DIRS}")
    message(STATUS "    Boost_LIBRARIES: ${Boost_LIBRARIES}")
else ()
    message(FATAL_ERROR "Boost not found.")
endif ()

# zlib
find_package(ZLIB REQUIRED)
if (ZLIB_FOUND)
    message(STATUS "ZLIB version: ${ZLIB_VERSION_STRING}")
else ()
    message(FATAL_ERROR "ZLIB not found.")
endif ()
# libzip
find_package(LIBZIP REQUIRED)
if (LIBZIP_FOUND)
    message(STATUS "LibZip version: ${LIBZIP_VERSION}")
else ()
    message(FATAL_ERROR "LibZip not found.")
endif ()
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
add_executable(skins_generator src/Generator.cpp ${HEADER_FILES} ${SOURCE_FILES})
target_compile_options(skins_generator PRIVATE $<$<CONFIG:Release>:/O2>)

target_link_libraries(skins_generator
        ${Boost_LIBRARIES}
        libzip::zip
        ZLIB::ZLIB
)

# [改动4] 运行期 DLL 直接拷到 exe 旁边：libzip / zlib 是 Debug 版，Boost 是动态库
file(GLOB BOOST_RUNTIME_DLLS
        "${Boost_ROOT}/lib/boost_filesystem-*-x64-*.dll"
        "${Boost_ROOT}/lib/boost_log-*-x64-*.dll"
        "${Boost_ROOT}/lib/boost_log_setup-*-x64-*.dll"
        "${Boost_ROOT}/lib/boost_thread-*-x64-*.dll")
add_custom_command(
        TARGET skins_generator
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${BOOST_RUNTIME_DLLS}
            "D:/C++/vslibs/dist/zlib/bin/zlib.dll"
            "D:/C++/vslibs/dist/libzip/bin/zip.dll"
            "$<TARGET_FILE_DIR:skins_generator>"
)