#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>

typedef void *(*find_module_fn)(const char *name);

int main(void) {
    find_module_fn find_module = (find_module_fn) dlsym(
        RTLD_DEFAULT, "gum_process_find_module_by_name");
    if (find_module == NULL) {
        fprintf(stderr, "gum_process_find_module_by_name is unavailable\n");
        _exit(1);
    }

    const char *modules[] = {
        "liblua51.so",
        "liblua51Original.so",
        "liblua51DS.so",
        "liblua51DS_gengc.so",
    };
    for (size_t i = 0; i < sizeof(modules) / sizeof(modules[0]); ++i) {
        if (find_module(modules[i]) == NULL) {
            fprintf(stderr, "preloaded module is missing from Gum: %s\n", modules[i]);
            _exit(1);
        }
    }

    _exit(0);
}
