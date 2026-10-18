# UG Cloud iOS — prototype 0.3.0

Independent SwiftUI prototype inspired by the uploaded UgPhone Office APK. This is not an official UgPhone client and does not claim to implement undocumented/private UgPhone APIs.

## Build IPA with GitHub Actions (no Mac/Xcode project setup required locally)

1. Create a new **private or public GitHub repository** and upload the contents of this folder. The `.github/workflows/build-ipa.yml` file must be at that exact path in the repository.
2. Open **Actions** in the repository. If GitHub asks, enable workflows.
3. Select **Build iOS IPA** → **Run workflow**. A push to `main` or `master` also starts a build.
4. Open the completed workflow run and download the `UgCloudiOS-unsigned-IPA` artifact. Download `UgCloudiOS-build-log` if the build fails.

The workflow uses a GitHub-hosted macOS runner and Apple's Xcode toolchain. It builds an **unsigned IPA**. It does not require Apple signing secrets, but the result is not signed for normal App Store/device installation. On a jailbroken device, installation depends on a compatible signing/install method (for example, a supported TrollStore workflow); do not assume the unsigned artifact is directly installable. For standard installation, configure Apple Developer signing and provisioning.

## Project contents
- `UgCloudiOS.xcodeproj`: Xcode project, iOS deployment target 16.0.
- `UgCloudiOS/UgCloudiOSApp.swift`: SwiftUI interface prototype.
- `UgCloudiOS/UgPhoneProvider.swift`: HTTPS client scaffold; endpoint contract must be configured against documented, authorized APIs before it can connect to UgPhone.
- `.github/workflows/build-ipa.yml`: CI workflow that builds and packages an unsigned IPA, and uploads the build log.

## Integration status

The UI and build pipeline are a starting point. Real UgPhone login, device inventory, remote screen streaming, touch relay, APK upload/install, and cloud instance management are **not implemented**. They require an official API/SDK or documented protocol and account authorization. The workflow must not be interpreted as proof that the service integration works.

Never commit account passwords, API tokens, certificates, or provisioning profiles to the repository. Use GitHub Actions secrets for any future signing credentials and rotate any secret accidentally exposed.
