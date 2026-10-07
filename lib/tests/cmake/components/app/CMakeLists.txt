boilerplate_add_executable(component_app
        SOURCES main.cpp
        LIBRARIES component_core::component_core
        POLICIES minimal)

# boilerplate_add_component() must preserve native add_subdirectory scope semantics.
set(COMPONENT_PARENT_SCOPE_SIGNAL "published-by-app" PARENT_SCOPE)
