"""One shared slowapi Limiter — imported by both main.py (to register it +
its exception handler on the app) and any router that wants to decorate a
route with `@limiter.limit(...)`.
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
