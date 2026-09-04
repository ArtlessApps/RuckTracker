package com.artless.rucktracker.ui.premium

import android.app.Activity
import androidx.lifecycle.ViewModel
import com.artless.rucktracker.billing.BillingManager
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class PaywallViewModel @Inject constructor(
    private val billingManager: BillingManager
) : ViewModel() {
    init { billingManager.startConnection() }

    fun purchaseMonthly(activity: Activity, onSuccess: () -> Unit) {
        billingManager.launchPurchase(activity, BillingManager.MONTHLY_PRODUCT, onSuccess)
    }

    fun purchaseYearly(activity: Activity, onSuccess: () -> Unit) {
        billingManager.launchPurchase(activity, BillingManager.YEARLY_PRODUCT, onSuccess)
    }
}
