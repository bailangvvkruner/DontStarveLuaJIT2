#pragma once
#include <string>
#include <cstdint>
#include <frida-gum.h>

std::string get_module_path(const char *maybeName, uintptr_t ptr = 0);

GumModule *gum_find_module_by_name_or_path(const char *maybeName);

GumModule *gum_find_or_load_module(const char *name, GError **error);

void gum_module_enumerate_imports_ext(GumModule * self,
                              GumFoundImportFunc func,
                              gpointer user_data);
