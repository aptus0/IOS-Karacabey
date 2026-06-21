import Foundation
import GoogleMobileAds

@MainActor
final class AdMobService: NSObject {
    static let shared = AdMobService()

    private enum Constants {
        static let productionInterstitialAdUnitID = "ca-app-pub-3321006469806168/9841027691"
        static let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
        static let minimumEligibleTransitions = 4
        static let minimumPresentationInterval: TimeInterval = 4 * 60
        static let maximumCachedAdAge: TimeInterval = 55 * 60
    }

    private var hasStarted = false
    private var interstitialAd: InterstitialAd?
    private var isLoadingInterstitial = false
    private var interstitialLoadDate: Date?
    private var lastPresentationDate: Date?
    private var eligibleTransitionCount = 0
    private var pendingTransitionAction: (() -> Void)?

    private var interstitialAdUnitID: String {
        #if DEBUG
        return Constants.testInterstitialAdUnitID
        #else
        return Constants.productionInterstitialAdUnitID
        #endif
    }

    private var adUnitMode: String {
        #if DEBUG
        return "test"
        #else
        return "production"
        #endif
    }

    private var isCachedInterstitialExpired: Bool {
        guard let interstitialLoadDate else { return true }
        return Date().timeIntervalSince(interstitialLoadDate) > Constants.maximumCachedAdAge
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        // TODO: Gate startup through Google UMP consent before enabling personalized ads for EEA/UK users.
        MobileAds.shared.start()

        Task {
            await loadInterstitialIfNeeded(force: true)
        }
    }

    func performAfterOptionalInterstitial(_ action: @escaping () -> Void) {
        eligibleTransitionCount += 1

        guard shouldPresentInterstitialNow, let ad = interstitialAd, !isCachedInterstitialExpired else {
            action()
            Task {
                await loadInterstitialIfNeeded(force: isCachedInterstitialExpired)
            }
            return
        }

        eligibleTransitionCount = 0
        lastPresentationDate = Date()
        pendingTransitionAction = action
        interstitialAd = nil
        interstitialLoadDate = nil
        ad.fullScreenContentDelegate = self
        ad.present(from: nil)
    }

    private var shouldPresentInterstitialNow: Bool {
        guard eligibleTransitionCount >= Constants.minimumEligibleTransitions else { return false }
        guard let lastPresentationDate else { return true }
        return Date().timeIntervalSince(lastPresentationDate) >= Constants.minimumPresentationInterval
    }

    private func loadInterstitialIfNeeded(force: Bool = false) async {
        guard hasStarted else { return }
        guard force || interstitialAd == nil || isCachedInterstitialExpired else { return }
        guard !isLoadingInterstitial else { return }

        isLoadingInterstitial = true
        defer { isLoadingInterstitial = false }

        do {
            let ad = try await InterstitialAd.load(
                with: interstitialAdUnitID,
                request: Request()
            )
            ad.fullScreenContentDelegate = self
            interstitialAd = ad
            interstitialLoadDate = Date()
        } catch {
            interstitialAd = nil
            interstitialLoadDate = nil
            CrashReporter.record(
                error,
                context: "admob_interstitial_load_failed",
                metadata: ["ad_unit_mode": adUnitMode]
            )
            #if DEBUG
            print("[AdMob] Interstitial yüklenemedi (\(adUnitMode)): \(error.localizedDescription)")
            #endif
        }
    }

    private func completePendingTransition() {
        let action = pendingTransitionAction
        pendingTransitionAction = nil
        action?()
    }
}

extension AdMobService: FullScreenContentDelegate {
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[AdMob] Interstitial impression kaydedildi.")
        #endif
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        #if DEBUG
        print("[AdMob] Interstitial tıklaması kaydedildi.")
        #endif
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        CrashReporter.record(
            error,
            context: "admob_interstitial_present_failed",
            metadata: ["ad_unit_mode": adUnitMode]
        )
        completePendingTransition()
        Task {
            await loadInterstitialIfNeeded(force: true)
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        completePendingTransition()
        Task {
            await loadInterstitialIfNeeded(force: true)
        }
    }
}
