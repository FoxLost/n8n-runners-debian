#!/usr/bin/env python3
import os
import sys

def patch_file(filepath):
    if not os.path.exists(filepath):
        print(f"[patch_runner] File not found: {filepath}")
        return

    with open(filepath, "r") as f:
        content = f.read()

    helper = '''
class _N8nInputHelper:
    def __init__(self, items, item=None):
        self._items = items
        self._current = item if item is not None else (items[0] if items else {})
    def all(self):
        return self._items
    def first(self):
        return self._items[0] if self._items else None
    def last(self):
        return self._items[-1] if self._items else None
    @property
    def item(self):
        return self._current
'''

    if "_N8nInputHelper" not in content:
        content = helper + "\n" + content

    old_all = '''            globals = {
                "__builtins__": TaskExecutor._filter_builtins(security_config),
                "_items": items,
                "_query": query,
                "print": TaskExecutor._create_custom_print(print_args),
                EXECUTOR_SAFE_FORMAT_KEY: _safe_format,
            }'''

    new_all = '''            _input_helper = _N8nInputHelper(items)
            _first_item = items[0] if items and isinstance(items[0], dict) else {}
            _first_json = _first_item.get("json", {}) if isinstance(_first_item, dict) else {}

            globals = {
                "__builtins__": TaskExecutor._filter_builtins(security_config),
                "_items": items,
                "items": items,
                "_input": _input_helper,
                "_json": _first_json,
                "_item": _first_item,
                "_query": query,
                "print": TaskExecutor._create_custom_print(print_args),
                EXECUTOR_SAFE_FORMAT_KEY: _safe_format,
            }'''

    old_per = '''                globals = {
                    "__builtins__": filtered_builtins,
                    "_item": item,
                    "print": custom_print,
                    EXECUTOR_SAFE_FORMAT_KEY: _safe_format,
                }'''

    new_per = '''                _input_helper = _N8nInputHelper(items, item)
                _item_json = item.get("json", {}) if isinstance(item, dict) else {}

                globals = {
                    "__builtins__": filtered_builtins,
                    "_item": item,
                    "_items": items,
                    "items": items,
                    "_input": _input_helper,
                    "_json": _item_json,
                    "print": custom_print,
                    EXECUTOR_SAFE_FORMAT_KEY: _safe_format,
                }'''

    content = content.replace(old_all, new_all)
    content = content.replace(old_per, new_per)

    with open(filepath, "w") as f:
        f.write(content)
    print(f"[patch_runner] Patched {filepath} successfully")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        patch_file(sys.argv[1])
