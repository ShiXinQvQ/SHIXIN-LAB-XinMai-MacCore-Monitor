#import "ShixinStressPowerHardwareBridge.h"

#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;

#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

#define SHIXIN_IOHID_EVENT_FIELD_BASE(type) (type << 16)
#define SHIXIN_IOHID_EVENT_TYPE_TEMPERATURE 15

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timestamp);
CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

NSDictionary<NSString *, NSNumber *> *ShixinAppleSiliconTemperatureSensors(void) {
    NSDictionary *match = @{
        @"PrimaryUsagePage": @(0xff00),
        @"PrimaryUsage": @(0x0005)
    };

    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (system == NULL) {
        return @{};
    }

    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)match);
    CFArrayRef services = IOHIDEventSystemClientCopyServices(system);
    if (services == NULL) {
        CFRelease(system);
        return @{};
    }

    NSMutableDictionary<NSString *, NSNumber *> *results = [NSMutableDictionary dictionary];
    CFIndex count = CFArrayGetCount(services);
    for (CFIndex index = 0; index < count; index++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, index);
        if (service == NULL) {
            continue;
        }

        NSString *name = CFBridgingRelease(IOHIDServiceClientCopyProperty(service, CFSTR("Product")));
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, SHIXIN_IOHID_EVENT_TYPE_TEMPERATURE, 0, 0);
        if (name != nil && event != NULL) {
            double value = IOHIDEventGetFloatValue(event, SHIXIN_IOHID_EVENT_FIELD_BASE(SHIXIN_IOHID_EVENT_TYPE_TEMPERATURE));
            if (isfinite(value)) {
                results[name] = @(value);
            }
        }
        if (event != NULL) {
            CFRelease(event);
        }
    }

    CFRelease(services);
    CFRelease(system);
    return results;
}
