#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <systemd/sd-bus.h>

static int contains_control_character(const char *value) {
    for (const unsigned char *p = (const unsigned char *)value; *p; p++) {
        if (*p < ' ' || *p == 0x7f)
            return 1;
    }
    return 0;
}

static void publish_current_state(sd_bus *bus, char *last_state, size_t size) {
    sd_bus_error error = SD_BUS_ERROR_NULL;
    sd_bus_message *reply = NULL;
    const char *state = NULL;

    int result = sd_bus_call_method(
        bus,
        "org.fcitx.Fcitx5",
        "/controller",
        "org.fcitx.Fcitx.Controller1",
        "CurrentInputMethod",
        &error,
        &reply,
        "");

    if (result >= 0)
        result = sd_bus_message_read(reply, "s", &state);

    if (result >= 0 && state && state[0] != '\0' &&
        !contains_control_character(state) &&
        strncmp(state, last_state, size) != 0) {
        snprintf(last_state, size, "%s", state);
        puts(last_state);
        fflush(stdout);
    }

    sd_bus_error_free(&error);
    sd_bus_message_unref(reply);
}

static int list_group_methods(sd_bus *bus) {
    sd_bus_error error = SD_BUS_ERROR_NULL;
    sd_bus_message *reply = NULL;
    const char *group = NULL;
    const char *layout = NULL;
    char **group_ids = NULL;
    size_t group_count = 0;
    int result = sd_bus_call_method(
        bus, "org.fcitx.Fcitx5", "/controller",
        "org.fcitx.Fcitx.Controller1", "CurrentInputMethodGroup",
        &error, &reply, "");

    if (result >= 0)
        result = sd_bus_message_read(reply, "s", &group);
    if (result < 0 || !group)
        goto done;

    size_t group_size = strlen(group) + 1;
    char *group_copy = malloc(group_size);
    if (group_copy)
        memcpy(group_copy, group, group_size);
    sd_bus_message_unref(reply);
    reply = NULL;
    sd_bus_error_free(&error);
    error = SD_BUS_ERROR_NULL;
    if (!group_copy)
        return 1;

    result = sd_bus_call_method(
        bus, "org.fcitx.Fcitx5", "/controller",
        "org.fcitx.Fcitx.Controller1", "InputMethodGroupInfo",
        &error, &reply, "s", group_copy);
    free(group_copy);
    if (result < 0)
        goto done;

    result = sd_bus_message_read(reply, "s", &layout);
    if (result < 0)
        goto done;
    result = sd_bus_message_enter_container(reply, 'a', "(ss)");
    if (result < 0)
        goto done;

    for (;;) {
        const char *id = NULL;
        const char *method_layout = NULL;
        result = sd_bus_message_enter_container(reply, 'r', "ss");
        if (result <= 0)
            break;
        result = sd_bus_message_read(reply, "ss", &id, &method_layout);
        if (result < 0)
            break;
        if (id && id[0] != '\0') {
            char **next_ids = realloc(group_ids, sizeof(*group_ids) * (group_count + 1));
            if (!next_ids) {
                result = -1;
                break;
            }
            group_ids = next_ids;
            size_t id_size = strlen(id) + 1;
            group_ids[group_count] = malloc(id_size);
            if (!group_ids[group_count]) {
                result = -1;
                break;
            }
            memcpy(group_ids[group_count], id, id_size);
            group_count++;
        }
        sd_bus_message_exit_container(reply);
    }
    if (result < 0)
        goto done;

    sd_bus_message_unref(reply);
    reply = NULL;
    sd_bus_error_free(&error);
    error = SD_BUS_ERROR_NULL;

    result = sd_bus_call_method(
        bus, "org.fcitx.Fcitx5", "/controller",
        "org.fcitx.Fcitx.Controller1", "AvailableInputMethods",
        &error, &reply, "");
    if (result < 0)
        goto done;
    result = sd_bus_message_enter_container(reply, 'a', "(ssssssb)");
    if (result < 0)
        goto done;

    for (;;) {
        const char *id = NULL;
        const char *name = NULL;
        const char *native_name = NULL;
        const char *icon = NULL;
        const char *label = NULL;
        const char *language = NULL;
        int configurable = 0;
        result = sd_bus_message_enter_container(reply, 'r', "ssssssb");
        if (result <= 0)
            break;
        result = sd_bus_message_read(reply, "ssssssb", &id, &name, &native_name,
                                     &icon, &label, &language, &configurable);
        if (result < 0)
            break;
        if (!id || contains_control_character(id)) {
            sd_bus_message_exit_container(reply);
            continue;
        }

        for (size_t i = 0; i < group_count; i++) {
            if (strcmp(group_ids[i], id) == 0) {
                const char *safe_name =
                    name && name[0] && !contains_control_character(name)
                        ? name : id;
                const char *safe_language =
                    language && !contains_control_character(language)
                        ? language : "";
                printf("%zu\t%s\t%s\t%s\n", i, id,
                       safe_name, safe_language);
                break;
            }
        }
        sd_bus_message_exit_container(reply);
    }
    fflush(stdout);
    result = result < 0 ? result : 0;

done:
    for (size_t i = 0; i < group_count; i++)
        free(group_ids[i]);
    free(group_ids);
    sd_bus_error_free(&error);
    sd_bus_message_unref(reply);
    return result < 0 ? 1 : 0;
}

static int set_current_method(sd_bus *bus, const char *id) {
    sd_bus_error error = SD_BUS_ERROR_NULL;
    sd_bus_message *reply = NULL;
    int result = sd_bus_call_method(
        bus, "org.fcitx.Fcitx5", "/controller",
        "org.fcitx.Fcitx.Controller1", "SetCurrentIM",
        &error, &reply, "s", id);
    sd_bus_error_free(&error);
    sd_bus_message_unref(reply);
    return result < 0 ? 1 : 0;
}

int main(int argc, char **argv) {
    sd_bus *bus = NULL;
    char last_state[128] = "";
    int result;

    if (sd_bus_default_user(&bus) < 0)
        return 1;

    if (argc == 2 && strcmp(argv[1], "--list") == 0)
        return list_group_methods(bus);
    if (argc == 3 && strcmp(argv[1], "--set") == 0)
        return set_current_method(bus, argv[2]);
    if (argc != 1) {
        fprintf(stderr, "usage: %s [--list | --set INPUT_METHOD]\n", argv[0]);
        return 2;
    }

    for (;;) {
        publish_current_state(bus, last_state, sizeof(last_state));

        // CurrentInputMethod has no change signal in Fcitx 5.1.21. Waiting on
        // the bus keeps this process asleep between inexpensive method calls.
        result = sd_bus_wait(bus, 750000);
        if (result < 0) {
            fprintf(stderr, "failed to wait on user bus: %s\n",
                    strerror(-result));
            break;
        }

        while ((result = sd_bus_process(bus, NULL)) > 0) {}
        if (result < 0) {
            fprintf(stderr, "failed to process user bus: %s\n",
                    strerror(-result));
            break;
        }
    }

    sd_bus_unref(bus);
    return 1;
}
