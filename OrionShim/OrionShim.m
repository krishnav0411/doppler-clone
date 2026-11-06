#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface OrionShim : NSObject
@end

@implementation OrionShim

+ (void)load {
    NSLog(@"[OrionShim] Activating App Group fallback shim for sideloading...");
    Class cls = [NSFileManager class];
    SEL originalSelector = @selector(containerURLForSecurityApplicationGroupIdentifier:);
    SEL swizzledSelector = @selector(orion_containerURLForSecurityApplicationGroupIdentifier:);

    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method swizzledMethod = class_getInstanceMethod([self class], swizzledSelector);

    if (originalMethod && swizzledMethod) {
        if (class_addMethod(cls, swizzledSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
            Method newSwizzled = class_getInstanceMethod(cls, swizzledSelector);
            method_exchangeImplementations(originalMethod, newSwizzled);
            NSLog(@"[OrionShim] Hook installed successfully.");
        }
    }
}

- (NSURL *)orion_containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupId {
    NSURL *url = [self orion_containerURLForSecurityApplicationGroupIdentifier:groupId];
    if (!url) {
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documents = [paths firstObject];
        url = [documents URLByAppendingPathComponent:@"AppGroupContainer" isDirectory:YES];
        [[NSFileManager defaultManager] createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:nil];
        NSLog(@"[OrionShim] Redirected App Group '%@' -> %@", groupId, url.path);
    }
    return url;
}

@end
