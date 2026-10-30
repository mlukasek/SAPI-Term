"""Minimal client of the SAPIemu MCP server (JSON-RPC over HTTP POST).

Taken from SAPI-Bad-Apple (tools/emu/sapimcp.py), only the default port differs.

URL: environment variable SAPIEMU_MCP, default http://127.0.0.1:8595/mcp (sapiemu-cli --mcp --mcp-port 8595;
the GUI listens on 8580). Command line: python sapimcp.py TOOL '{"arg": value}'
"""
import json, os, sys, urllib.request

URL = os.environ.get('SAPIEMU_MCP', 'http://127.0.0.1:8595/mcp')
_id = [0]


def _post(method, params=None):
    _id[0] += 1
    req = {'jsonrpc': '2.0', 'id': _id[0], 'method': method}
    if params is not None:
        req['params'] = params
    r = urllib.request.Request(URL, json.dumps(req).encode(), {'Content-Type': 'application/json'})
    resp = json.loads(urllib.request.urlopen(r, timeout=600).read())
    if 'error' in resp:
        raise RuntimeError(resp['error'])
    return resp['result']


def call(_tool, **args):
    """Call a tool. Returns the structured result, the parsed JSON text, the text, or the list of contents
    (images are dicts with base64 'data')."""
    res = _post('tools/call', {'name': _tool, 'arguments': args})
    out = [c['text'] if c.get('type') == 'text' else c for c in res.get('content', [])]
    if res.get('isError'):
        raise RuntimeError('%s: %s' % (_tool, out))
    if res.get('structuredContent') is not None:
        return res['structuredContent']
    if len(out) == 1 and isinstance(out[0], str):
        if out[0][:1] in '{["':
            try:
                return json.loads(out[0])
            except ValueError:
                pass
        return out[0]
    return out


def tools():
    return _post('tools/list')['tools']


if __name__ == '__main__':
    args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    print(json.dumps(call(sys.argv[1], **args), indent=1, ensure_ascii=False)[:5000])
