# the minimum version of CMake.
cmake_minimum_required(VERSION 3.4.1)
project(Map)

add_library(hello SHARED hello.cpp)
target_link_libraries(hello libhilog_ndk.z.so)
target_link_libraries(hello -lGLESv3)
target_link_libraries(hello libace_napi.z.so)