#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface FakeVocabulary : NSObject
@end

@implementation FakeVocabulary
- (void)setVocabularyStrings:(id)strings ofType:(NSInteger)type {
    NSLog(@"[OrionShim] FakeVocabulary setVocabularyStrings suppressed.");
}
- (void)setVocabulary:(id)vocabulary ofType:(NSInteger)type {
    NSLog(@"[OrionShim] FakeVocabulary setVocabulary suppressed.");
}
- (void)removeAllVocabularyStrings {
    NSLog(@"[OrionShim] FakeVocabulary removeAllVocabularyStrings suppressed.");
}
- (id)forwardingTargetForSelector:(SEL)aSelector {
    return nil;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes:"v@:"];
}
- (void)forwardInvocation:(NSInvocation *)anInvocation {
}
@end

static void replace_method_with_block(Class cls, SEL sel, const char *types, id block) {
    if (!cls) return;
    IMP newImp = imp_implementationWithBlock(block);
    Method origMethod = class_getInstanceMethod(cls, sel);
    if (origMethod) {
        method_setImplementation(origMethod, newImp);
    } else {
        class_addMethod(cls, sel, newImp, types);
    }
}

@interface NSBundle (OrionRebranding)
@end

@implementation NSBundle (OrionRebranding)
- (NSString *)orion_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName {
    NSString *orig = [self orion_localizedStringForKey:key value:value table:tableName];
    if (!orig) return orig;
    
    // Suppress trial time remaining notice completely
    if ([key isEqualToString:@"TRIAL_TIME_REMAINING"] || [key isEqualToString:@"TRIAL_EXPIRED_MESSAGE"] || [key isEqualToString:@"TRIAL_EXTEND_HINT"]) {
        return @"";
    }
    
    NSString *result = orig;
    if ([result containsString:@"Doppler"]) {
        result = [result stringByReplacingOccurrencesOfString:@"Doppler" withString:@"Orion"];
    }
    if ([result containsString:@"doppler"]) {
        result = [result stringByReplacingOccurrencesOfString:@"doppler" withString:@"orion"];
    }
    return result;
}
@end

@interface NSUserDefaults (OrionFlags)
@end

@implementation NSUserDefaults (OrionFlags)
- (BOOL)orion_boolForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"DOPPLER_IGNORE_ENTITLEMENTS"]) {
        return YES;
    }
    if ([defaultName isEqualToString:@"DOPPLER_SHOW_ONBOARDING"]) {
        return NO;
    }
    return [self orion_boolForKey:defaultName];
}
@end

@interface UIViewController (OrionTrialBypass)
@end

@implementation UIViewController (OrionTrialBypass)

- (void)orion_presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    NSString *clsName = NSStringFromClass([viewControllerToPresent class]);
    if ([clsName containsString:@"StartTrial"] ||
        [clsName containsString:@"TrialRemaining"] ||
        [clsName containsString:@"TryDoppler"] ||
        [clsName containsString:@"V3UpgradeStartTrial"] ||
        [clsName containsString:@"Subscribe"] ||
        [clsName containsString:@"StoreKitPurchase"]) {
        NSLog(@"[OrionShim] Suppressed presentation of paywall controller: %@", clsName);
        if (completion) {
            completion();
        }
        return;
    }
    [self orion_presentViewController:viewControllerToPresent animated:flag completion:completion];
}

@end

@interface OrionShim : NSObject
@end

@implementation OrionShim

+ (void)load {
    NSLog(@"[OrionShim] Activating Orion runtime shims and rebranding...");
    
    // 1. Force developer flags in NSUserDefaults to ignore entitlements and skip onboarding
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DOPPLER_IGNORE_ENTITLEMENTS"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DOPPLER_SHOW_ONBOARDING"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    Class udClass = [NSUserDefaults class];
    Method mOrigBool = class_getInstanceMethod(udClass, @selector(boolForKey:));
    Method mSwizBool = class_getInstanceMethod(udClass, @selector(orion_boolForKey:));
    if (mOrigBool && mSwizBool) {
        method_exchangeImplementations(mOrigBool, mSwizBool);
        NSLog(@"[OrionShim] Successfully hooked NSUserDefaults boolForKey:");
    }
    
    // 2. Hook NSFileManager containerURLForSecurityApplicationGroupIdentifier:
    Class fmClass = [NSFileManager class];
    SEL origFM = @selector(containerURLForSecurityApplicationGroupIdentifier:);
    SEL swizFM = @selector(orion_containerURLForSecurityApplicationGroupIdentifier:);
    Method mOrigFM = class_getInstanceMethod(fmClass, origFM);
    Method mSwizFM = class_getInstanceMethod([self class], swizFM);
    if (mOrigFM && mSwizFM) {
        if (class_addMethod(fmClass, swizFM, method_getImplementation(mSwizFM), method_getTypeEncoding(mSwizFM))) {
            Method newSwiz = class_getInstanceMethod(fmClass, swizFM);
            method_exchangeImplementations(mOrigFM, newSwiz);
            NSLog(@"[OrionShim] Successfully hooked containerURL");
        }
    }
    
    // 3. Hook INVocabulary sharedVocabulary to suppress Siri entitlement crash
    Class vocabClass = NSClassFromString(@"INVocabulary");
    if (vocabClass) {
        SEL origVocab = @selector(sharedVocabulary);
        SEL swizVocab = @selector(orion_sharedVocabulary);
        Method mOrigVocab = class_getClassMethod(vocabClass, origVocab);
        Method mSwizVocab = class_getClassMethod([self class], swizVocab);
        if (mOrigVocab && mSwizVocab) {
            Class metaClass = object_getClass((id)vocabClass);
            if (class_addMethod(metaClass, swizVocab, method_getImplementation(mSwizVocab), method_getTypeEncoding(mSwizVocab))) {
                Method newSwiz = class_getClassMethod(vocabClass, swizVocab);
                method_exchangeImplementations(mOrigVocab, newSwiz);
                NSLog(@"[OrionShim] Successfully hooked INVocabulary sharedVocabulary");
            }
        }
    }
    
    // 4. Hook NSBundle localizedStringForKey:value:table: for dynamic UI rebranding
    Class bundleClass = [NSBundle class];
    Method mOrigBundle = class_getInstanceMethod(bundleClass, @selector(localizedStringForKey:value:table:));
    Method mSwizBundle = class_getInstanceMethod([NSBundle class], @selector(orion_localizedStringForKey:value:table:));
    if (mOrigBundle && mSwizBundle) {
        method_exchangeImplementations(mOrigBundle, mSwizBundle);
        NSLog(@"[OrionShim] Successfully hooked NSBundle localization");
    }
    
    // 5. Hook UIViewController presentViewController:animated:completion:
    Class vcClass = [UIViewController class];
    Method mOrigPresent = class_getInstanceMethod(vcClass, @selector(presentViewController:animated:completion:));
    Method mSwizPresent = class_getInstanceMethod(vcClass, @selector(orion_presentViewController:animated:completion:));
    if (mOrigPresent && mSwizPresent) {
        method_exchangeImplementations(mOrigPresent, mSwizPresent);
        NSLog(@"[OrionShim] Successfully hooked presentViewController");
    }
    
    // 6. Hook Entitlements, Purchases and suppress Notice banners immediately
    [self hookEntitlements];
}

+ (void)hookEntitlements {
    NSLog(@"[OrionShim] Hooking entitlement and purchase providers...");
    
    // Hook EntitlementsManager
    Class entMgrClass = NSClassFromString(@"_TtC11Doppler_iOS19EntitlementsManager");
    if (entMgrClass) {
        replace_method_with_block(entMgrClass, NSSelectorFromString(@"hasActiveSubscription"), "B@:", ^BOOL(id self) {
            return YES;
        });
        replace_method_with_block(entMgrClass, NSSelectorFromString(@"purchasedVersions"), "@@:", ^id(id self) {
            return [NSSet setWithObjects:@(2), @(3), nil];
        });
        replace_method_with_block(entMgrClass, NSSelectorFromString(@"trial"), "@@:", ^id(id self) {
            return nil;
        });
    }
    
    // Hook TrialManager - permanent active, never expired
    Class trialMgrClass = NSClassFromString(@"_TtC11Doppler_iOS12TrialManager");
    if (trialMgrClass) {
        replace_method_with_block(trialMgrClass, NSSelectorFromString(@"isInTrialPeriod"), "B@:", ^BOOL(id self) {
            return YES;
        });
        replace_method_with_block(trialMgrClass, NSSelectorFromString(@"cannotRestartExpiredTrial"), "B@:", ^BOOL(id self) {
            return NO;
        });
        replace_method_with_block(trialMgrClass, NSSelectorFromString(@"freeTrialUntilDate"), "@@:", ^id(id self) {
            return [NSDate dateWithTimeIntervalSinceNow:100 * 365 * 86400];
        });
    }
    
    // Hook DopplerPlusManagementViewModel
    Class plusVMClass = NSClassFromString(@"_TtC11Doppler_iOS30DopplerPlusManagementViewModel");
    if (plusVMClass) {
        replace_method_with_block(plusVMClass, NSSelectorFromString(@"_isSignedIn"), "B@:", ^BOOL(id self) {
            return YES;
        });
        replace_method_with_block(plusVMClass, NSSelectorFromString(@"_isLoading"), "B@:", ^BOOL(id self) {
            return NO;
        });
    }
    
    // Hook LibraryNoticeManager to completely hide the trial notice banner
    Class noticeMgrClass = NSClassFromString(@"_TtC11Doppler_iOS20LibraryNoticeManager");
    if (noticeMgrClass) {
        replace_method_with_block(noticeMgrClass, NSSelectorFromString(@"currentNoticeType"), "@@:", ^id(id self) {
            return nil;
        });
    }
    
    // Hook WrappedLibraryDataSource to hide notice header
    NSArray *dataSourceClasses = @[
        @"_TtC11Doppler_iOS24WrappedLibraryDataSource",
        @"WrappedLibraryDataSource"
    ];
    for (NSString *dName in dataSourceClasses) {
        Class d = NSClassFromString(dName);
        if (d) {
            replace_method_with_block(d, NSSelectorFromString(@"isShowingNoticeHeader"), "B@:", ^BOOL(id self) {
                return NO;
            });
        }
    }
    
    // Suppress NoticeCollectionViewListCell height if requested
    Class noticeCellClass = NSClassFromString(@"_TtC11Doppler_iOS28NoticeCollectionViewListCell");
    if (noticeCellClass) {
        replace_method_with_block(noticeCellClass, @selector(systemLayoutSizeFittingSize:), "{CGSize=dd}@:{CGSize=dd}", ^CGSize(id self, CGSize targetSize) {
            return CGSizeZero;
        });
    }
    
    // Hook RevenueCat CustomerInfo and EntitlementInfo
    NSArray *rcCustomerClasses = @[
        @"_TtC39RevenueCat_CustomEntitlementComputation12CustomerInfo",
        @"RCCustomerInfo"
    ];
    for (NSString *cName in rcCustomerClasses) {
        Class c = NSClassFromString(cName);
        if (c) {
            replace_method_with_block(c, NSSelectorFromString(@"allPurchasedProductIdentifiers"), "@@:", ^id(id self) {
                return [NSSet setWithObjects:@"co.brushedtype.doppler.plus", @"co.brushedtype.DopplerPlus", nil];
            });
            replace_method_with_block(c, NSSelectorFromString(@"activeSubscriptions"), "@@:", ^id(id self) {
                return [NSSet setWithObjects:@"co.brushedtype.doppler.plus", @"co.brushedtype.DopplerPlus", nil];
            });
            replace_method_with_block(c, NSSelectorFromString(@"nonSubscriptions"), "@@:", ^id(id self) {
                return [NSSet setWithObjects:@"co.brushedtype.doppler.plus", @"co.brushedtype.DopplerPlus", nil];
            });
        }
    }
    
    NSArray *rcEntitlementClasses = @[
        @"_TtC39RevenueCat_CustomEntitlementComputation15EntitlementInfo",
        @"RCEntitlementInfo"
    ];
    for (NSString *cName in rcEntitlementClasses) {
        Class c = NSClassFromString(cName);
        if (c) {
            replace_method_with_block(c, NSSelectorFromString(@"isActive"), "B@:", ^BOOL(id self) {
                return YES;
            });
            replace_method_with_block(c, NSSelectorFromString(@"isActiveInCurrentEnvironment"), "B@:", ^BOOL(id self) {
                return YES;
            });
            replace_method_with_block(c, NSSelectorFromString(@"isActiveInAnyEnvironment"), "B@:", ^BOOL(id self) {
                return YES;
            });
            replace_method_with_block(c, NSSelectorFromString(@"willRenew"), "B@:", ^BOOL(id self) {
                return YES;
            });
        }
    }
    
    NSLog(@"[OrionShim] Entitlement and notice suppression hooks successfully applied.");
}

+ (id)orion_sharedVocabulary {
    static FakeVocabulary *fake = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fake = [[FakeVocabulary alloc] init];
    });
    return fake;
}

- (NSURL *)orion_containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupId {
    NSURL *url = [self orion_containerURLForSecurityApplicationGroupIdentifier:groupId];
    if (!url) {
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documents = [paths firstObject];
        url = [documents URLByAppendingPathComponent:@"AppGroupContainer" isDirectory:YES];
        [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return url;
}

@end
