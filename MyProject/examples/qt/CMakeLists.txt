boilerplate_add_example(qt_widgets_example
  SOURCES main.cpp window.ui resources.qrc
  POLICIES qt-widgets
  LABELS qt)

if(_project_testing AND BOILERPLATE_BUILD_TESTS AND BUILD_TESTING)
  boilerplate_register_check(qt_widgets_smoke qt_widgets_example
    ARGS --smoke
    ENVIRONMENT QT_QPA_PLATFORM=offscreen
    LABELS smoke example qt)
endif()
