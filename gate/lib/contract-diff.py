#!/usr/bin/env python3
"""Lists the breaking changes between two versions of an OpenAPI contract.

Usage: contract-diff.py <base.yaml> <head.yaml>      Prints a JSON array of {change, hint}.
Exit code 3 when PyYAML is missing (the caller falls back to a line-based heuristic).

A change is breaking for an existing consumer when it removes or renames something, or when it
makes a request stricter. Additions (a new path, a new optional field, a new schema with its own
required fields) are not breaking.
"""
import json
import sys

try:
    import yaml
except ImportError:
    sys.exit(3)

METHODS = ("get", "put", "post", "delete", "patch", "head", "options")


def load(path):
    with open(path) as f:
        return yaml.safe_load(f) or {}


def resolve(spec, node):
    """Follows a local $ref, once or twice."""
    for _ in range(3):
        if isinstance(node, dict) and "$ref" in node and node["$ref"].startswith("#/"):
            cur = spec
            for part in node["$ref"][2:].split("/"):
                cur = (cur or {}).get(part, {})
            node = cur
        else:
            break
    return node if isinstance(node, dict) else {}


def schema_of(spec, content):
    media = (content or {}).get("application/json", {})
    return resolve(spec, media.get("schema", {}))


def props(spec, schema):
    """Properties of a schema, following $ref and allOf."""
    schema = resolve(spec, schema)
    out = dict(schema.get("properties", {}))
    for part in schema.get("allOf", []):
        out.update(props(spec, part))
    return out


def required(spec, schema):
    schema = resolve(spec, schema)
    req = set(schema.get("required", []) or [])
    for part in schema.get("allOf", []):
        req |= required(spec, part)
    return req


def compare_schema(spec_b, spec_h, sb, sh, where, request, out, depth=0):
    sb, sh = resolve(spec_b, sb), resolve(spec_h, sh)
    if depth > 4 or not sb:
        return
    pb, ph = props(spec_b, sb), props(spec_h, sh)
    for name, pschema in pb.items():
        if name not in ph:
            out.append({"change": f"{where}: property '{name}' was removed or renamed",
                        "hint": f"Keep '{name}' in {where} (add the new name next to it) so existing consumers keep working."})
            continue
        tb, th = resolve(spec_b, pschema).get("type"), resolve(spec_h, ph[name]).get("type")
        if tb and th and tb != th:
            out.append({"change": f"{where}: property '{name}' changed type {tb} -> {th}",
                        "hint": f"Do not change the type of '{name}'; add a new field instead."})
        compare_schema(spec_b, spec_h, pschema, ph[name], f"{where}.{name}", request, out, depth + 1)
    if request:
        for name in required(spec_h, sh) - required(spec_b, sb):
            if name in pb:  # an already-existing field that became mandatory
                out.append({"change": f"{where}: request field '{name}' became required",
                            "hint": f"Keep '{name}' optional: existing callers do not send it."})
    # A brand-new field that is required in a request also breaks existing callers.
    if request:
        for name in required(spec_h, sh):
            if name not in pb and name in ph and sb:
                out.append({"change": f"{where}: new request field '{name}' is required",
                            "hint": f"Make '{name}' optional, existing callers do not send it."})


def diff(base, head):
    out = []
    pb, ph = base.get("paths", {}), head.get("paths", {})
    for path, item in pb.items():
        if path not in ph:
            out.append({"change": f"path {path} was removed or renamed",
                        "hint": f"Keep {path} (add the new path next to it) or version the API."})
            continue
        for method in METHODS:
            if method not in item:
                continue
            op_b, op_h = item[method], ph[path].get(method)
            label = f"{method.upper()} {path}"
            if op_h is None:
                out.append({"change": f"{label} was removed",
                            "hint": f"Keep {label}, or version the API."})
                continue
            # Responses: a removed success status or a removed response property.
            for code, resp in (op_b.get("responses") or {}).items():
                if code not in (op_h.get("responses") or {}):
                    out.append({"change": f"{label}: response {code} was removed",
                                "hint": f"Keep the {code} response of {label}."})
                    continue
                rb = schema_of(base, resolve(base, resp).get("content"))
                rh = schema_of(head, resolve(head, op_h["responses"][code]).get("content"))
                compare_schema(base, head, rb, rh, f"{label} response {code}", False, out)
            # Request body: becoming required, or stricter fields.
            rqb, rqh = resolve(base, op_b.get("requestBody", {})), resolve(head, op_h.get("requestBody", {}))
            if rqb:
                if rqh.get("required") and not rqb.get("required"):
                    out.append({"change": f"{label}: the request body became required",
                                "hint": f"Keep the body of {label} optional."})
                compare_schema(base, head, schema_of(base, rqb.get("content")),
                               schema_of(head, rqh.get("content")), f"{label} request", True, out)
            # Parameters: a new required parameter.
            names_b = {resolve(base, p).get("name") for p in (item.get("parameters", []) + op_b.get("parameters", []))}
            for p in item.get("parameters", []) + op_h.get("parameters", []):
                p = resolve(head, p)
                if p.get("required") and p.get("name") not in names_b:
                    out.append({"change": f"{label}: new required parameter '{p.get('name')}'",
                                "hint": f"Make '{p.get('name')}' optional or give it a default."})
    return out


if __name__ == "__main__":
    print(json.dumps(diff(load(sys.argv[1]), load(sys.argv[2])), indent=2))
