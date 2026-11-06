#import <Foundation/Foundation.h>
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

@interface OrionShim : NSObject
@end

@implementation OrionShim

+ (void)load {
    NSLog(@"[OrionShim] Activating Orion runtime shims...");
    
    // 1. Hook NSFileManager containerURLForSecurityApplicationGroupIdentifier:
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
    
    // 2. Hook INVocabulary sharedVocabulary to suppress Siri entitlement crash on free developer accounts
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
