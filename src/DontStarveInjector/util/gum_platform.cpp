#include "gum_platform.hpp"
#include <filesystem>
#include <frida-gum.h>
#include <list>
#include <string_view>
#ifdef _WIN32
#include "module.hpp"
#endif

#include "platform.hpp"

namespace {
std::string_view filename(std::string_view path) {
    const auto separator = path.find_last_of("/\\");
    return separator == std::string_view::npos ? path : path.substr(separator + 1);
}

bool module_matches(const char *target, GumModule *module) {
    if (!target || !*target || !module) {
        return false;
    }

    const std::string_view requested{target};
    const std::string_view requested_filename = filename(requested);
    const char *module_name_raw = gum_module_get_name(module);
    const char *module_path_raw = gum_module_get_path(module);
    const std::string_view module_name = module_name_raw ? module_name_raw : "";
    const std::string_view module_path = module_path_raw ? module_path_raw : "";

    return requested == module_name || requested == module_path ||
           requested_filename == filename(module_name) ||
           requested_filename == filename(module_path);
}
}

GumModule *gum_find_module_by_name_or_path(const char *maybeName) {
    if (!maybeName || !*maybeName) {
        return nullptr;
    }

    if (auto *module = gum_process_find_module_by_name(maybeName)) {
        return module;
    }

    struct Search {
        const char *name;
        GumModule *module;
    } search{maybeName, nullptr};

    gum_process_enumerate_modules(
            +[](GumModule *module, gpointer user_data) -> gboolean {
                auto *search = static_cast<Search *>(user_data);
                if (!module_matches(search->name, module)) {
                    return true;
                }

                search->module = static_cast<GumModule *>(g_object_ref(module));
                return false;
            },
            &search);
    return search.module;
}

GumModule *gum_find_or_load_module(const char *name, GError **error) {
    if (auto *module = gum_find_module_by_name_or_path(name)) {
        return module;
    }

#ifndef _WIN32
    loadlib(name);
    if (auto *module = gum_find_module_by_name_or_path(name)) {
        return module;
    }
#endif

    return gum_module_load(name, error);
}

std::string get_module_path(const char *maybeName, uintptr_t ptr) {
    std::list<std::string> res;
    auto arg = std::tuple{&res, maybeName, ptr};
    gum_process_enumerate_modules(
            +[](GumModule *module,
                gpointer user_data) -> gboolean {
                auto &[res, maybeName, ptr] = *(decltype(arg) *) user_data;
                auto module_name = gum_module_get_name(module);
                if (std::string_view(module_name).contains(maybeName)) {
                    auto range = gum_module_get_range(module);
                    if (ptr != 0 && !(range->base_address <= ptr && ptr < range->base_address + range->size))
                        return true;
                    auto path = gum_module_get_path(module);
                    res->push_back(path);
                    return true;
                }
                return true;
            },
            (void *) &arg);
    if (res.empty()) {
        return {};
    }
    for (auto &p: res) {
        if (p == maybeName)
            return p;
    }
    return res.back();
}

void gum_module_enumerate_imports_ext(GumModule *self,
                                      GumFoundImportFunc func,
                                      gpointer user_data) {
    auto range = gum_module_get_range(self);
#ifdef _WIN32
    std::pair args = {func, user_data};
    auto module = (HMODULE) range->base_address;
    module_enumerate_imports(module, +[](const ImportDetails *details, void *ud) {
        auto [func, user_data] = *(decltype(args) *) ud;
        GumImportDetails gumdetails;
        gumdetails.type = GUM_IMPORT_FUNCTION;
        gumdetails.name = details->name;
        gumdetails.address = (GumAddress)details->address;
        gumdetails.slot = (GumAddress)details->slot;
        bool ret = func(&gumdetails, user_data);
        return ret;
     }, (void*)&args);
#else
    gum_module_enumerate_imports(self, func, user_data);
#endif
}
