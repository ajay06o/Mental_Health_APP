Render deploy notes
===================

Quick actions to ensure Render uses Python 3.11 and installs `backend/requirements.txt` correctly.

- Confirm the repo runtime files:
  - `/.runtime.txt` contains `python-3.11.16`.
  - `backend/.runtime.txt` contains `python-3.11.16`.

- Recommended Render settings (Service > Settings > Build & Deploy):
  - Build Root: set to `backend` (so `requirements.txt` is found), OR
  - Build Command: `pip install --only-binary=:all: -r backend/requirements.txt`
  - Start Command (example): `uvicorn app:app --host 0.0.0.0 --port $PORT`
  - Render will pick the Python version from the repository `.runtime.txt` file.

- Trigger a manual deploy after pushing the runtime files.

Alternative if you must keep Python 3.13 on Render:
- Edit `backend/requirements.txt` and bump `scikit-learn` to a 3.13-compatible release (for example `scikit-learn==1.6.1`), commit and redeploy.

If you want, I can open a small PR to change the `scikit-learn` line instead.
