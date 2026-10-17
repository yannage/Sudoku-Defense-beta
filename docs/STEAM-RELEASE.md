# Gridfall: Linux / Steam Deck release path

Checked against official documentation on October 17, 2026. This project is a playable prototype with Linux packaging support. It has not been certified, submitted to Steam, or verified on physical Steam Deck hardware.

## What is ready

- A self-contained web game with local assets and no backend requirement.
- An Electron Linux x86-64 wrapper, fullscreen startup, a standard browser gamepad adapter, and a Steam-depot-friendly unpacked output.
- An AppImage target for direct testing and GitHub Actions artifact builds.
- Loopback-only serving, sandboxed web content, restricted navigation, and persistent localStorage backup in `game-storage.json` under Electron's user-data directory.

This is a native Linux application that embeds a browser renderer. It is not a custom C++/Vulkan engine. Packaging the web game avoids a separate browser requirement; it does not guarantee the performance or resource usage of a purpose-built native engine. Steamworks SDK features such as achievements, Steam Cloud, Steam Input API glyphs, and overlay integration are not implemented.

## Build and test on a Deck

1. On Linux with Node 22+, run `npm ci`, `npm test`, and `npm run package:linux`.
2. Copy all of `release/linux-unpacked/` to the Deck without losing file permissions. Alternatively download the CI depot tarball, then extract it on the Deck.
3. In Desktop Mode, add the `gridfall` executable to Steam as a non-Steam game. Do not force Proton for this Linux build. Test from Gaming Mode with Steam Input's standard Gamepad template.
4. Verify cold start with Wi-Fi disabled, gameplay, audio, menus, buying towers, restart, fullscreen, suspend/resume, save/settings retention, and recovery after closing the app.
5. Profile several complete runs at 1280×800 under the default settings. Check controller glyphs, every menu without a mouse, and legibility on the actual screen. Browser and CI tests cannot substitute for this.

Valve's requirements include access to all content through the default controller configuration, correct controller prompts, suitable text-entry handling, a playable default frame rate, and legible text. The current documentation calls for 30 fps at 800p on Deck; it recommends 1280×800 and 12-pixel text, with 9 pixels as the stated absolute character-height minimum. [Compatibility checklist](https://partner.steamgames.com/doc/steamhardware/compat)

## Submit when the game is ready

1. Complete Steamworks onboarding, legal agreements, identity, banking, and tax details through the owner's account. Steam Direct currently charges **$100 USD per app**, recoupable after the product earns $1,000 in adjusted gross revenue. [Onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding) · [Steam Direct fee](https://partner.steamgames.com/doc/gettingstarted/appfee)
2. Create the app, a Linux depot, and a Linux launch option whose executable path is `gridfall`. Add that depot to the development package. Upload the **contents** of `release/linux-unpacked/` with SteamPipe. Test a private branch first. The AppImage is convenient for sideloading; use the unpacked content for the depot. [Upload and depot configuration](https://partner.steamgames.com/doc/sdk/uploading)
3. Finish the store page, capsule/library artwork, screenshots, trailer, pricing, system requirements, content survey, third-party notices, and the actual feature set promised on the store page. Check the current survey's disclosure questions accurately. Submit the store presence before the build review; both must be approved. [Release process](https://partner.steamgames.com/doc/store/releasing)
4. Plan around the current onboarding waiting period shown in Steamworks and at least **two weeks** with a public Coming Soon page. Valve's October 2026 onboarding documentation currently says a **21-day** app-fee waiting period for the first few releases; check your app's live dashboard before setting a date. [Onboarding timing](https://partner.steamgames.com/doc/gettingstarted/onboarding)
5. Finish the physical Deck pass and address failures. Request Valve's hardware compatibility review if that control is available on the app's Steamworks page. Only Valve's completed review grants the public compatibility rating. [Review process](https://partner.steamgames.com/doc/steamhardware/compat)

No Steamworks credentials, SDK binaries, app IDs, store submission, app fee payment, or public Steam release are part of this repository.
