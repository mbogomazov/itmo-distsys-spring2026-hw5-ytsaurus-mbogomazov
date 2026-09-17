"""Launcher for `yt_local start` that also works on an EXISTING cluster working directory.

Why: the image's `yt_local start` reuses /tmp/locasaurus (master state, tables), so data survives a
container restart. But the optional components (query-tracker, yql-agent) were written for a fresh
cluster only: on every start they call `client.create("user", ...)`, create ACL namespaces, etc.
On the second start master already has these objects and the start fails with
`User "query_tracker" already exists`.

Fix: wrap the YT clients created by the environment so that `create(...)` / `add_member(...)` ignore
"already exists" / "already present" errors (the object is already there - exactly what we wanted), then run the original
/usr/local/bin/yt_local unchanged. Used by deploy/start.sh as the container entrypoint.

Runs inside the container with the image's Python 3.8.
"""
import logging
import runpy

from yt.environment import yt_env

logger = logging.getLogger("YtLocal")


# Client methods that (re)create cluster objects on every start, and master's error texts for "already done"
IDEMPOTENT_METHODS = ("create", "add_member")
ALREADY_DONE_MARKERS = ("already exists", "already present")


def _make_idempotent(client):
    for method_name in IDEMPOTENT_METHODS:
        original = getattr(client, method_name)

        def wrapper(*args, _original=original, _name=method_name, **kwargs):
            try:
                return _original(*args, **kwargs)
            except Exception as error:  # YtError / YtResponseError from master
                if not any(marker in str(error) for marker in ALREADY_DONE_MARKERS):
                    raise
                logger.info("Restart: %s%s already done, skipping", _name, args[:1])
                return None

        setattr(client, method_name, wrapper)
    return client


def _patch_client_factory(method_name):
    original = getattr(yt_env.YTInstance, method_name)

    def factory(self, *args, **kwargs):
        return _make_idempotent(original(self, *args, **kwargs))

    setattr(yt_env.YTInstance, method_name, factory)


_patch_client_factory("create_client")
_patch_client_factory("create_native_client")

runpy.run_path("/usr/local/bin/yt_local", run_name="__main__")
