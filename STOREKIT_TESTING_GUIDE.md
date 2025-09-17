# StoreKit Local Testing Setup Guide

## Overview
This guide will help you set up local testing for your RuckTracker in-app purchases using StoreKit Configuration Files. This allows you to test your subscription system without needing App Store Connect setup.

## Files Created
- `Products.storekit` - StoreKit Configuration File with your subscription products

## Setup Steps

### 1. Add StoreKit Configuration File to Xcode Project

1. **Open your RuckTracker project in Xcode**
2. **Right-click on your project** in the navigator
3. **Select "Add Files to 'RuckTracker'"**
4. **Navigate to and select** `Products.storekit`
5. **Make sure "Add to target" is checked** for your main app target
6. **Click "Add"**

### 2. Configure Xcode Scheme for StoreKit Testing

1. **In Xcode, go to Product → Scheme → Edit Scheme**
2. **Select "Run" in the left sidebar**
3. **Go to the "Options" tab**
4. **Under "StoreKit Configuration", select** `Products.storekit`
5. **Click "Close"**

### 3. Test Your In-App Purchases

#### Running the App with StoreKit Testing
1. **Build and run your app** in the simulator or on device
2. **Your StoreKitManager will now load the test products** from the configuration file
3. **Test the subscription flow** by tapping upgrade buttons

#### Available Test Products
- **Monthly Subscription**: $4.99/month with 7-day free trial
- **Yearly Subscription**: $39.99/year with 7-day free trial

### 4. StoreKit Testing Features

#### Simulated Purchases
- **No real money charged** during testing
- **Instant purchase completion** for testing
- **Simulated subscription states** (active, expired, etc.)

#### Test Subscription States
You can simulate different subscription states in Xcode:

1. **Go to Debug → StoreKit → Manage Transactions**
2. **Select different subscription states** to test:
   - Active subscription
   - Expired subscription
   - In grace period
   - Cancelled subscription

#### Test Subscription Renewals
1. **In StoreKit testing, you can fast-forward time**
2. **Test subscription renewals** and expiration
3. **Verify your app handles** different subscription states correctly

### 5. Testing Checklist

#### Basic Functionality
- [ ] App loads without crashing
- [ ] StoreKitManager initializes correctly
- [ ] Products load successfully
- [ ] Paywall displays correctly
- [ ] Purchase flow works
- [ ] Subscription status updates correctly

#### Premium Features
- [ ] Premium features are gated for free users
- [ ] Premium features unlock after purchase
- [ ] Premium badges display correctly
- [ ] Free trial banner shows when applicable

#### Edge Cases
- [ ] App handles purchase cancellation
- [ ] App handles purchase failures
- [ ] App handles network errors
- [ ] App handles subscription expiration
- [ ] Restore purchases works correctly

### 6. Debugging Tips

#### Console Logs
Your StoreKitManager includes helpful console logs:
- `✅ Loaded X subscription products` - Products loaded successfully
- `🔐 Premium status updated: Premium/Free` - Subscription status changed
- `❌ Failed to load products` - Product loading failed

#### Common Issues
1. **Products not loading**: Check that Products.storekit is added to your target
2. **Purchase not working**: Verify StoreKit Configuration is set in scheme
3. **Subscription status not updating**: Check that StoreKitManager is properly initialized

### 7. Testing Different Scenarios

#### Free User Experience
1. **Launch app without subscription**
2. **Verify premium features are gated**
3. **Test paywall presentation**
4. **Verify upgrade prompts work**

#### Premium User Experience
1. **Purchase subscription in StoreKit testing**
2. **Verify premium features unlock**
3. **Test all premium functionality**
4. **Verify subscription status displays correctly**

#### Subscription Expiration
1. **Set subscription to expired in StoreKit testing**
2. **Verify premium features are re-gated**
3. **Test re-subscription flow**

### 8. Next Steps

Once local testing is complete:
1. **Set up App Store Connect** with the same product IDs
2. **Test with TestFlight** using sandbox accounts
3. **Submit for App Store review**

## Product Configuration Details

### Monthly Subscription
- **Product ID**: `com.artless.rucktracker.premium.monthly`
- **Price**: $4.99/month
- **Free Trial**: 7 days
- **Duration**: 1 month

### Yearly Subscription
- **Product ID**: `com.artless.rucktracker.premium.yearly`
- **Price**: $39.99/year
- **Free Trial**: 7 days
- **Duration**: 1 year
- **Savings**: ~33% compared to monthly

### Subscription Group
- **Group ID**: `premium`
- **Contains**: Both monthly and yearly subscriptions
- **Localization**: English (US)

## Troubleshooting

### Products Not Loading
1. Check that `Products.storekit` is in your project
2. Verify it's added to your app target
3. Check that StoreKit Configuration is set in your scheme
4. Look for console errors

### Purchase Flow Issues
1. Verify StoreKitManager is properly initialized
2. Check that product IDs match exactly
3. Ensure you're testing in simulator or on device (not just building)

### Subscription Status Issues
1. Check StoreKit testing transaction management
2. Verify subscription group configuration
3. Test different subscription states

## Support

If you encounter issues:
1. Check Xcode console for error messages
2. Verify StoreKit Configuration setup
3. Test with different subscription states
4. Review StoreKit documentation for advanced scenarios
