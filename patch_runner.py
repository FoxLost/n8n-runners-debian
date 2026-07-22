#!/usr/bin/env python3
import os
import sys

def patch_task_executor(filepath):
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

class _N8nNodeHelper:
    def __init__(self, name="Code", node_id=""):
        self.name = name
        self.id = node_id
    def __getattr__(self, attr):
        return None
    def __getitem__(self, key):
        if hasattr(self, key):
            return getattr(self, key)
        return None
    def get(self, key, default=None):
        if hasattr(self, key):
            return getattr(self, key)
        return default
    def __repr__(self):
        return f"<N8nNode {self.name}>"

class _N8nWorkflowHelper:
    def __init__(self, name="Workflow", workflow_id="", active=True):
        self.name = name
        self.id = workflow_id
        self.active = active
    def __getattr__(self, attr):
        return None
    def __getitem__(self, key):
        if hasattr(self, key):
            return getattr(self, key)
        return None
    def get(self, key, default=None):
        if hasattr(self, key):
            return getattr(self, key)
        return default
    def __repr__(self):
        return f"<N8nWorkflow {self.name}>"

def _normalize_n8n_user_result(result, fallback_items):
    try:
        if result is None:
            return fallback_items
        if hasattr(result, "to_dict") and callable(getattr(result, "to_dict")):
            try:
                records = result.to_dict(orient="records")
                return [{"json": rec} for rec in records]
            except Exception:
                pass
        if hasattr(result, "all") and callable(getattr(result, "all")):
            try:
                res_all = result.all()
                if res_all is not None:
                    return res_all
            except Exception:
                pass
        if isinstance(result, dict):
            if "json" in result:
                return [result]
            return [{"json": result}]
        if isinstance(result, (list, tuple)):
            normalized = []
            for item in result:
                if isinstance(item, dict):
                    if "json" in item:
                        normalized.append(item)
                    else:
                        normalized.append({"json": item})
                else:
                    normalized.append({"json": {"value": str(item)}})
            return normalized
        return [{"json": {"result": result}}]
    except Exception:
        return fallback_items
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
            _node_helper = _N8nNodeHelper()
            _workflow_helper = _N8nWorkflowHelper()
            _first_item = items[0] if items and isinstance(items[0], dict) else {}
            _first_json = _first_item.get("json", {}) if isinstance(_first_item, dict) else {}

            sys.stdout.write("[PythonRunner:ScriptStart] Mode: All Items | Incoming items: %d\\n" % len(items))
            sys.stdout.flush()

            globals = {
                "__builtins__": TaskExecutor._filter_builtins(security_config),
                "_items": items,
                "items": items,
                "_input": _input_helper,
                "_node": _node_helper,
                "_workflow": _workflow_helper,
                "_json": _first_json,
                "_item": _first_item,
                "_query": query,
                "print": TaskExecutor._create_custom_print(print_args),
                EXECUTOR_SAFE_FORMAT_KEY: _safe_format,
            }'''

    old_all_result = '''            result = cast(Items, globals[EXECUTOR_USER_OUTPUT_KEY])'''
    new_all_result = '''            raw_user_res = globals.get(EXECUTOR_USER_OUTPUT_KEY)
            result = _normalize_n8n_user_result(raw_user_res, items)
            sys.stdout.write("[PythonRunner:ScriptSuccess] Execution finished | Returned items: %d\\n" % len(result))
            sys.stdout.flush()'''

    old_per = '''                globals = {
                    "__builtins__": filtered_builtins,
                    "_item": item,
                    "print": custom_print,
                    EXECUTOR_SAFE_FORMAT_KEY: _safe_format,
                }'''

    new_per = '''                _input_helper = _N8nInputHelper(items, item)
                _node_helper = _N8nNodeHelper()
                _workflow_helper = _N8nWorkflowHelper()
                _item_json = item.get("json", {}) if isinstance(item, dict) else {}

                sys.stdout.write("[PythonRunner:ScriptStart] Mode: Per Item | Processing item index: %d\\n" % index)
                sys.stdout.flush()

                globals = {
                    "__builtins__": filtered_builtins,
                    "_item": item,
                    "_items": items,
                    "items": items,
                    "_input": _input_helper,
                    "_node": _node_helper,
                    "_workflow": _workflow_helper,
                    "_json": _item_json,
                    "print": custom_print,
                    EXECUTOR_SAFE_FORMAT_KEY: _safe_format,
                }'''

    old_error = '''            TaskExecutor._put_error(
                write_conn.fileno(), e, stderr_capture.getvalue(), print_args
            )'''

    new_error = '''            err_output = stderr_capture.getvalue()
            sys.stderr.write("[PythonRunner:ScriptError] VERBOSE ERROR TRACEBACK:\\n%s\\nStderr: %s\\n" % (traceback.format_exc(), err_output))
            sys.stderr.flush()
            TaskExecutor._put_error(
                write_conn.fileno(), e, err_output, print_args
            )'''

    content = content.replace(old_all, new_all)
    content = content.replace(old_all_result, new_all_result)
    content = content.replace(old_per, new_per)
    content = content.replace(old_error, new_error)

    with open(filepath, "w") as f:
        f.write(content)
    print(f"[patch_runner] Patched {filepath} successfully")

def patch_task_runner(filepath):
    if not os.path.exists(filepath):
        print(f"[patch_runner] File not found: {filepath}")
        return

    with open(filepath, "r") as f:
        content = f.read()

    old_exec_start = '''            task_state.process = process'''
    new_exec_start = '''            self.logger.info(f"[PythonRunner:TaskExecute] Task {task_id} started executing")
            task_state.process = process'''

    old_task_error = '''        except Exception as e:
            self.logger.error(f"Task {task_id} failed", exc_info=True)'''

    new_task_error = '''        except Exception as e:
            self.logger.error(f"[PythonRunner:TaskError] Task {task_id} failed with Exception: {e}", exc_info=True)'''

    content = content.replace(old_exec_start, new_exec_start)
    content = content.replace(old_task_error, new_task_error)

    with open(filepath, "w") as f:
        f.write(content)
    print(f"[patch_runner] Patched {filepath} successfully")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        target_dir = sys.argv[1]
        executor_path = os.path.join(target_dir, "build/lib/src/task_executor.py")
        runner_path = os.path.join(target_dir, "build/lib/src/task_runner.py")
        if not os.path.exists(executor_path):
            executor_path = sys.argv[1]
        patch_task_executor(executor_path)
        if os.path.exists(runner_path):
            patch_task_runner(runner_path)
