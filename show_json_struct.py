"""Print the structure of a JSON file — keys, array shapes, leaf types — as a
compact schema overview.

Usage: python show_json_struct.py <file.json>
"""
import json, sys

def schema(v, indent=0):
    pad = "  " * indent
    if isinstance(v, dict):
        if not v:
            return "{}"
        lines = ["{"]
        for k, x in v.items():
            lines.append(f"{pad}  {k!r}: {schema(x, indent + 1)},")
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(v, list):
        if not v:
            return "Array[]"
        # unique element shapes, order preserved
        shapes = []
        for x in v:
            s = schema(x, indent + 1)
            if s not in shapes:
                shapes.append(s)
        inner = " | ".join(shapes)
        return f"Array[{inner}, ..]" if len(v) > 1 else f"Array[{inner}]"
    if v is None:
        return "null"
    return type(v).__name__  # str, int, float, bool

if __name__ == "__main__":
    with open(sys.argv[1]) as f:
        print(schema(json.load(f)))
