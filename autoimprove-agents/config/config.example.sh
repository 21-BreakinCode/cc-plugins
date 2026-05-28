# autoimprove-agents configuration
# Copy to ~/.claude/autoimprove-agents/config.sh and customize

# Enable NotebookLM integration (requires notebooklm-py)
export AUTOIMPROVE_NOTEBOOKLM_ENABLED=false

# Auto-apply low-risk self-improvement changes (tagging archived features)
export AUTOIMPROVE_AUTO_APPLY_LOW_RISK=true

# Name of the cross-project NotebookLM notebook
export AUTOIMPROVE_CROSS_PROJECT_NOTEBOOK="claude-cross-project-kb"

# Google account email for NotebookLM (required if NotebookLM enabled)
export AUTOIMPROVE_GOOGLE_ACCOUNT=""
