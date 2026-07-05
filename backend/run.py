"""Entry point: python run.py  →  http://localhost:8000"""
from dotenv import load_dotenv

load_dotenv()  # must run before `app.main` (and its imports) read any env vars

import uvicorn  # noqa: E402

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=False)
