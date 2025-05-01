# Find Packages (commented out as in original, but now organized)

# fmt until all compilers will support C++20 format and C++23 print
# find_package(fmt)
# alternative for cin(C++ streams) and scanf(C std non typesafe func)
# find_package(scnlib)

# boost
# find_package(Boost)

# graphics
# find_package(glfw3 CONFIG REQUIRED)
# find_package(glm CONFIG REQUIRED)
# find_package(GLEW REQUIRED)
# find_package(imgui CONFIG REQUIRED)

# regex
# find_package(ctre)

# sfml
# find_package(SFML COMPONENTS system window graphics CONFIG REQUIRED)

# poco
# find_package(Poco REQUIRED Data Net Util XML)

# Link libs with target glm
# target_link_libraries(${PROJECT_NAME} glm::glm)

# glfw
# target_link_libraries(${PROJECT_NAME} PRIVATE glfw)

# glew
# target_link_libraries(${PROJECT_NAME} GLEW::GLEW)

# imgui
# target_link_libraries(${PROJECT_NAME} imgui::imgui)

# crte
# target_link_libraries(${PROJECT_NAME} ctre::ctre)

# sfml
# target_link_libraries(${PROJECT_NAME} sfml::sfml)

# poco
# target_link_libraries(${PROJECT_NAME} Poco::Data Poco::Net Poco::Util Poco::XML)

# boost
# if(NOT WIN32)
#   target_link_libraries(${PROJECT_NAME} boost::system pthread)
# else()
#   target_link_libraries(${PROJECT_NAME} boost::system)
# endif()
