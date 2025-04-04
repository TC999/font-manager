/* font-manager-string-set.c
 *
 * Copyright (C) 2009-2025 Jerry Casiano
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.
 *
 * If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>.
*/

#include "font-manager-string-set.h"

/**
 * SECTION: font-manager-string-set
 * @short_description: Set of unique strings
 * @title: String Set
 * @include: font-manager-string-set.h
 *
 * #FontManagerStringSet provides a convenient way to store and access a set of strings.
 */

typedef struct
{
    GPtrArray *strings;
}
FontManagerStringSetPrivate;

G_DEFINE_TYPE_WITH_PRIVATE(FontManagerStringSet, font_manager_string_set, G_TYPE_OBJECT)

enum
{
    PROP_RESERVED,
    PROP_SIZE,
    N_PROPERTIES
};

enum
{
    CHANGED,
    NUM_SIGNALS
};

static guint signals[NUM_SIGNALS];

static void
font_manager_string_set_dispose (GObject *gobject)
{
    g_return_if_fail(gobject != NULL);
    FontManagerStringSet *self = FONT_MANAGER_STRING_SET(gobject);
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    if (priv->strings)
        g_ptr_array_free(priv->strings, TRUE);
    G_OBJECT_CLASS(font_manager_string_set_parent_class)->dispose(gobject);
    return;
}

static void
font_manager_string_set_get_property (GObject *gobject,
                                      guint property_id,
                                      GValue *value,
                                      GParamSpec *pspec)
{
    g_return_if_fail(gobject != NULL);
    FontManagerStringSet *self = FONT_MANAGER_STRING_SET(gobject);

    switch (property_id) {
        case PROP_SIZE:
            g_value_set_uint(value, font_manager_string_set_size(self));
            break;
        default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID(gobject, property_id, pspec);
            break;
    }

    return;
}

static void
font_manager_string_set_class_init (FontManagerStringSetClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS(klass);
    object_class->dispose = font_manager_string_set_dispose;
    object_class->get_property = font_manager_string_set_get_property;

    /**
     * FontManagerStringSet:size
     *
     * Number of strings contained in this set
     */
    g_object_class_install_property(object_class,
                                    PROP_SIZE,
                                    g_param_spec_uint("size",
                                                      NULL,
                                                      "Number of entries",
                                                      0, G_MAXUINT, 0,
                                                      G_PARAM_READABLE | G_PARAM_STATIC_STRINGS));

    /**
     * FontManagerStringSet:changed:
     *
     * Emitted whenever the number of strings in set changes
     */
    signals[CHANGED] = g_signal_new(g_intern_static_string("changed"),
                                    G_TYPE_FROM_CLASS(object_class),
                                    G_SIGNAL_RUN_LAST,
                                    G_STRUCT_OFFSET(FontManagerStringSetClass, changed),
                                    NULL, NULL, NULL,
                                    G_TYPE_NONE, 0);

    return;
}

static void
font_manager_string_set_init (FontManagerStringSet *self)
{
    g_return_if_fail(self != NULL);
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    priv->strings = g_ptr_array_new_with_free_func((GDestroyNotify) g_free);
    return;
}

/**
 * font_manager_string_set_add:
 * @self:   #FontManagerStringSet
 * @str:    string to add to #FontManagerStringSet
 */
void
font_manager_string_set_add (FontManagerStringSet *self, const gchar *str)
{
    g_return_if_fail(self != NULL);
    g_return_if_fail(str != NULL);
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    if (!font_manager_string_set_contains(self, str))
        g_ptr_array_add(priv->strings, g_strdup(str));
    g_signal_emit(self, signals[CHANGED], 0);
    return;
}

/**
 * font_manager_string_set_add_all:
 * @self:                   #FontManagerStringSet
 * @add: (transfer none):   #FontManagerStringSet to add to @self
 */
void
font_manager_string_set_add_all (FontManagerStringSet *self, FontManagerStringSet *add)
{
    g_return_if_fail(self != NULL);
    g_object_freeze_notify(G_OBJECT(self));
    guint n_strings = font_manager_string_set_size(add);
    for (guint i = 0; i < n_strings; i++)
        font_manager_string_set_add(self, font_manager_string_set_get(add, i));
    g_object_thaw_notify(G_OBJECT(self));
    return;
}

/**
 * font_manager_string_set_contains:
 * @self:   #FontManagerStringSet
 * @str:    string to look for in #FontManagerStringSet
 *
 * Returns: %TRUE if @self contains str
 */
gboolean
font_manager_string_set_contains (FontManagerStringSet *self, const gchar *str)
{
    if (!self || !str || font_manager_string_set_size(self) < 1)
        return FALSE;
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    return g_ptr_array_find_with_equal_func(priv->strings, str, (GEqualFunc) g_str_equal, NULL);
}

/**
 * font_manager_string_set_contains_all:
 * @self:                       #FontManagerStringSet
 * @contents: (transfer none):  #FontManagerStringSet to check against
 *
 * Returns: %TRUE if all strings in @contents are contained in @self
 */
gboolean
font_manager_string_set_contains_all (FontManagerStringSet *self, FontManagerStringSet *contents)
{
    g_return_val_if_fail(self != NULL, FALSE);
    guint n_strings = font_manager_string_set_size(contents);
    for (guint i = 0; i < n_strings; i++)
        if (!font_manager_string_set_contains(self, font_manager_string_set_get(contents, i)))
            return FALSE;
    return TRUE;
}

/**
 * font_manager_string_set_remove:
 * @self:   #FontManagerStringSet
 * @str:    string to remove from #FontManagerStringSet
 */
void
font_manager_string_set_remove (FontManagerStringSet *self, const gchar *str)
{
    g_return_if_fail(self != NULL);
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    guint index;
    if (g_ptr_array_find_with_equal_func(priv->strings, str, (GEqualFunc) g_str_equal, &index))
        g_ptr_array_remove_index(priv->strings, index);
    g_signal_emit(self, signals[CHANGED], 0);
    return;
}

/**
 * font_manager_string_set_remove_all:
 * @self:                       #FontManagerStringSet
 * @remove: (transfer none):    #FontManagerStringSet containing strings to remove
 */
void
font_manager_string_set_remove_all (FontManagerStringSet *self, FontManagerStringSet *remove)
{
    g_return_if_fail(self != NULL);
    g_object_freeze_notify(G_OBJECT(self));
    guint n_strings = font_manager_string_set_size(remove);
    for (guint i = 0; i < n_strings; i++)
        font_manager_string_set_remove(self, font_manager_string_set_get(remove, i));
    g_object_thaw_notify(G_OBJECT(self));
    return;
}

/**
 * font_manager_string_set_retain_all:
 * @self:                       #FontManagerStringSet
 * @retain: (transfer none):    #FontManagerStringSet
 *
 * Remove any elements not contained in @retain
 */
void
font_manager_string_set_retain_all (FontManagerStringSet *self, FontManagerStringSet *retain)
{
    g_return_if_fail(self != NULL);
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    GPtrArray *tmp = g_ptr_array_new_with_free_func((GDestroyNotify) g_free);
    guint n_strings = font_manager_string_set_size(retain);
    for (guint i = 0; i < n_strings; i++) {
        guint index;
        const gchar *entry = font_manager_string_set_get(retain, i);
        if (g_ptr_array_find_with_equal_func(priv->strings, entry, (GEqualFunc) g_str_equal, &index))
            g_ptr_array_add(tmp, g_ptr_array_steal_index_fast(priv->strings, index));
    }
    g_ptr_array_free(priv->strings, TRUE);
    priv->strings = tmp;
    g_signal_emit(self, signals[CHANGED], 0);
    return;
}

/**
 * font_manager_string_set_size:
 * @self:   #FontManagerStringSet
 *
 * Returns: Returns the number of strings contained in @self
 */
guint
font_manager_string_set_size (FontManagerStringSet *self)
{
    g_return_val_if_fail(self != NULL, 0);
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    return priv->strings->len;
}

/**
 * font_manager_string_set_list:
 * @self:   #FontManagerStringSet
 *
 * Returns: (element-type utf8) (transfer full): A #GList containing
 * the contents of #FontManagerStringSet.
 * Use #g_list_free_full(list, #g_free) when done using the list.
 */
GList *
font_manager_string_set_list (FontManagerStringSet *self)
{
    g_return_val_if_fail(self != NULL, NULL);
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    GList *result = NULL;
    for (guint i = 0; i < priv->strings->len; i++)
        result = g_list_prepend(result, g_strdup(g_ptr_array_index(priv->strings, i)));
    result = g_list_reverse(result);
    return result;
}

/**
 * font_manager_string_set_foreach:
 * @self:                   #FontManagerStringSet
 * @func: (scope call):     #GFunc to call for each string in the set
 * @user_data:              user data to pass to the function
 *
 * Calls a function for each string of a #FontManagerStringSet.
 * @func must not add elements to or remove elements from the #FontManagerStringSet.
 */
void
font_manager_string_set_foreach(FontManagerStringSet *self, GFunc func, gpointer user_data)
{
    g_return_if_fail(self != NULL);
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    g_ptr_array_foreach(priv->strings, func, user_data);
    return;
}

/**
 * font_manager_string_set_clear:
 * @self:   #FontManagerStringSet
 *
 * Clear all strings from @self
 */
void
font_manager_string_set_clear (FontManagerStringSet *self)
{
    g_return_if_fail(self != NULL);
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    g_ptr_array_remove_range(priv->strings, 0, priv->strings->len);
    g_signal_emit(self, signals[CHANGED], 0);
    return;
}

gint
compare_func (gconstpointer a, gconstpointer b)
{
    g_return_val_if_fail((a != NULL && b != NULL), 0);
    g_autofree gchar *s1 = g_utf8_collate_key_for_filename((gchar *) a, -1);
    g_autofree gchar *s2 = g_utf8_collate_key_for_filename((gchar *) b, -1);
    return g_strcmp0(s1, s2);
}

/**
 * font_manager_string_set_sort:
 * @self:                       #FontManagerStringSet
 *
 * Sorts the set, using @compare_func
 */
void
font_manager_string_set_sort(FontManagerStringSet *self)
{
    g_return_if_fail(self != NULL);
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    g_ptr_array_sort_values(priv->strings, compare_func);
    return;
}

/**
 * font_manager_string_set_get:
 * @self:   a #FontManagerStringSet
 * @index:  index of entry to retrieve
 *
 * Returns: (transfer none) (nullable): A string which is owned by #FontManagerStringSet
 * and should not be modified or freed. %NULL on error or if index could not be retrieved.
 */
const gchar *
font_manager_string_set_get (FontManagerStringSet *self, guint index)
{
    g_return_val_if_fail(self != NULL, NULL);
    FontManagerStringSetPrivate *priv = font_manager_string_set_get_instance_private(self);
    g_return_val_if_fail(index >= 0 && index < priv->strings->len, NULL);
    return g_ptr_array_index(priv->strings, index);
}

static void
add_string_to_array (gchar *str, GStrvBuilder *strv)
{
    g_strv_builder_add(strv, str);
    return;
}

/**
 * font_manager_string_set_to_strv:
 * @self:   a #FontManagerStringSet
 *
 * Returns: (array zero-terminated=1) (element-type utf8) (transfer full):
 * The returned value should be freed with #g_strfreev() when no longer needed.
 */
GStrv
font_manager_string_set_to_strv (FontManagerStringSet *self)
{
    g_autoptr(GStrvBuilder) strv = g_strv_builder_new();
    font_manager_string_set_foreach(self, (GFunc) add_string_to_array, strv);
    return g_strv_builder_end(strv);
}

/**
 * font_manager_string_set_new:
 *
 * Returns: (transfer full): A newly-created #FontManagerStringSet.
 * Free the returned object using #g_object_unref().
 **/
FontManagerStringSet *
font_manager_string_set_new (void)
{
    return g_object_new(FONT_MANAGER_TYPE_STRING_SET, NULL);
}

/**
 * font_manager_string_set_new_from_strv:
 * @strv: (array zero-terminated=1) (element-type utf8) (not nullable) (transfer none) :
 * %NULL terminated array of strings to include in the returned set
 *
 * Returns: (transfer full): A newly-created #FontManagerStringSet.
 * Free the returned object using #g_object_unref().
 **/
FontManagerStringSet *
font_manager_string_set_new_from_strv (GStrv strv)
{
    FontManagerStringSet *set = font_manager_string_set_new();
    for (int i = 0; strv[i] != NULL; i++)
        font_manager_string_set_add(set, strv[i]);
    return set;
}


