#include "plugin_runtime.hpp"
#include "sample_plugin_export.h"
extern "C" SAMPLE_PLUGIN_EXPORT int sample_plugin_probe() {
  return sample_plugin_runtime_value();
}
