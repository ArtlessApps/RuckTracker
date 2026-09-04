package com.artless.rucktracker.domain

import com.artless.rucktracker.billing.BillingManager
import com.artless.rucktracker.data.model.PaywallContext
import com.artless.rucktracker.data.model.PremiumFeature
import com.artless.rucktracker.data.remote.AuthRepository
import com.artless.rucktracker.data.remote.ClubRepository
import com.artless.rucktracker.data.remote.SubscriptionRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

enum class PremiumSource { SUBSCRIPTION, AMBASSADOR, NONE }

@Singleton
class PremiumManager @Inject constructor(
    private val authRepository: AuthRepository,
    private val subscriptionRepository: SubscriptionRepository,
    private val clubRepository: ClubRepository,
    private val billingManager: BillingManager
) {
    private val _isPremiumUser = MutableStateFlow(false)
    val isPremiumUser: StateFlow<Boolean> = _isPremiumUser.asStateFlow()

    private val _isAmbassador = MutableStateFlow(false)
    val isAmbassador: StateFlow<Boolean> = _isAmbassador.asStateFlow()

    private val _premiumSource = MutableStateFlow(PremiumSource.NONE)
    val premiumSource: StateFlow<PremiumSource> = _premiumSource.asStateFlow()

    private val _showPaywall = MutableStateFlow(false)
    val showPaywall: StateFlow<Boolean> = _showPaywall.asStateFlow()

    private val _paywallContext = MutableStateFlow(PaywallContext.FEATURE_UPSELL)
    val paywallContext: StateFlow<PaywallContext> = _paywallContext.asStateFlow()

    private var hasActiveSubscription = false

    suspend fun refreshPremiumStatus() {
        val userId = authRepository.currentUserId
        if (userId != null) {
            val sub = subscriptionRepository.getActiveSubscription(userId)
            hasActiveSubscription = sub != null
            checkAmbassadorStatus(userId)
        } else {
            hasActiveSubscription = billingManager.isSubscribed.value
            _isAmbassador.value = false
        }
        updatePremiumState()
    }

    private suspend fun checkAmbassadorStatus(userId: String) {
        val clubs = clubRepository.loadMyClubs(userId)
        val founderClub = clubs.find { it.createdBy == userId && it.memberCount >= 5 }
        _isAmbassador.value = founderClub != null
        if (founderClub != null && !hasActiveSubscription) {
            subscriptionRepository.recordAmbassadorSubscription(userId)
            hasActiveSubscription = true
        }
    }

    private fun updatePremiumState() {
        val isPremium = if (authRepository.isAuthenticated) {
            hasActiveSubscription || _isAmbassador.value
        } else {
            billingManager.isSubscribed.value
        }
        _isPremiumUser.value = isPremium
        _premiumSource.value = when {
            hasActiveSubscription || billingManager.isSubscribed.value -> PremiumSource.SUBSCRIPTION
            _isAmbassador.value -> PremiumSource.AMBASSADOR
            else -> PremiumSource.NONE
        }
    }

    fun canAccess(feature: PremiumFeature): Boolean =
        !feature.requiresPremium || _isPremiumUser.value

    fun canStartWorkout(): Boolean = _isPremiumUser.value

    fun requestPaywall(context: PaywallContext) {
        _paywallContext.value = context
        _showPaywall.value = true
    }

    fun dismissPaywall() {
        _showPaywall.value = false
    }

    suspend fun onPurchaseComplete() {
        val userId = authRepository.currentUserId
        if (userId != null) {
            subscriptionRepository.recordSubscription(
                userId = userId,
                type = billingManager.activeProductId.value ?: "monthly",
                transactionId = billingManager.purchaseToken.value ?: "",
                expiresAt = null
            )
        }
        refreshPremiumStatus()
        dismissPaywall()
    }
}
