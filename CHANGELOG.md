# Changelog

## 0.1.0

- Build the native Half-Life client and server DLLs and the Fabric mod from pinned source revisions on Windows.
- Confirm that the Half-Life process exited before shutting Minecraft down. A Windows permission failure no longer triggers a false exit.
- Fall back to a centered Windows cursor if SDL loses relative mouse capture. Recenter also when the Minecraft inventory consumes mouse motion.
