# Minecraft X Half-Life — Windows build fixes

Builds the [Minecraft X Half-Life](https://github.com/SawyerTheNerd/Minecraft-X-HalfLife) crossover from its original sources and applies two fixes for Windows. Half-Life renders its own maps with Minecraft's blocks and mobs, and displays Minecraft's hotbar and inventory. Minecraft Java runs locally alongside it and handles Minecraft gameplay.

## Requirements

- Windows 10 or 11, 64-bit, with PowerShell 7 and Git for Windows.
- Steam Half-Life, 25th Anniversary branch, using the OpenGL renderer.
- Minecraft Java **26.3**, Fabric Loader **0.19.5** or later, and [Fabric API **0.161.0+26.3**](https://modrinth.com/mod/fabric-api/versions?g=26.3). Use your own Minecraft installation and a separate game directory for the crossover.
- JDK 25, Visual Studio 2022 Build Tools with MSVC v143 x86/x64, and a Windows SDK. The first build downloads source archives and Gradle dependencies.

## Build

Open PowerShell 7 in the package directory. Set `JAVA_HOME` to your JDK 25 folder or pass `-JavaHome` with its path. Run:

```powershell
.\Build.ps1
```

If Visual Studio Build Tools is installed in a location that `vswhere` cannot find, pass `-MSBuild` with the full path to `MSBuild.exe`. The build runs the Fabric tests and puts the installable files under `.build/dist`. For a clean rebuild in another folder, pass `-WorkDirectory` with a new path.

## Install and play

1. Close both games. Copy `.build/dist/mchl` into the Steam Half-Life directory next to `hl.exe`. If you already have an `mchl` directory, back it up before updating its files.
2. Put `.build/dist/minecraft/mods/skycraft-mchl-0.1.2.jar` and Fabric API in the `mods` directory of your separate Minecraft 26.3 profile. Keep one SkyCraft JAR in that profile. The build uses Minecraft's own rendered player and skips the upstream project's optional replacement GoldSrc weapon models.
3. Start the Half-Life mod. Substitute the full path to your own `steam.exe` in this example:

   ```powershell
   & 'C:\Program Files (x86)\Steam\steam.exe' -applaunch 70 -game mchl -insecure -gl -windowed -novid -condebug +map t0a0
   ```

4. With Half-Life open, start the Fabric profile from your launcher. Minecraft hides its window after connecting. Return to Half-Life and press **E** for the inventory. **1–9** select a hotbar slot, **G** activates Half-Life doors and buttons, and **O** opens Minecraft's pause menu.

This build is for local single-player. Live verification covered connecting through Legacy Launcher, entering the SkyCraft world, and sending the Hazard Course collision mesh and Minecraft texture atlas. Every Minecraft feature and Half-Life map still needs compatibility testing. The mouse fix was built and loaded by Half-Life. Its effect on a full turn still needs a play test.

## Troubleshooting and removal

- Half-Life writes bridge messages beginning with `MCLink:` in `qconsole.log` next to `hl.exe`. Minecraft writes its log to `logs/latest.log` in its profile directory.
- If the Minecraft window disappears after `MCLink: Minecraft linked`, return to Half-Life. This is how the bridge presents Minecraft's picture through GoldSrc.
- To remove the mod, close both games, move `mchl` out of the Steam Half-Life directory, and remove the SkyCraft JAR from the Minecraft profile. Back up the mod's saves first if you want to keep them.

## Credits and distribution

- [SawyerTheNerd](https://github.com/SawyerTheNerd/Minecraft-X-HalfLife) made the Half-Life port of [chasmlol's SkyCraft](https://github.com/chasmlol/SkyCraft). [Valve's Half-Life SDK](https://github.com/ValveSoftware/halflife) provides the GoldSrc game code.
- The Windows fixes and build script were prepared with OpenAI Codex using [Universal Modder](https://github.com/rehan-remade/universal-modder).
- This companion package contains the local changes and build instructions. It retrieves the pinned port, SkyCraft and Valve SDK from their original repositories. It contains no upstream source tree, compiled mod, game assets, saves or launcher data. Upstream terms apply to those downloads. The original port does not declare a standalone redistribution license. Check with its author before rehosting its source or publishing binaries built from it.
