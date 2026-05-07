# Changelog

## [1.7.0](https://github.com/spreadpaper/SpreadPaper/compare/v1.6.0...v1.7.0) (2026-05-07)


### Features

* **model:** persist isAppearanceBased flag on SavedPreset ([cdfd04f](https://github.com/spreadpaper/SpreadPaper/commit/cdfd04f06a991e64ee7d529df7db2ccf1f6ee390))


### Bug Fixes

* **editor:** tighten header and replace Menu-based Type picker ([12b3656](https://github.com/spreadpaper/SpreadPaper/commit/12b365600c1a95e36fc2803d20361d2786d36173))


### Performance Improvements

* **gallery:** render thumbnails off the main actor ([f35b22f](https://github.com/spreadpaper/SpreadPaper/commit/f35b22fe26c60d24db96a0e148a164c9c33906b7))

## [1.6.0](https://github.com/spreadpaper/SpreadPaper/compare/v1.5.2...v1.6.0) (2026-05-07)


### Features

* add CoolDark reusable components — segmented control, slider, text field, tooltip ([b026a99](https://github.com/spreadpaper/SpreadPaper/commit/b026a99d2d0c3ef16c3ffc91101ab8465277a618))
* add CoolDarkTheme with color tokens, button styles, view modifiers ([53ab913](https://github.com/spreadpaper/SpreadPaper/commit/53ab91332001f6d3eb20fe1130538b6eab1d8d10))
* add CreationModal — type picker with Standard / Dynamic / Light-Dark ([4948055](https://github.com/spreadpaper/SpreadPaper/commit/4948055ff057ce728dc0be1abd24ca48b99b0611))
* add dynamic wallpaper save and apply to WallpaperManager ([88df552](https://github.com/spreadpaper/SpreadPaper/commit/88df552894b5c1825ac258d5ea66f1cd6ce36a8c))
* add DynamicEditorView with canvas + timeline integration ([e820cad](https://github.com/spreadpaper/SpreadPaper/commit/e820cad042ef29556cff2a2ed5a365bfc83d0587))
* add DynamicWallpaperGenerator for HEIC dynamic desktop creation ([8d757c4](https://github.com/spreadpaper/SpreadPaper/commit/8d757c47b712ac2fb7e18be4ac614df700d4d62e))
* add EditorView with canvas, right panel, all three wallpaper modes ([5cb06e3](https://github.com/spreadpaper/SpreadPaper/commit/5cb06e3615dee1e2ec91b026019e3ba94453acdd))
* add GalleryCardView — image-forward card with overlay info ([8d3b0ce](https://github.com/spreadpaper/SpreadPaper/commit/8d3b0ce6f20de15bd450aa7ceb998ed24da61437))
* add GalleryView — image-forward grid with filter tabs and empty state ([64f3f7c](https://github.com/spreadpaper/SpreadPaper/commit/64f3f7cf3a82d48c2deeb56810cb9a6761e6d918))
* add navigation model, wizard flag, wallpaper type display ([11dda06](https://github.com/spreadpaper/SpreadPaper/commit/11dda061f3e53fb7b59db73c1d7ed20466efde0a))
* add RangeBarView — AppKit custom draggable range bar with snap-to-10min ([c1138fd](https://github.com/spreadpaper/SpreadPaper/commit/c1138fdb3bb018a7c5cc94a55ddf9fc04cc451f1))
* add ScheduleView — per-row range bars with drag handles and auto-names ([0949580](https://github.com/spreadpaper/SpreadPaper/commit/0949580c3f150b344ae664a458cfbe89324a0476))
* add time editing popover for dynamic wallpaper variants ([403249b](https://github.com/spreadpaper/SpreadPaper/commit/403249ba3fa8b0093895c6809a88ae6897db481e))
* add TimelineView with time scrubber and thumbnail strip ([1425086](https://github.com/spreadpaper/SpreadPaper/commit/142508631fa3b8bfa9ae18ed7d8b1ebda7629a0a))
* add TimeVariant model and extend SavedPreset for dynamic desktops ([b045d86](https://github.com/spreadpaper/SpreadPaper/commit/b045d8691b2ce26017d157c5680615e530f41e7d))
* add WizardView — 2-step welcome flow with display detection ([3aae823](https://github.com/spreadpaper/SpreadPaper/commit/3aae823131f1580488804a8e4c4d14b67c3cdf02))
* context-aware gallery thumbnails ([2425c06](https://github.com/spreadpaper/SpreadPaper/commit/2425c06bd83dbc359c8059896c59fca3555b8e50))
* **editor:** unified sidebar with live type switching and SaveDialog ([6381a05](https://github.com/spreadpaper/SpreadPaper/commit/6381a05185d88f287ebd6e6f1ed2517c0d773031))
* **filenames:** preserve original image names in stored files ([984aded](https://github.com/spreadpaper/SpreadPaper/commit/984adedb8dda33245d3bcba4df08d728b07c3147))
* inline time editor, Light/Dark mode, and appearance-based HEIC ([f8ca5a9](https://github.com/spreadpaper/SpreadPaper/commit/f8ca5a912005b40946b5ade8d6da65fcb45469c2))
* rewire app entry point with Cool Dark navigation ([23a24d1](https://github.com/spreadpaper/SpreadPaper/commit/23a24d1d810ab3f969f540b668338506dcdd14ed))
* split into Preview and Save & Apply buttons ([8854a59](https://github.com/spreadpaper/SpreadPaper/commit/8854a59e0292dbc4a1688cb73265bedfb16d9c83))
* **theme:** add WallpaperTypeToggle and ToastView components ([3104cdb](https://github.com/spreadpaper/SpreadPaper/commit/3104cdb9c96f38f561383e8b372dce96827b8151))
* upgrade file access entitlement to read-write ([7a7d1b0](https://github.com/spreadpaper/SpreadPaper/commit/7a7d1b0dc43ff74c1d1083a9cbd66a0176da4a81))
* wire sidebar and content view for dynamic preset routing ([0b21323](https://github.com/spreadpaper/SpreadPaper/commit/0b21323c0c33c462a0e59e5b8b20107110b8c8de))


### Bug Fixes

* bigger filter buttons with full-row click target ([8114cdd](https://github.com/spreadpaper/SpreadPaper/commit/8114cddffb2507079664b491b3daccde1a5f601b))
* bigger fonts, more padding across all UI components ([1c21f68](https://github.com/spreadpaper/SpreadPaper/commit/1c21f6810c5e566f3bdb60f4a94162bc490a6d29))
* clean up timeline UI, sort thumbnails by time ([d5fb918](https://github.com/spreadpaper/SpreadPaper/commit/d5fb918702c68698627b246907b9b91850e94467))
* clicking empty Dark card opens file picker instead of doing nothing ([47e7960](https://github.com/spreadpaper/SpreadPaper/commit/47e7960c8205f0231c6fd6c07a230ee69f06d3f5))
* consolidate timeline into DynamicEditorView, fix broken layout ([2644cb5](https://github.com/spreadpaper/SpreadPaper/commit/2644cb580296a2b1ad70be643e609a13baa2506a))
* correct dark index wrap-around and add input validation ([6996958](https://github.com/spreadpaper/SpreadPaper/commit/69969587f73e33c08f59a1d3d38b8064135c3e76))
* default times to natural day phases instead of starting at midnight ([c0c0a27](https://github.com/spreadpaper/SpreadPaper/commit/c0c0a27edfa4ca08604b659cae97de730bd76714))
* editor top bar hidden behind traffic lights, add top padding ([a288932](https://github.com/spreadpaper/SpreadPaper/commit/a288932b745bd54f27ae1e1cfb60b8bcc3018261))
* Fit/Flip buttons with icons, canvas edge snapping, drag-to-reorder ([ebb603a](https://github.com/spreadpaper/SpreadPaper/commit/ebb603a046da3bebd794a2051dbb1f3bfe484da2))
* hide static toolbar in dynamic mode, auto-fit on variant switch ([8940aed](https://github.com/spreadpaper/SpreadPaper/commit/8940aedab730c8b471bd5791a02956ef4f3e2dca))
* keep Apply button inside right panel, remove safeAreaInset ([e811fc5](https://github.com/spreadpaper/SpreadPaper/commit/e811fc5aa11913f5f83031329df2a10b25440290))
* load all variant images correctly when reopening preset ([0cafeda](https://github.com/spreadpaper/SpreadPaper/commit/0cafeda239d9d007bcd570d92326165892c4ab1d))
* pass actual previewScale to wallpaper rendering instead of 1.0 ([64ae7f0](https://github.com/spreadpaper/SpreadPaper/commit/64ae7f03ca0ecaadbccab30c5285d69d51f23323))
* per-variant position in wallpaper rendering ([5bb2fb3](https://github.com/spreadpaper/SpreadPaper/commit/5bb2fb3a7ff8c0d4fa3f8f84684ea8393b8da6c8))
* per-variant position state, save/restore on switch ([9bdeb98](https://github.com/spreadpaper/SpreadPaper/commit/9bdeb988315a22da662d5e99c90e53896f512c33))
* register XMP namespace on correct metadata instance ([9655e74](https://github.com/spreadpaper/SpreadPaper/commit/9655e74ca03856efbf3f199273604b4d612d6677))
* remove focus ring from filter buttons ([71ac7af](https://github.com/spreadpaper/SpreadPaper/commit/71ac7af3896251d81e3d128b74cec0445edce4f7))
* select newly added image, don't reset position of existing images ([9fe2790](https://github.com/spreadpaper/SpreadPaper/commit/9fe27906b4a4fc2004641f33e4fc1c44f38bbad1))
* sort light/dark variants correctly on load (light=0, dark=1) ([2f6c145](https://github.com/spreadpaper/SpreadPaper/commit/2f6c1454d022449f0a437024176571035b15cc51))
* update existing preset on Save & Apply instead of creating duplicate ([0da9e34](https://github.com/spreadpaper/SpreadPaper/commit/0da9e34f3b333833572507f41fcab6d1210572f8))
* use focusEffectDisabled instead of focusable(false) ([a1bd26c](https://github.com/spreadpaper/SpreadPaper/commit/a1bd26ca68214cafdaf980e39dbb6b39006bc9a5))
* use opaque bitmap context for wallpaper rendering ([dd79e7c](https://github.com/spreadpaper/SpreadPaper/commit/dd79e7c7a6057690f2905c4cdb85a17037072bcd))
* use openSettings environment action instead of deprecated sendAction ([1ef838a](https://github.com/spreadpaper/SpreadPaper/commit/1ef838a2930293949e051ae385157a27566fcb03))
* wider sidebar, cleaner schedule rows, editable name in modal ([d2c1f75](https://github.com/spreadpaper/SpreadPaper/commit/d2c1f7526cbd5b15b678b6304b80063064b9e8e8))
* wizard allows multiple images, bolder typography ([3449b40](https://github.com/spreadpaper/SpreadPaper/commit/3449b4007913cc233cae8e0224f9026b7ecf3d14))
* **wizard:** swap system icon for PhosphorSwift equivalent ([fd9edfd](https://github.com/spreadpaper/SpreadPaper/commit/fd9edfd5e5a35c4c9e81a0086acd1eef2bb7737f))

## [1.5.2](https://github.com/spreadpaper/SpreadPaper/compare/v1.5.1...v1.5.2) (2026-02-21)


### Bug Fixes

* **docs:** update quarantine removal instructions in README ([632b6e7](https://github.com/spreadpaper/SpreadPaper/commit/632b6e74e5f70e9c3fa2ac6496264b1b533c8025)), closes [#36](https://github.com/spreadpaper/SpreadPaper/issues/36)

## [1.5.1](https://github.com/spreadpaper/SpreadPaper/compare/v1.5.0...v1.5.1) (2026-02-21)


### Bug Fixes

* wrap macOS 26 glassEffect API in compiler check for Xcode 16 CI ([7c0d9ef](https://github.com/spreadpaper/SpreadPaper/commit/7c0d9ef992df83700c8d0d567f4b5352354e251a))

## [1.5.0](https://github.com/spreadpaper/SpreadPaper/compare/v1.4.1...v1.5.0) (2026-02-21)


### Features

* add Liquid Glass UI support for macOS 26 ([c4e3335](https://github.com/spreadpaper/SpreadPaper/commit/c4e3335e643c6eb783b674fd0d1c98d09fe60af9))
* add native toolbar with fit button and stable layout ([89d54a7](https://github.com/spreadpaper/SpreadPaper/commit/89d54a765e474d9e912ce913c4bbfc0672a1dfca))
* clip image to rounded monitor shapes ([de4e7e9](https://github.com/spreadpaper/SpreadPaper/commit/de4e7e9b9676fcd95ad638ec16af6a63ca71f77a))
* improve rendering pipeline ([22951e2](https://github.com/spreadpaper/SpreadPaper/commit/22951e2b21caab846c78e0ff64ae60f8b7f5fb50))


### Bug Fixes

* remove aggressive window customization for native macOS 26 styling ([ccae57d](https://github.com/spreadpaper/SpreadPaper/commit/ccae57dc6460ad6850035f394ff7b5ea383d8854))

## [1.4.1](https://github.com/spreadpaper/SpreadPaper/compare/v1.4.0...v1.4.1) (2025-12-21)


### Bug Fixes

* markdown rendering and focus issues ([#34](https://github.com/spreadpaper/SpreadPaper/issues/34)) ([9e8b3b3](https://github.com/spreadpaper/SpreadPaper/commit/9e8b3b31ded40f92676079060fa6ddd181e801b5))

## [1.4.0](https://github.com/spreadpaper/SpreadPaper/compare/v1.3.0...v1.4.0) (2025-12-21)


### Features

* add macOS Sequoia support ([#32](https://github.com/spreadpaper/SpreadPaper/issues/32)) ([8a8c4ff](https://github.com/spreadpaper/SpreadPaper/commit/8a8c4ff2f63ff1081813ef31edf3a61ed7331f24))

## [1.3.0](https://github.com/spreadpaper/SpreadPaper/compare/v1.2.4...v1.3.0) (2025-12-21)


### Features

* add version check popup on app startup ([#30](https://github.com/spreadpaper/SpreadPaper/issues/30)) ([deec647](https://github.com/spreadpaper/SpreadPaper/commit/deec6471ee2f8f654e248f394f0dfc547f1fc2e6))

## [1.2.4](https://github.com/spreadpaper/SpreadPaper/compare/v1.2.3...v1.2.4) (2025-12-21)


### Bug Fixes

* wallpaper reapplication issue after recent update ([#28](https://github.com/spreadpaper/SpreadPaper/issues/28)) ([f76ddaf](https://github.com/spreadpaper/SpreadPaper/commit/f76ddaf9fd39fb5ccc1aec9b899147bcb1c6eede))

## [1.2.3](https://github.com/spreadpaper/SpreadPaper/compare/v1.2.2...v1.2.3) (2025-12-18)


### Bug Fixes

* persist wallpapers to Application Support instead of temp directory ([#26](https://github.com/spreadpaper/SpreadPaper/issues/26)) ([faba55f](https://github.com/spreadpaper/SpreadPaper/commit/faba55f7a235b7c550f5694a39ccc4c3f10f71e4)), closes [#10](https://github.com/spreadpaper/SpreadPaper/issues/10)

## [1.2.2](https://github.com/spreadpaper/SpreadPaper/compare/v1.2.1...v1.2.2) (2025-12-17)


### Bug Fixes

* parse markdown in changelog for what's new ([#19](https://github.com/spreadpaper/SpreadPaper/issues/19)) ([2931c6c](https://github.com/spreadpaper/SpreadPaper/commit/2931c6c323f914b2147844bd2e0a1938df15aa1f))

## [1.2.1](https://github.com/spreadpaper/SpreadPaper/compare/v1.2.0...v1.2.1) (2025-12-17)


### Bug Fixes

* center image upload area in UI ([#15](https://github.com/spreadpaper/SpreadPaper/issues/15)) ([caaa8e0](https://github.com/spreadpaper/SpreadPaper/commit/caaa8e065745d09c15a50d08237cdfe7c6dd3949))
* migrate site deployment to GitHub Actions ([#17](https://github.com/spreadpaper/SpreadPaper/issues/17)) ([036d6e3](https://github.com/spreadpaper/SpreadPaper/commit/036d6e392c2bf9fd3a31ac45f301ec2ea3a8332f))

## [1.2.0](https://github.com/spreadpaper/SpreadPaper/compare/v1.1.3...v1.2.0) (2025-12-17)


### Features

* sync app version with GitHub releases ([#11](https://github.com/spreadpaper/SpreadPaper/issues/11)) ([b6fbbc7](https://github.com/spreadpaper/SpreadPaper/commit/b6fbbc715bf1abaf8435b11a85924594185a4b9a))

## [1.1.3](https://github.com/rvanbaalen/SpreadPaper/compare/v1.1.2...v1.1.3) (2025-11-22)


### Bug Fixes

* improve build process with archive workflow and dual artifact output ([#8](https://github.com/rvanbaalen/SpreadPaper/issues/8)) ([0422f31](https://github.com/rvanbaalen/SpreadPaper/commit/0422f3194bbdb004aa93ad47ac11a7ae25aa68b1))

## [1.1.2](https://github.com/rvanbaalen/SpreadPaper/compare/v1.1.1...v1.1.2) (2025-11-22)


### Bug Fixes

* punctuation in README ([9d410ec](https://github.com/rvanbaalen/SpreadPaper/commit/9d410ec4d6777f9ecf09e61c7a2a730815bfa61e))

## [1.1.1](https://github.com/rvanbaalen/SpreadPaper/compare/v1.1.0...v1.1.1) (2025-11-22)


### Bug Fixes

* unify release workflow and fix DMG upload permissions ([#5](https://github.com/rvanbaalen/SpreadPaper/issues/5)) ([f472fa8](https://github.com/rvanbaalen/SpreadPaper/commit/f472fa8691191d12cc131fbb43b9825df61d1e7e))

## [1.1.0](https://github.com/rvanbaalen/SpreadPaper/compare/v1.0.1...v1.1.0) (2025-11-22)


### Features

* improve documentation and issue templates ([#3](https://github.com/rvanbaalen/SpreadPaper/issues/3)) ([eb6f7f7](https://github.com/rvanbaalen/SpreadPaper/commit/eb6f7f734e82f28374d77e9ae081c718a6542163))

## [1.0.1](https://github.com/rvanbaalen/SpreadPaper/compare/v1.0.0...v1.0.1) (2025-11-22)


### Bug Fixes

* add release published trigger and manual workflow dispatch ([c5d6935](https://github.com/rvanbaalen/SpreadPaper/commit/c5d6935c42e3af8734877fd9079eb6e7615dc7b5))

## 1.0.0 (2025-11-22)


### Features

* implement wallpaper spreading with multi-monitor support ([d4949c7](https://github.com/rvanbaalen/SpreadPaper/commit/d4949c7bc21ff18b7a3ed6ae7c1c3a7f05cbec99))
* update app entry point structure ([88ba282](https://github.com/rvanbaalen/SpreadPaper/commit/88ba28212ccb9eacca6960384925de6265194497))
